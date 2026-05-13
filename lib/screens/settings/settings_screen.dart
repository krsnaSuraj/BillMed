import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../providers/database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/export_service.dart';
import '../../services/backup_service.dart';
import '../../theme/app_theme.dart';
import '../reports/reports_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = '${info.version}+${info.buildNumber}');
  }

  Future<void> _export(String type) async {
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      await ExportService.exportToCsv(db, type: type);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _manualBackup() async {
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService.exportBackup(db);
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup exported successfully')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _exporting = true);
    try {
      final db = ref.read(databaseProvider);
      final success = await BackupService.importBackup(db);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Backup restored. Restart the app.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restore cancelled')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          _section('Appearance', [
            ListTile(
              leading: Icon(Icons.light_mode, color: themeMode == ThemeMode.light ? AppColors.warning : AppColors.textSecondary),
              title: const Text('Light Mode'),
              trailing: themeMode == ThemeMode.light ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.light,
            ),
            ListTile(
              leading: Icon(Icons.dark_mode, color: themeMode == ThemeMode.dark ? AppColors.warning : AppColors.textSecondary),
              title: const Text('Dark Mode'),
              trailing: themeMode == ThemeMode.dark ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.dark,
            ),
            ListTile(
              leading: Icon(Icons.settings_brightness, color: themeMode == ThemeMode.system ? AppColors.warning : AppColors.textSecondary),
              title: const Text('System Default'),
              subtitle: const Text('Follow device setting'),
              trailing: themeMode == ThemeMode.system ? const Icon(Icons.check, color: AppColors.accent) : null,
              onTap: () => ref.read(themeModeProvider.notifier).state = ThemeMode.system,
            ),
          ]),
          _section('Reports', [
            ListTile(
              leading: const Icon(Icons.bar_chart, color: AppColors.info),
              title: const Text('View Reports'),
              subtitle: const Text('Summary & distributor breakdown'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
            ),
          ]),
          _section('Backup & Export', [
            ListTile(
              leading: const Icon(Icons.backup, color: AppColors.accent),
              title: const Text('Auto Backup'),
              subtitle: const Text('Android Auto Backup (Google Drive)'),
            ),
            ListTile(
              leading: Icon(Icons.backup_outlined, color: _exporting ? AppColors.textSecondary : AppColors.accent),
              title: const Text('Manual Backup'),
              subtitle: const Text('Export database file'),
              trailing: _exporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _exporting ? null : () => _manualBackup(),
            ),
            ListTile(
              leading: Icon(Icons.restore, color: _exporting ? AppColors.textSecondary : AppColors.warning),
              title: const Text('Restore from Backup'),
              subtitle: const Text('Import .db file'),
              trailing: _exporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _exporting ? null : () => _restoreBackup(),
            ),
            ListTile(
              leading: Icon(Icons.file_download, color: _exporting ? AppColors.textSecondary : AppColors.info),
              title: const Text('Export Distributors'),
              subtitle: const Text('CSV file'),
              trailing: _exporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _exporting ? null : () => _export('distributors'),
            ),
            ListTile(
              leading: Icon(Icons.receipt_long, color: _exporting ? AppColors.textSecondary : AppColors.info),
              title: const Text('Export Bills'),
              subtitle: const Text('CSV file'),
              trailing: _exporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _exporting ? null : () => _export('bills'),
            ),
            ListTile(
              leading: Icon(Icons.payment, color: _exporting ? AppColors.textSecondary : AppColors.info),
              title: const Text('Export Payments'),
              subtitle: const Text('CSV file'),
              trailing: _exporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _exporting ? null : () => _export('payments'),
            ),
            ListTile(
              leading: Icon(Icons.file_download_done, color: _exporting ? AppColors.textSecondary : AppColors.success),
              title: const Text('Export All Data'),
              subtitle: const Text('Distributors + Bills + Payments'),
              trailing: _exporting ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
              onTap: _exporting ? null : () => _export('all'),
            ),
          ]),
          _section('About', [
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.accent),
              title: const Text('Version'),
              subtitle: Text(_version.isNotEmpty ? 'v$_version' : 'Loading...'),
            ),
            ListTile(
              leading: const Icon(Icons.code, color: AppColors.textSecondary),
              title: const Text('Built with'),
              subtitle: const Text('Flutter · Drift · Riverpod'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.accent, letterSpacing: 0.5)),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: tiles),
        ),
      ],
    );
  }
}
