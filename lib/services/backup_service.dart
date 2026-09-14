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

  /// A ledger backup is kilobytes: refuse absurd files before copying them
  /// twice (probe + live) and exhausting disk.
  static const int _maxBackupBytes = 100 * 1024 * 1024;

  /// Per-row money bound (₹100 crore in paise). No shop bill reaches it, and a
  /// file full of such rows could overflow SQLite's `SUM(amount_paise)`.
  static const int _maxPlausiblePaise = 100 * 1000 * 1000 * 1000 * 100;

  /// Columns the app reads. A v4 file is read directly; a v1–v3 file is
  /// migrated on reopen, and drift's migration puts **every** one of these
  /// names in its `INSERT … SELECT`. A file missing one of them used to pass
  /// this probe and then fail the migration on the next launch — every later
  /// open threw, which bricked the app and (because the safety copy needs a
  /// working live database) removed the in-app way back.
  static const Map<String, Set<String>> _requiredV4Columns = {
    'distributors': {'id', 'name', 'company', 'phone', 'created_at'},
    'bills': {
      'id',
      'distributor_id',
      'bill_number',
      'bill_date',
      'amount_paise',
      'notes',
      'created_at',
    },
    'payments': {
      'id',
      'bill_id',
      'payment_date',
      'amount_paise',
      'mode',
      'reference_no',
      'notes',
      'created_at',
    },
  };

  /// Pre-v4 shape: the same rows with the money column still named `amount`.
  static const Map<String, Set<String>> _requiredLegacyColumns = {
    'distributors': {'id', 'name', 'company', 'phone', 'created_at'},
    'bills': {
      'id',
      'distributor_id',
      'bill_number',
      'bill_date',
      'amount',
      'notes',
      'created_at',
    },
    'payments': {
      'id',
      'bill_id',
      'payment_date',
      'amount',
      'mode',
      'reference_no',
      'notes',
      'created_at',
    },
  };

  static Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'billmed.db'));
  }

  /// Validates a candidate backup file exactly the way a restore does: SQLite
  /// header, size, declared schema version, the full column set that version
  /// is read through, no triggers/views, `integrity_check`, and plausible
  /// money values.
  ///
  /// The single gate for "may this file be trusted as a BillMed backup?":
  /// [importBackup] runs it on the picked file, and Settings runs it on the
  /// newest backup before re-sharing it. Public (not a private helper) so
  /// tests can point it at hand-built fixtures — the restore flow itself needs
  /// the platform file picker, which `flutter test` cannot drive.
  static Future<bool> validateBackupFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    if (await file.length() > _maxBackupBytes) return false;
    if (await file.length() < 100) return false;

    final raf = file.openSync();
    try {
      final header = raf.readSync(15);
      if (header.length < 15 ||
          String.fromCharCodes(header) != 'SQLite format 3') {
        return false;
      }
    } finally {
      raf.closeSync();
    }

    // Same database class restore probes with: generated tables are omitted, so
    // drift neither migrates the file nor fakes `user_version`. Table names
    // below are compile-time constants, never user input.
    final probe = _ProbeDatabase(NativeDatabase(file, enableMigrations: false));
    try {
      final version =
          await probe.customSelect('PRAGMA user_version').getSingle();
      final userVersion = version.read<int>('user_version');
      // Accept schema v1–v4: v4 files restore directly, older ones are
      // migrated by the app's onUpgrade when reopened after restart.
      if (userVersion < 1 || userVersion > 4) return false;

      final tables = await probe
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tables.map((row) => row.read<String>('name')).toSet();
      for (final required in const ['distributors', 'bills', 'payments']) {
        if (!names.contains(required)) return false;
      }

      final Map<String, Set<String>> required =
          userVersion == 4 ? _requiredV4Columns : _requiredLegacyColumns;
      if (!await _hasColumns(probe, required)) return false;

      // Names are not enough: the stored values have to be readable too, or the
      // file is accepted and the app then throws on the first read — after the
      // ledger has already been replaced.
      final types = userVersion == 4 ? _readableV4Types : _readableLegacyTypes;
      if (!await _valuesAreReadable(probe, types)) return false;

      // BillMed never creates triggers or views: any file carrying them
      // is foreign — reject instead of letting hostile logic ride into
      // the live database on restore. (Extra *tables* stay allowed:
      // legacy v1–v3 backups may carry bank_transactions, which the
      // migrator drops on reopen.)
      final foreignObjects = await probe
          .customSelect(
              "SELECT type FROM sqlite_master WHERE type IN ('trigger', 'view') LIMIT 1")
          .get();
      if (foreignObjects.isNotEmpty) return false;

      final moneyColumn = userVersion == 4 ? 'amount_paise' : 'amount';
      final moneyBound = userVersion == 4
          ? _maxPlausiblePaise
          : _maxPlausiblePaise ~/ 100; // legacy files store rupees
      if (!await _amountsInRange(probe, moneyColumn, moneyBound)) return false;

      // Structural sanity before this file ever touches the live path.
      final integrity =
          await probe.customSelect('PRAGMA integrity_check').getSingle();
      if (integrity.read<String>('integrity_check') != 'ok') return false;

      return true;
    } catch (e) {
      debugPrint('BackupService.validateBackupFile failed: $e');
      return false;
    } finally {
      await probe.close();
    }
  }

  /// Storage types drift can map for every column the app reads, by table.
  ///
  /// Column *names* are not enough: a file that declares `amount_paise INTEGER`
  /// but stores NULL, or a text bill number stored as a number, passes a
  /// name-only check and then throws inside the app on the first read — after
  /// it has already replaced the ledger. `typeof()` catches every row, and
  /// `'null'` is simply not an allowed type where the app reads non-nullably.
  static const Map<String, Map<String, Set<String>>> _readableV4Types = {
    'distributors': {
      'id': {'integer'},
      'name': {'text'},
      'company': {'text', 'null'},
      'phone': {'text', 'null'},
      'created_at': {'integer'},
    },
    'bills': {
      'id': {'integer'},
      'distributor_id': {'integer'},
      'bill_number': {'text'},
      'bill_date': {'integer'},
      'amount_paise': {'integer'},
      'notes': {'text', 'null'},
      'created_at': {'integer'},
    },
    'payments': {
      'id': {'integer'},
      'bill_id': {'integer'},
      'payment_date': {'integer'},
      'amount_paise': {'integer'},
      'mode': {'text'},
      'reference_no': {'text', 'null'},
      'notes': {'text', 'null'},
      'created_at': {'integer'},
    },
  };

  /// Pre-v4 shape: the money column is `amount` and may be REAL (rupees).
  static Map<String, Map<String, Set<String>>> get _readableLegacyTypes => {
        for (final entry in _readableV4Types.entries)
          entry.key: {
            for (final column in entry.value.entries)
              if (column.key == 'amount_paise')
                'amount': const {'integer', 'real'}
              else
                column.key: column.value,
          },
      };

  /// `PRAGMA table_info` set check per table. The table names come from the
  /// constant maps above — nothing here is built from file content.
  static Future<bool> _hasColumns(
    _ProbeDatabase probe,
    Map<String, Set<String>> required,
  ) async {
    for (final entry in required.entries) {
      final rows =
          await probe.customSelect('PRAGMA table_info(${entry.key})').get();
      final present = rows.map((row) => row.read<String>('name')).toSet();
      if (!present.containsAll(entry.value)) return false;
    }
    return true;
  }

  /// Every stored value must be something the app can actually read back:
  /// right storage type, and never NULL where the app does not expect it.
  /// Table and column names come from the constant maps above.
  static Future<bool> _valuesAreReadable(
    _ProbeDatabase probe,
    Map<String, Map<String, Set<String>>> types,
  ) async {
    for (final table in types.entries) {
      final conditions = <String>[];
      for (final column in table.value.entries) {
        final allowed = column.value.map((String type) => "'$type'").join(', ');
        conditions.add("typeof(${column.key}) NOT IN ($allowed)");
      }
      final row = await probe
          .customSelect(
              'SELECT COUNT(*) AS n FROM ${table.key} WHERE ${conditions.join(' OR ')}')
          .getSingle();
      if (row.read<int>('n') > 0) return false;
    }
    return true;
  }

  /// Rejects negative and absurd money values: they cannot come from this app,
  /// and a file full of them overflows SQLite's `SUM()`. NULL is already
  /// refused by [_valuesAreReadable] (`typeof(NULL) = 'null'`).
  static Future<bool> _amountsInRange(
    _ProbeDatabase probe,
    String column,
    int bound,
  ) async {
    for (final table in const ['bills', 'payments']) {
      final row = await probe.customSelect(
        'SELECT COUNT(*) AS n FROM $table WHERE $column < 0 OR $column > ?',
        variables: [Variable.withInt(bound)],
      ).getSingle();
      if (row.read<int>('n') > 0) return false;
    }
    return true;
  }

  /// Row counts of a ledger, in a fixed table order.
  static Future<List<int>> _rowCounts(GeneratedDatabase db) async {
    final counts = <int>[];
    for (final table in const ['distributors', 'bills', 'payments']) {
      final row =
          await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle();
      counts.add(row.read<int>('n'));
    }
    return counts;
  }

  /// A snapshot is only published when it holds exactly the rows the live
  /// ledger has. A failed WAL checkpoint during the copy fallback used to
  /// leave a silently older file that still reported "Backup saved".
  static Future<bool> _snapshotMatches(
    BillMedDatabase db,
    String snapshotPath,
  ) async {
    final live = await _rowCounts(db);
    final probe = _ProbeDatabase(
        NativeDatabase(File(snapshotPath), enableMigrations: false));
    try {
      final snapshot = await _rowCounts(probe);
      return live.length == snapshot.length &&
          List.generate(live.length, (i) => live[i] == snapshot[i])
              .every((same) => same);
    } catch (e) {
      debugPrint('BackupService: snapshot check failed: $e');
      return false;
    } finally {
      await probe.close();
    }
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
        // Copying the main file is only a complete snapshot once the WAL has
        // been flushed into it. A checkpoint that fails leaves committed rows
        // behind in -wal, i.e. a backup silently missing the newest entries —
        // so this fails instead of publishing a file the user would trust.
        try {
          await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (e) {
          debugPrint('BackupService: WAL checkpoint failed: $e');
          return null;
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

      // Verified before publishing: a snapshot is only a backup if it opens as
      // a valid BillMed database and holds exactly the rows of the live
      // ledger. Success is never reported on a file-size check alone.
      if (!await validateBackupFile(tmpPath) ||
          !await _snapshotMatches(db, tmpPath)) {
        debugPrint('BackupService: snapshot failed verification, discarded');
        try {
          await tmpFile.delete();
        } catch (_) {}
        return null;
      }
      await _deleteSidecars(tmpPath);

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
        // Same rule as the manual export: an unflushed WAL would make this
        // "auto backup" quietly older than the ledger it claims to protect.
        try {
          await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
        } catch (e) {
          debugPrint('BackupService: auto WAL checkpoint failed: $e');
          return;
        }
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
      if (!await validateBackupFile(tmpPath) ||
          !await _snapshotMatches(db, tmpPath)) {
        debugPrint(
            'BackupService: auto snapshot failed verification, discarded');
        try {
          await tmp.delete();
        } catch (_) {}
        return;
      }
      await _deleteSidecars(tmpPath);
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
      // Tracked so a failure after `db.close()` is reported honestly instead of
      // being blamed on the file the user picked.
      var dbClosed = false;

      try {
        if (!await source.exists()) return RestoreResult.invalid;
        final sourceLength = await source.length();
        if (sourceLength < 100 || sourceLength > _maxBackupBytes) {
          return RestoreResult.invalid;
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
        await source.copy(probePath);
        final bool valid;
        try {
          valid = await validateBackupFile(probePath);
        } finally {
          try {
            await File(probePath).delete();
          } catch (_) {}
          await _deleteSidecars(probePath);
        }
        if (!valid) return RestoreResult.invalid;

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
          // untouched, so cancelling here loses nothing. The copy is validated
          // too — a safety copy that cannot be restored is not a safety copy.
          if (!safetyDone || !await validateBackupFile(safetyPath)) {
            return RestoreResult.safetyFailed;
          }
          await _deleteSidecars(safetyPath);
        }

        await db.close();
        dbClosed = true;

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
        // Once the live database has been closed the ledger may be half
        // swapped: "select a valid backup file" would be a lie, because the
        // problem is no longer the file.
        return dbClosed
            ? RestoreResult.failedRestartRequired
            : RestoreResult.invalid;
      }
    } finally {
      _busy = false;
      // The picker keeps its own plaintext copy of whatever was chosen; drop
      // it rather than leaving a ledger copy in the cache directory.
      try {
        await FilePicker.platform.clearTemporaryFiles();
      } catch (_) {}
    }
  }

  /// Removes `-wal`/`-shm`/`-journal` siblings of [path]. Probing a snapshot
  /// can leave them behind, and a renamed snapshot must never drag a stale
  /// sidecar into the live path.
  static Future<void> _deleteSidecars(String path) async {
    for (final suffix in const ['-wal', '-shm', '-journal']) {
      try {
        await File('$path$suffix').delete();
      } catch (_) {}
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
