import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/database_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/backup_service.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';
  bool _backupBusy = false;
  bool _restoreBusy = false;
  bool _checkingUpdate = false;
  String? _lastBackupLabel;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadLastBackup();
  }

  /// Scans app storage for the newest backup file so the user can always
  /// see and re-share it. Manual backups win over the auto snapshot.
  Future<void> _loadLastBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>().where((f) {
        final name = p.basename(f.path);
        return name.startsWith('BillMed_backup_') ||
            name == 'BillMed_auto_backup.db';
      }).toList();
      if (files.isEmpty) {
        if (mounted) setState(() => _lastBackupLabel = null);
        return;
      }
      files
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final manual =
          files.where((f) => p.basename(f.path).startsWith('BillMed_backup_'));
      final latest = manual.isNotEmpty ? manual.first : files.first;
      final stat = latest.lastModifiedSync();
      final sizeKb = (latest.lengthSync() / 1024).ceil();
      final kind = p.basename(latest.path).startsWith('BillMed_backup_')
          ? 'Backup'
          : 'Auto backup';
      final label =
          '$kind · ${DateFormat('d MMM, HH:mm').format(stat)} · $sizeKb KB';
      if (mounted) setState(() => _lastBackupLabel = label);
    } catch (_) {
      if (mounted) setState(() => _lastBackupLabel = null);
    }
  }

  /// Re-shares the newest backup file (the share sheet can be dismissed).
  /// Manual backups win; the auto snapshot is the fallback so the tile
  /// never promises a file it cannot deliver.
  Future<void> _reshareBackup() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>().where((f) {
        final name = p.basename(f.path);
        return name.startsWith('BillMed_backup_') ||
            name == 'BillMed_auto_backup.db';
      }).toList();
      if (files.isEmpty) {
        if (!mounted) return;
        showAppSnack(context, 'No backup yet — tap Backup Now first.',
            success: false);
        return;
      }
      files
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final manual =
          files.where((f) => p.basename(f.path).startsWith('BillMed_backup_'));
      final latest = manual.isNotEmpty ? manual.first : files.first;
      // Never share a torn snapshot (e.g. a kill mid-export left a
      // partial that the loader would otherwise offer).
      if (!await latest.exists() || await latest.length() < 100) {
        if (!mounted) return;
        showAppSnack(context, 'Latest backup is incomplete — tap Backup Now.',
            success: false);
        return;
      }
      final raf = latest.openSync();
      try {
        final header = raf.readSync(15);
        if (header.length < 15 ||
            String.fromCharCodes(header) != 'SQLite format 3') {
          if (!mounted) return;
          showAppSnack(context, 'Latest backup is incomplete — tap Backup Now.',
              success: false);
          return;
        }
      } finally {
        raf.closeSync();
      }
      await Share.shareXFiles(
        [XFile(latest.path)],
        text: 'BillMed Backup — save this file securely.',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not share backup — please try again.',
          success: false);
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version}+${info.buildNumber}');
    }
  }

  Future<void> _manualBackup() async {
    setState(() => _backupBusy = true);
    try {
      final db = ref.read(databaseProvider);
      final path = await BackupService.exportBackup(db);
      if (!mounted) return;
      await _loadLastBackup();
      if (!mounted) return;
      if (path != null) {
        showAppSnack(context, 'Backup saved on this phone.');
      } else if (BackupService.isBusy) {
        showAppSnack(context, 'A backup is running — please try again.',
            success: false);
      } else {
        showAppSnack(context, 'Backup failed — please try again.',
            success: false);
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Backup failed — please try again.',
            success: false);
      }
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await confirmSheet(
      context,
      title: 'Restore from backup?',
      message: 'Your CURRENT data will be replaced by the backup file.\n\n'
          'A safety copy of your current data will be saved first.',
      confirmLabel: 'Continue',
    );
    if (!confirmed) return;

    setState(() => _restoreBusy = true);
    try {
      final db = ref.read(databaseProvider);
      final result = await BackupService.importBackup(db);
      if (!mounted) return;
      switch (result) {
        case RestoreResult.successRequiresRestart:
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PopScope(
              canPop: false,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Restore Complete',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(ctx),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        defaultTargetPlatform == TargetPlatform.iOS
                            ? 'Your data has been restored.\n\nFully swipe away BillMed, then reopen it to finish.'
                            : 'Your data has been restored.\n\nClose and reopen BillMed to finish.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.subtitleColor(ctx),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          // SystemNavigator.pop is Android-only: on iOS it is a
                          // no-op that would leave the app running on a closed
                          // database, so guide the user to reopen manually.
                          if (defaultTargetPlatform == TargetPlatform.iOS) {
                            if (mounted) {
                              showAppSnack(context,
                                  'Swipe away BillMed and reopen it to finish.');
                            }
                            return;
                          }
                          SystemNavigator.pop();
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Close App Now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          break;
        case RestoreResult.invalid:
          showAppSnack(context,
              'Invalid file. Select a valid BillMed backup (.db) file.',
              success: false);
          break;
        case RestoreResult.cancelled:
          break;
        case RestoreResult.failedRestartRequired:
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => PopScope(
              canPop: false,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'Restore Failed',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(ctx),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        defaultTargetPlatform == TargetPlatform.iOS
                            ? 'The restore could not be completed.\n\nFully swipe away BillMed, then reopen it — your previous data is safe.'
                            : 'The restore could not be completed.\n\nClose and reopen BillMed — your previous data is safe.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.subtitleColor(ctx),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (defaultTargetPlatform == TargetPlatform.iOS) {
                            if (mounted) {
                              showAppSnack(
                                  context, 'Swipe away BillMed and reopen it.');
                            }
                            return;
                          }
                          SystemNavigator.pop();
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Close App'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          break;
        case RestoreResult.busy:
          showAppSnack(context, 'A backup is running — please try again.',
              success: false);
          break;
        case RestoreResult.safetyFailed:
          showAppSnack(
              context,
              'Could not protect current data — restore cancelled. '
              'Free up space and try again.',
              success: false);
          break;
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Restore failed — please try again.',
            success: false);
      }
    } finally {
      if (mounted) setState(() => _restoreBusy = false);
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    try {
      await UpdateService.manualCheck(context);
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _setTheme(ThemeMode mode) {
    AppHaptics.select();
    ref.read(themeModeProvider.notifier).state = mode;
    persistThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const MeshHeader(height: 200),
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textColor(context),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Preferences, data and updates',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.subtitleColor(context),
                  ),
                ),
                const SizedBox(height: 14),
                _profileHero(),
                const SizedBox(height: 20),
                const SectionHeader(title: 'DISPLAY'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.settings_brightness),
                          label: Text('System'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (modes) => _setTheme(modes.first),
                      style: SegmentedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'DATA'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        minVerticalPadding: 12,
                        leading: const Icon(Icons.phone_android,
                            color: AppColors.info),
                        title: const Text('Move Data to a New Phone'),
                        subtitle: const Text('Step-by-step guide'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          AppHaptics.select();
                          _showTransferGuide();
                        },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        minVerticalPadding: 12,
                        leading: Icon(Icons.backup_outlined,
                            color: _backupBusy
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : AppColors.accent),
                        title: const Text('Backup Now'),
                        subtitle: Text(
                          _backupBusy
                              ? 'Preparing backup file...'
                              : 'Export your full database as a shareable file',
                        ),
                        trailing: _busyTrailing(_backupBusy),
                        onTap: (_backupBusy || _restoreBusy)
                            ? null
                            : _manualBackup,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        minVerticalPadding: 12,
                        leading:
                            const Icon(Icons.history, color: AppColors.success),
                        title: const Text('My Backups'),
                        subtitle: Text(
                          _lastBackupLabel ?? 'No backup saved yet',
                        ),
                        trailing: const Icon(Icons.ios_share),
                        onTap: (_backupBusy || _restoreBusy)
                            ? null
                            : () {
                                AppHaptics.select();
                                _reshareBackup();
                              },
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        minVerticalPadding: 12,
                        leading: Icon(Icons.restore,
                            color: _restoreBusy
                                ? Theme.of(context).colorScheme.onSurfaceVariant
                                : AppColors.warning),
                        title: const Text('Restore from Backup'),
                        subtitle: const Text(
                            'Replace current data with a backup file'),
                        trailing: _busyTrailing(_restoreBusy),
                        onTap: (_backupBusy || _restoreBusy)
                            ? null
                            : _restoreBackup,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionHeader(title: 'ABOUT'),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        minVerticalPadding: 12,
                        leading: const Icon(Icons.system_update,
                            color: AppColors.info),
                        title: const Text('Check for Updates'),
                        subtitle: const Text(
                            'Opens GitHub releases page when a new version exists'),
                        trailing: _checkingUpdate
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right),
                        onTap: _checkingUpdate ? null : _checkForUpdate,
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        minVerticalPadding: 12,
                        leading: const Icon(Icons.info_outline,
                            color: AppColors.accent),
                        title: const Text('Version'),
                        subtitle:
                            Text(_version.isNotEmpty ? 'v$_version' : '...'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadow.hero(context),
        border: AppShadow.cardBorder(context),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppGradients.sheen,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Row(
            children: [
              const BrandLogo(size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BillMed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Supplier Khata & Payments',
                      style: TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _version.isNotEmpty ? 'v$_version' : 'v...',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 32,
                  color: Colors.white30,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _busyTrailing(bool busy) => busy
      ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2))
      : const Icon(Icons.chevron_right);

  void _showTransferGuide() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(children: [
                const BrandLogo(size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Move Data to a New Phone',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textColor(ctx),
                    ),
                  ),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Follow these steps to safely move all your records:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textColor(ctx),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _step(
                        '1',
                        'Backup on OLD phone',
                        'Settings > Backup Now > save the .db file somewhere safe.',
                        AppColors.accent),
                    _step(
                        '2',
                        'Save the file',
                        'Google Drive, email to yourself, or your PC.',
                        AppColors.info),
                    _step(
                        '3',
                        'Install BillMed on NEW phone',
                        'Install the same app on the new phone.',
                        AppColors.success),
                    _step(
                        '4',
                        'Open BillMed once',
                        'Open it at least one time so it creates its folder.',
                        AppColors.warning),
                    _step(
                        '5',
                        'Restore on NEW phone',
                        'Settings > Restore from Backup > pick your .db file.',
                        AppColors.danger),
                    _step(
                        '6',
                        'Close and reopen the app',
                        'All bills, payments and suppliers are restored.',
                        AppColors.success),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.tips_and_updates,
                            color: AppColors.success, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          'Tip: take a backup every week. The file is NOT encrypted — store it somewhere only you can access.',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.success),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        // Pop the guide first so the backup result snackbar
                        // is visible on the Settings page underneath.
                        Navigator.pop(ctx);
                        Future.microtask(() => _manualBackup());
                      },
                      icon: const Icon(Icons.backup_outlined, size: 18),
                      label: const Text('Backup Now'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String num, String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(num,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(desc,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ])),
      ]),
    );
  }
}
