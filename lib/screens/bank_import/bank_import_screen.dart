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
          const SizedBox(height: 8),
          Text(
            'Supports Canara, SBI, HDFC, ICICI, PNB, Axis, Kotak, BOB and all major Indian banks.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
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
            Row(children: [
              const Icon(Icons.help_outline, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const Divider(height: 16),
            _infoRow(Icons.picture_as_pdf, 'Download your bank statement PDF from NetBanking or bank app'),
            _infoRow(Icons.upload_file, 'Tap "Select PDF" above and choose that file'),
            _infoRow(Icons.auto_awesome, 'App auto-detects your bank and parses transactions'),
            _infoRow(Icons.preview, 'Review the parsed transactions before saving'),
            _infoRow(Icons.check_circle, 'Balance is verified — mismatches are flagged clearly'),
            _infoRow(Icons.edit_note, 'You can edit/correct any transaction before saving'),
            const Divider(height: 16),
            const Text('Supported Banks', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: [
                for (final b in ['Canara', 'SBI', 'HDFC', 'ICICI', 'PNB', 'Axis', 'Kotak', 'BOB', 'Union', 'Yes', 'IndusInd', 'Federal', 'IDFC', '+ More'])
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(b, style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tips_and_updates, color: AppColors.info, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'For best accuracy: Add a free Gemini API key in Settings. It uses Google AI to parse even complex PDF formats.',
                    style: TextStyle(fontSize: 12, color: AppColors.info),
                  )),
                ],
              ),
            ),
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
