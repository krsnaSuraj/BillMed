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

    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) {
      final external = await getExternalStorageDirectory();
      if (external == null) return null;
      final backup = File('${external.path}/BillMed_backup_${DateTime.now().millisecondsSinceEpoch}.db');
      await dbFile.copy(backup.path);
      await Share.shareXFiles([XFile(backup.path)], text: 'BillMed Backup');
      return backup.path;
    }

    final backup = File('${downloadsDir.path}/BillMed_backup_${DateTime.now().millisecondsSinceEpoch}.db');
    await dbFile.copy(backup.path);
    await Share.shareXFiles([XFile(backup.path)], text: 'BillMed Backup');
    return backup.path;
  }

  static Future<void> autoBackup(BillMedDatabase db) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File('${dir.path}/billmed.db');
    if (!await dbFile.exists()) return;

    final downloadsDir = Directory('/storage/emulated/0/Download');
    if (!await downloadsDir.exists()) return;

    final backup = File('${downloadsDir.path}/BillMed_auto_backup.db');
    await dbFile.copy(backup.path);
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

    // Close current database connection
    await db.close();

    // Replace database file
    await source.copy(dest.path);

    return true;
  }
}
