import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database.dart';

class BackupService {
  // ─── Get DB file path (same path used by Drift) ───────────────────────────
  static Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'billmed.db'));
  }

  // ─── Manual Backup ─────────────────────────────────────────────────────────
  static Future<String?> exportBackup(BillMedDatabase db) async {
    try {
      // Checkpoint WAL to make sure all writes are flushed to the main DB file
      await db.customStatement('PRAGMA wal_checkpoint(FULL)');

      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        return null;
      }

      // Save to app documents with timestamp
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat.fromStr(DateTime.now());
      final backupFile =
          File(p.join(dir.path, 'BillMed_backup_$timestamp.db'));
      await dbFile.copy(backupFile.path);

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'BillMed Backup - $timestamp',
      );
      return backupFile.path;
    } catch (e) {
      return null;
    }
  }

  // ─── Auto Backup (on app pause) ───────────────────────────────────────────
  static Future<void> autoBackup(BillMedDatabase db) async {
    try {
      // Flush WAL
      await db.customStatement('PRAGMA wal_checkpoint(PASSIVE)');

      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) return;

      final dir = await getApplicationDocumentsDirectory();
      final backup =
          File(p.join(dir.path, 'BillMed_auto_backup.db'));
      await dbFile.copy(backup.path);
    } catch (_) {
      // Silent fail — auto backup is best-effort
    }
  }

  // ─── Restore from Backup ───────────────────────────────────────────────────
  /// Returns: 'success', 'cancelled', or 'invalid'
  static Future<RestoreResult> importBackup(BillMedDatabase db) async {
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

    // Validate: check SQLite magic header (first 16 bytes = "SQLite format 3\000")
    try {
      final header = await source.openRead(0, 16).first;
      final magic = String.fromCharCodes(header.take(15));
      if (!magic.startsWith('SQLite format 3')) {
        return RestoreResult.invalid;
      }
    } catch (_) {
      return RestoreResult.invalid;
    }

    try {
      // Checkpoint + close DB before replacing the file
      await db.customStatement('PRAGMA wal_checkpoint(FULL)');
      await db.close();

      final dest = await _getDbFile();

      // Backup current DB before overwriting (safety net)
      final dir = await getApplicationDocumentsDirectory();
      final safety = File(p.join(dir.path, 'billmed_pre_restore.db'));
      if (await dest.exists()) {
        await dest.copy(safety.path);
      }

      await source.copy(dest.path);
      return RestoreResult.success;
    } catch (_) {
      return RestoreResult.invalid;
    }
  }
}

// ─── Result enum ──────────────────────────────────────────────────────────────
enum RestoreResult { success, cancelled, invalid }

// Simple date formatter (avoids intl import in service layer)
class DateFormat {
  static String fromStr(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}_'
      '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}';
}
