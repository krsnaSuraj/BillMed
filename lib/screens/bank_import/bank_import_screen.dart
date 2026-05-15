import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/bank_statement_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/gemini_provider.dart';
import 'bank_preview_screen.dart';
import 'manual_entry_screen.dart';

class BankImportScreen extends ConsumerStatefulWidget {
  const BankImportScreen({super.key});

  @override
  ConsumerState<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends ConsumerState<BankImportScreen> {
  bool _loading = false;
  String? _filePath;
  String? _fileName;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _filePath = result.files.single.path;
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _parse() async {
    if (_filePath == null) return;
    setState(() => _loading = true);

    try {
      final geminiKey = ref.read(geminiKeyProvider);
      final result = await BankStatementService.parseStatement(
        pdfPath: _filePath!,
        geminiKey: geminiKey.isNotEmpty ? geminiKey : null,
      );

      if (!mounted) return;

      // If we got ANY transactions, always go to preview screen
      // (user can choose to save or not after seeing the data)
      if (result.transactions.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BankPreviewScreen(
              transactions: result.transactions,
              fileName: _fileName ?? 'Unknown',
              status: result.status,
              message: result.message,
            ),
          ),
        );
        return;
      }

      // Truly zero transactions — offer manual entry
      final goManual = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Could Not Parse PDF'),
          content: Text(
            result.message.isNotEmpty
                ? result.message
                : 'No transactions could be extracted from this PDF.\n\n'
                    'Make sure:\n'
                    '• The PDF is a bank statement (not a scanned image)\n'
                    '• The PDF is not password-protected\n'
                    '• Try with a Gemini API key for better accuracy',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enter Manually'),
            ),
          ],
        ),
      );
      if (goManual == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManualEntryScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasGeminiKey = ref.watch(geminiKeyProvider).isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('Import Bank Statement')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(Icons.account_balance, size: 64, color: AppColors.accent),
          const SizedBox(height: 16),
          const Text(
            'Import PDF Bank Statement',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a bank statement PDF to import transactions.\nSupports SBI, HDFC, ICICI, Axis, Canara and more.',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (!hasGeminiKey) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Set a Gemini API key in Settings for much better parsing accuracy.',
                      style: TextStyle(fontSize: 13, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            child: InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      _filePath != null ? Icons.description : Icons.upload_file,
                      size: 48,
                      color: _filePath != null ? AppColors.success : AppColors.info,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _filePath != null ? _fileName! : 'Tap to select PDF',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _filePath != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (_filePath != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatSize(File(_filePath!).lengthSync()),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: (_filePath != null && !_loading) ? _parse : null,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Parse & Import'),
          ),

          const SizedBox(height: 16),
          _buildInfoSection(),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How it works',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _infoRow(Icons.auto_awesome, 'AI (Gemini) parses for best accuracy'),
            _infoRow(Icons.security, 'Your data stays on your device'),
            _infoRow(Icons.verified, 'Balance verified before you save'),
            _infoRow(Icons.edit, 'Preview & correct before importing'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
