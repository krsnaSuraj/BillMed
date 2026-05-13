import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() => _version = '${info.version}+${info.buildNumber}');
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
          _buildSection(context, 'Appearance', [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch to dark theme'),
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: isDark ? AppColors.warning : AppColors.info,
              ),
              value: isDark,
              activeColor: AppColors.accent,
              onChanged: (v) {
                ref.read(themeModeProvider.notifier).state =
                    v ? ThemeMode.dark : ThemeMode.light;
              },
            ),
          ]),
          _buildSection(context, 'Data', [
            ListTile(
              leading: const Icon(Icons.backup, color: AppColors.accent),
              title: const Text('Auto Backup'),
              subtitle: const Text('Enabled (Google Drive)'),
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined, color: AppColors.info),
              title: const Text('Export Data'),
              subtitle: const Text('CSV / Excel format'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ]),
          _buildSection(context, 'About', [
            ListTile(
              leading: const Icon(Icons.info_outline, color: AppColors.accent),
              title: const Text('Version'),
              subtitle: Text(_version.isNotEmpty ? 'v$_version' : 'Loading...'),
            ),
            ListTile(
              leading: const Icon(Icons.code, color: AppColors.textSecondary),
              title: const Text('Built with Flutter'),
              subtitle: const Text('Drift + Riverpod'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: items),
        ),
      ],
    );
  }
}
