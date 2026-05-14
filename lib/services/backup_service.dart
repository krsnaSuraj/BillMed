import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../database/database.dart';

class BackupService {
  static Future<String?> exportBackup(BillMedDatabase db) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File('${dir.path}/billmed.db');
    if (!await dbFile.exists()) return null;

    final extDir = await getExternalStorageDirectory();
    final backupDir = extDir ?? dir;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backup = File('${backupDir.path}/BillMed_backup_$timestamp.db');
    await dbFile.copy(backup.path);
    await Share.shareXFiles([XFile(backup.path)], text: 'BillMed Backup');
    return backup.path;
  }

  static Future<void> autoBackup(BillMedDatabase db) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/billmed.db');
      if (!await dbFile.exists()) return;

      final extDir = await getExternalStorageDirectory();
      if (extDir == null) return;

      final backup = File('${extDir.path}/BillMed_auto_backup.db');
      await dbFile.copy(backup.path);
    } catch (_) {}
  }

  static Future<bool> importBackup(BillMedDatabase db) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return false;

    final source = File(result.files.single.path!);
    if (!await source.exists()) return false;

    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/billmed.db');

    // Close database before replacing file
    await db.close();

    // Replace database file
    await source.copy(dest.path);

    return true; // App must restart to reinitialize DB
  }
}
