import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';

class _ProbeDatabase extends GeneratedDatabase {
  _ProbeDatabase(super.executor);

  @override
  Iterable<TableInfo> get allTables => const [];

  @override
  int get schemaVersion => 4;
}

class BackupService {
  static bool _busy = false;

  static Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'billmed.db'));
  }

  /// Returns the backup file path on success, null on failure.
  /// User cancelling the share sheet is not a failure.
  static Future<String?> exportBackup(BillMedDatabase db) async {
    if (_busy) return null;
    _busy = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ts = _timestamp();
      final backupPath = p.join(dir.path, 'BillMed_backup_$ts.db');
      final tmpPath = p.join(dir.path, 'BillMed_backup_$ts.tmp.db');

      // Same-millisecond repeat export must not fail on an existing file.
      for (final stalePath in [backupPath, tmpPath]) {
        final stale = File(stalePath);
        if (await stale.exists()) {
          try {
            await stale.delete();
          } catch (_) {}
        }
      }

      // Atomic publish (mirrors autoBackup): the visible backup path is
      // only ever replaced by a complete snapshot — a kill mid-write
      // leaves a hidden .tmp partial, never a corrupt "backup".
      var snapshotDone = false;
      try {
        await db.customStatement('VACUUM INTO ?', [tmpPath]);
        snapshotDone = true;
      } catch (e) {
        debugPrint(
            'BackupService: VACUUM INTO failed, falling back to copy: $e');
      }

      if (!snapshotDone) {
        try {
          await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (e) {
          debugPrint('BackupService: WAL checkpoint failed: $e');
        }
        final dbFile = await _getDbFile();
        if (!await dbFile.exists()) return null;
        await dbFile.copy(tmpPath);
      }

      final tmpFile = File(tmpPath);
      if (!await tmpFile.exists() || await tmpFile.length() < 100) {
        try {
          await tmpFile.delete();
        } catch (_) {}
        return null;
      }
      try {
        await tmpFile.rename(backupPath);
      } catch (_) {
        try {
          await tmpFile.copy(backupPath);
          await tmpFile.delete();
        } catch (_) {
          return null;
        }
      }

      final backupFile = File(backupPath);
      if (!await backupFile.exists() || await backupFile.length() < 100) {
        return null;
      }

      try {
        await Share.shareXFiles(
          [XFile(backupPath)],
          text:
              'BillMed Backup $ts\nSave this file securely to restore your data.',
        );
      } catch (_) {
        // Share cancelled/unavailable; backup file is already saved.
      }

      return backupPath;
    } catch (e) {
      debugPrint('BackupService.exportBackup failed: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  /// Silent best-effort backup, safe to fire-and-forget on app pause.
  static Future<void> autoBackup(BillMedDatabase db) async {
    if (_busy) return;
    _busy = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final backupPath = p.join(dir.path, 'BillMed_auto_backup.db');
      final tmpPath = p.join(dir.path, 'BillMed_auto_backup.tmp.db');

      var snapshotDone = false;
      try {
        await db.customStatement('VACUUM INTO ?', [tmpPath]);
        snapshotDone = true;
      } catch (e) {
        debugPrint(
            'BackupService: auto VACUUM INTO failed, falling back to copy: $e');
      }

      if (!snapshotDone) {
        try {
          await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (_) {}
        final dbFile = await _getDbFile();
        if (!await dbFile.exists()) return;
        // Fresh tmp: never copy onto a stale partial file.
        final staleTmp = File(tmpPath);
        if (await staleTmp.exists()) {
          try {
            await staleTmp.delete();
          } catch (_) {}
        }
        await dbFile.copy(tmpPath);
      }

      final tmp = File(tmpPath);
      if (!await tmp.exists() || await tmp.length() < 100) {
        try {
          await tmp.delete();
        } catch (_) {}
        return;
      }
      // Atomic publish: the live auto-backup path is only ever replaced by
      // a complete snapshot — a kill mid-write loses nothing.
      final existing = File(backupPath);
      if (await existing.exists()) {
        try {
          await existing.delete();
        } catch (_) {}
      }
      try {
        await tmp.rename(backupPath);
      } catch (_) {
        try {
          await tmp.copy(backupPath);
          await tmp.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('BackupService.autoBackup failed: $e');
    } finally {
      _busy = false;
    }
  }

  static bool get isBusy => _busy;

  static Future<RestoreResult> importBackup(BillMedDatabase db) async {
    if (_busy) return RestoreResult.busy;
    _busy = true;
    try {
      FilePickerResult? picked;
      try {
        picked = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
        );
      } catch (_) {
        return RestoreResult.cancelled;
      }
      if (picked == null || picked.files.isEmpty) {
        return RestoreResult.cancelled;
      }

      final sourcePath = picked.files.single.path;
      if (sourcePath == null) return RestoreResult.invalid;

      final liveDbPath =
          p.join((await getApplicationDocumentsDirectory()).path, 'billmed.db');
      if (p.equals(sourcePath, liveDbPath)) {
        return RestoreResult.invalid;
      }
      final source = File(sourcePath);

      try {
        if (!await source.exists()) return RestoreResult.invalid;
        // A ledger backup is kilobytes: refuse absurd files before copying
        // them twice (probe + live) and exhausting disk.
        if (await source.length() > 100 * 1024 * 1024) {
          return RestoreResult.invalid;
        }

        final raf = source.openSync();
        try {
          final header = raf.readSync(15);
          if (header.length < 15 ||
              String.fromCharCodes(header) != 'SQLite format 3') {
            return RestoreResult.invalid;
          }
        } finally {
          raf.closeSync();
        }

        // Probe a private temp copy — never the user's picked file. Opening
        // the source directly would create -wal/-shm sidecars next to it
        // (mutating user data) and fail on read-only sources.
        final tmpDir = await getTemporaryDirectory();
        final probePath =
            p.join(tmpDir.path, 'billmed_probe_${_timestamp()}.db');
        final staleProbe = File(probePath);
        if (await staleProbe.exists()) {
          try {
            await staleProbe.delete();
          } catch (_) {}
        }
        final probeCopy = await source.copy(probePath);
        final probe =
            _ProbeDatabase(NativeDatabase(probeCopy, enableMigrations: false));
        try {
          final version =
              await probe.customSelect('PRAGMA user_version').getSingle();
          final userVersion = version.read<int>('user_version');
          // Accept schema v1–v4: v4 files restore directly, older ones are
          // migrated by the app's onUpgrade when reopened after restart.
          if (userVersion < 1 || userVersion > 4) {
            return RestoreResult.invalid;
          }

          final tables = await probe
              .customSelect(
                  "SELECT name FROM sqlite_master WHERE type = 'table'")
              .get();
          final names = tables.map((row) => row.read<String>('name')).toSet();
          if (!names.contains('distributors') ||
              !names.contains('bills') ||
              !names.contains('payments')) {
            return RestoreResult.invalid;
          }

          if (userVersion == 4) {
            final columns =
                await probe.customSelect('PRAGMA table_info(payments)').get();
            final columnNames =
                columns.map((row) => row.read<String>('name')).toSet();
            if (!columnNames.contains('amount_paise')) {
              return RestoreResult.invalid;
            }
            final billColumns =
                await probe.customSelect('PRAGMA table_info(bills)').get();
            final billColumnNames =
                billColumns.map((row) => row.read<String>('name')).toSet();
            if (!billColumnNames.contains('amount_paise')) {
              return RestoreResult.invalid;
            }
          } else {
            final columns =
                await probe.customSelect('PRAGMA table_info(payments)').get();
            final columnNames =
                columns.map((row) => row.read<String>('name')).toSet();
            if (!columnNames.contains('amount')) {
              return RestoreResult.invalid;
            }
            final billColumns =
                await probe.customSelect('PRAGMA table_info(bills)').get();
            final billColumnNames =
                billColumns.map((row) => row.read<String>('name')).toSet();
            if (!billColumnNames.contains('amount')) {
              return RestoreResult.invalid;
            }
          }

          // BillMed never creates triggers or views: any file carrying them
          // is foreign — reject instead of letting hostile logic ride into
          // the live database on restore. (Extra *tables* stay allowed:
          // legacy v1–v3 backups may carry bank_transactions, which the
          // migrator drops on reopen.)
          final foreignObjects = await probe
              .customSelect(
                  "SELECT type FROM sqlite_master WHERE type IN ('trigger', 'view') LIMIT 1")
              .get();
          if (foreignObjects.isNotEmpty) {
            return RestoreResult.invalid;
          }

          // Structural sanity before this file ever touches the live path.
          final integrity =
              await probe.customSelect('PRAGMA integrity_check').getSingle();
          if (integrity.read<String>('integrity_check') != 'ok') {
            return RestoreResult.invalid;
          }
        } finally {
          await probe.close();
          try {
            await probeCopy.delete();
          } catch (_) {}
          for (final suffix in const ['-wal', '-shm', '-journal']) {
            try {
              await File('$probePath$suffix').delete();
            } catch (_) {}
          }
        }

        final dbFile = await _getDbFile();
        String? safetyPath;
        if (await dbFile.exists()) {
          final dir = await getApplicationDocumentsDirectory();
          safetyPath =
              p.join(dir.path, 'BillMed_pre_restore_${_timestamp()}.db');
          // Same-millisecond repeat restore must not fail on the existing
          // file — losing the safety copy (or aborting) is worse.
          final staleSafety = File(safetyPath);
          if (await staleSafety.exists()) {
            try {
              await staleSafety.delete();
            } catch (_) {}
          }
          var safetyDone = false;
          try {
            await db.customStatement('VACUUM INTO ?', [safetyPath]);
            safetyDone = true;
          } catch (_) {
            try {
              await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
              await dbFile.copy(safetyPath);
              safetyDone = true;
            } catch (_) {}
          }
          // No safety net, no restore: the live DB is still open and
          // untouched, so cancelling here loses nothing.
          if (!safetyDone) return RestoreResult.safetyFailed;
        }

        await db.close();

        // A locked sidecar + a fresh main file = stale WAL replay into the
        // restored DB. Fail closed instead of copying over it.
        for (final suffix in const ['-wal', '-shm', '-journal']) {
          final sidecar = File('${dbFile.path}$suffix');
          if (await sidecar.exists()) {
            try {
              await sidecar.delete();
            } catch (_) {
              if (safetyPath != null) {
                try {
                  await File(safetyPath).copy(dbFile.path);
                } catch (_) {}
              }
              return RestoreResult.failedRestartRequired;
            }
          }
        }

        try {
          await source.copy(dbFile.path);
        } catch (copyError) {
          debugPrint('BackupService restore copy failed: $copyError');
          if (safetyPath != null) {
            try {
              await File(safetyPath).copy(dbFile.path);
            } catch (_) {}
          }
          return RestoreResult.failedRestartRequired;
        }
        return RestoreResult.successRequiresRestart;
      } catch (e) {
        debugPrint('BackupService.importBackup failed: $e');
        return RestoreResult.invalid;
      }
    } finally {
      _busy = false;
    }
  }

  static String _timestamp() {
    final d = DateTime.now();
    return '${d.year}${_pad(d.month)}${_pad(d.day)}_${_pad(d.hour)}${_pad(d.minute)}${_pad(d.second)}${d.millisecond.toString().padLeft(3, '0')}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

enum RestoreResult {
  successRequiresRestart,
  failedRestartRequired,
  safetyFailed,
  cancelled,
  busy,
  invalid,
}
