import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _repoOwner = 'krsnaSuraj';
  static const String _repoName = 'BillMed';
  static const String _githubApi =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse(_githubApi))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final latestTag = data['tag_name'] as String? ?? '';
      if (latestTag.isEmpty) return;

      final latestVersion = latestTag.replaceAll('v', '').trim();
      final current = currentVersion.trim();

      if (latestVersion == current) return;
      if (!_isNewer(latestVersion, current)) return;

      final assets = data['assets'] as List? ?? [];
      String? downloadUrl;
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      if (context.mounted && downloadUrl != null) {
        _showUpdateDialog(context, latestVersion, downloadUrl);
      }
    } catch (_) {}
  }

  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = l.length > c.length ? l.length : c.length;
    for (int i = 0; i < len; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static void _showUpdateDialog(
      BuildContext context, String version, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update, color: Colors.blue, size: 28),
            SizedBox(width: 10),
            Text('Update Available'),
          ],
        ),
        content: Text(
          'BillMed v$version is ready.\n\n'
          'Tap Update to download and install.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Update', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
