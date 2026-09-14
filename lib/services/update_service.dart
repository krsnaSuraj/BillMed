import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _repoOwner = 'krsnaSuraj';
  static const String _repoName = 'BillMed';
  static const String _releasesUrl =
      'https://github.com/$_repoOwner/$_repoName/releases/latest';

  /// Manual check from Settings — always shows feedback.
  static Future<void> manualCheck(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();
      final currentBuild = int.tryParse(packageInfo.buildNumber.trim());

      final response = await http
          .get(Uri.parse(
              'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) throw Exception('network');
      // A release body is a few kilobytes. Refuse to decode something absurd
      // instead of buffering it into the UI isolate.
      if (response.bodyBytes.length > 256 * 1024) {
        throw Exception('oversized');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final latestTag = data['tag_name'] as String? ?? '';
      final version = versionFromTag(latestTag);
      if (version.isEmpty) throw Exception('empty-version');
      final (latestVersion, latestBuild) = _splitVersionBuild(version);
      final apkAsset = _hasApkAsset(data);

      if (!_isUpdateAvailable(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        latestBuild: latestBuild,
        currentBuild: currentBuild,
      )) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('You are on the latest version.'),
            backgroundColor: Color(0xFF10B981),
          ));
        }
        return;
      }
      // A newer tag without an installable APK is not "latest" — say so.
      if (!apkAsset) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('A newer release exists but has no installable file yet.'),
            backgroundColor: Color(0xFFF59E0B),
          ));
        }
        return;
      }

      if (context.mounted) _showUpdateDialog(context, latestVersion);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not check for updates. Are you online?'),
          backgroundColor: Color(0xFFEF4444),
        ));
      }
    }
  }

  static String _stripTag(String tag) {
    final t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) return t.substring(1).trim();
    return t;
  }

  /// The tag comes from the network and is rendered inside a dialog that looks
  /// like a system prompt, so only a version-shaped string is accepted: a
  /// hostile or malformed tag makes the check fail closed instead of printing
  /// arbitrary text ("9.9.9 — tap Update to restore your data") or a
  /// multi-megabyte string.
  @visibleForTesting
  static String versionFromTag(String tag) {
    final stripped = _stripTag(tag);
    if (stripped.isEmpty || stripped.length > 24) return '';
    if (!RegExp(r'^\d{1,4}(\.\d{1,4}){0,2}([-+][0-9A-Za-z.\-]{0,20})?$')
        .hasMatch(stripped)) {
      return '';
    }
    return stripped;
  }

  static bool _hasApkAsset(Map<String, dynamic> data) {
    final assets = data['assets'] as List?;
    if (assets == null) return false;
    return assets
        .whereType<Map>()
        .any((a) => (a['name'] as String? ?? '').endsWith('.apk'));
  }

  static (String, int?) _splitVersionBuild(String stripped) {
    final s = stripped.trim();
    final plus = s.lastIndexOf('+');
    if (plus < 0) return (s, null);
    final core = s.substring(0, plus).trim();
    final build = int.tryParse(s.substring(plus + 1).trim());
    return (core, build);
  }

  static bool _isUpdateAvailable({
    required String latestVersion,
    required String currentVersion,
    int? latestBuild,
    int? currentBuild,
  }) {
    if (_isNewer(latestVersion, currentVersion)) return true;
    if (_isNewer(currentVersion, latestVersion)) return false;
    if (latestBuild != null && currentBuild != null) {
      return latestBuild > currentBuild;
    }
    return false;
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

  static void _showUpdateDialog(BuildContext context, String version) {
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
          'BillMed v$version is ready.\n\nTap Update to go to the download page.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(_releasesUrl);
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                // Fallback: try platform default
                try {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                } catch (_) {}
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
