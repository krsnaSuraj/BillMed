import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database.dart';

class BackupService {
  // ─── Get DB file path (must match the path used by Drift in database.dart) ──
  static Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'billmed.db'));
  }

  // ─── Manual Backup ──────────────────────────────────────────────────────────
  /// Returns the backup file path on success, null on failure.
  static Future<String?> exportBackup(BillMedDatabase db) async {
    try {
      // 1. Checkpoint WAL so all pending writes flush to main DB file
      try {
        await db.customStatement('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      // 2. Verify the DB file actually exists
      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        return null; // explicitly return null = failure
      }

      // 3. Copy to documents directory with timestamp name
      final dir = await getApplicationDocumentsDirectory();
      final ts = _timestamp();
      final backupFile = File(p.join(dir.path, 'BillMed_backup_$ts.db'));
      await dbFile.copy(backupFile.path);

      // 4. Verify the copy actually worked
      if (!await backupFile.exists() || await backupFile.length() < 100) {
        return null;
      }

      // 5. Share the file (user can save to Drive, WhatsApp, Files app etc.)
      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'BillMed Backup - $ts\nStore this file safely to restore your data.',
      );

      return backupFile.path;
    } catch (e) {
      return null;
    }
  }

  // ─── Auto Backup (silent, called on app pause) ──────────────────────────────
  static Future<void> autoBackup(BillMedDatabase db) async {
    try {
      try {
        await db.customStatement('PRAGMA wal_checkpoint(PASSIVE)');
      } catch (_) {}

      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) return;

      final dir = await getApplicationDocumentsDirectory();
      final backup = File(p.join(dir.path, 'BillMed_auto_backup.db'));
      await dbFile.copy(backup.path);
    } catch (_) {
      // Silent fail — auto backup is best-effort
    }
  }

  // ─── Restore from Backup ────────────────────────────────────────────────────
  static Future<RestoreResult> importBackup(BillMedDatabase db) async {
    // 1. Pick file
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
    } catch (_) {
      return RestoreResult.cancelled;
    }

    if (result == null || result.files.isEmpty) return RestoreResult.cancelled;

    final sourcePath = result.files.single.path;
    if (sourcePath == null) return RestoreResult.cancelled;

    final source = File(sourcePath);
    if (!await source.exists()) return RestoreResult.invalid;

    // 2. Validate: check SQLite magic header
    try {
      final raf = source.openSync();
      final header = List<int>.filled(16, 0);
      raf.readIntoSync(header);
      raf.closeSync();
      final magic = String.fromCharCodes(header.take(15));
      if (!magic.startsWith('SQLite format 3')) {
        return RestoreResult.invalid;
      }
    } catch (_) {
      return RestoreResult.invalid;
    }

    try {
      // 3. Checkpoint current DB
      try {
        await db.customStatement('PRAGMA wal_checkpoint(FULL)');
      } catch (_) {}

      // 4. Safety backup of current DB
      final dbFile = await _getDbFile();
      if (await dbFile.exists()) {
        final dir = await getApplicationDocumentsDirectory();
        final safety = File(p.join(dir.path, 'BillMed_pre_restore_${_timestamp()}.db'));
        await dbFile.copy(safety.path);
      }

      // 5. Close DB, replace file, done
      await db.close();
      await source.copy(dbFile.path);

      return RestoreResult.success;
    } catch (_) {
      return RestoreResult.invalid;
    }
  }

  static String _timestamp() {
    final d = DateTime.now();
    return '${d.year}${_pad(d.month)}${_pad(d.day)}_${_pad(d.hour)}${_pad(d.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}

// ─── Result types ─────────────────────────────────────────────────────────────
enum RestoreResult { success, cancelled, invalid }
