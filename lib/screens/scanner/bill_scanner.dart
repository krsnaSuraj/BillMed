import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class BillScanResult {
  final String? billNumber;
  final DateTime? billDate;
  final double? amount;
  final String rawText;

  BillScanResult({
    this.billNumber,
    this.billDate,
    this.amount,
    required this.rawText,
  });

  bool get hasData => billNumber != null || amount != null;
}

class BillScanner {
  static Future<BillScanResult?> scanFromCamera(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, maxWidth: 2048);
    if (image == null) return null;
    return _processImage(context, File(image.path));
  }

  static Future<BillScanResult?> scanFromGallery(BuildContext context) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 2048);
    if (image == null) return null;
    return _processImage(context, File(image.path));
  }

  static Future<BillScanResult?> _processImage(BuildContext context, File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(inputImage);
      final text = result.text;
      if (text.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in image')),
          );
        }
        return null;
      }
      return _parseBillText(text);
    } finally {
      recognizer.close();
    }
  }

  static BillScanResult _parseBillText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? billNumber;
    DateTime? billDate;
    double? amount;
    String? distributorName;

    // Try to find distributor name (first few non-empty lines, exclude common keywords)
    for (final line in lines.take(6)) {
      final upper = line.toUpperCase();
      if (!upper.contains('GST') && !upper.contains('INVOICE') && !upper.contains('BILL')
          && !upper.contains('ADDRESS') && !upper.contains('PHONE') && !upper.contains('EMAIL')
          && !upper.contains('TAX') && !upper.contains('DATE') && !upper.contains('TOTAL')
          && line.length > 3 && line.length < 60) {
        distributorName = line;
        break;
      }
    }

    // Find bill/invoice number
    for (final line in lines) {
      final match = RegExp(r'(?:bill|invoice|inv)(?:\s*#|\s*no\.?|\s*:|\s+)\s*([A-Z0-9][A-Z0-9\/\-.]+)', caseSensitive: false).firstMatch(line);
      if (match != null) {
        billNumber = match.group(1)!.trim();
        break;
      }
    }

    // Find date
    for (final line in lines) {
      final match = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})').firstMatch(line);
      if (match != null) {
        try {
          final d = int.parse(match.group(1)!);
          final m = int.parse(match.group(2)!);
          var y = int.parse(match.group(3)!);
          if (y < 100) y += 2000;
          billDate = DateTime(y, m, d);
          break;
        } catch (_) {}
      }
    }

    // If no date, find date near "Date:" keyword
    if (billDate == null) {
      for (final line in lines) {
        final match = RegExp(r'date\s*:?\s*(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})', caseSensitive: false).firstMatch(line);
        if (match != null) {
          try {
            final d = int.parse(match.group(1)!);
            final m = int.parse(match.group(2)!);
            var y = int.parse(match.group(3)!);
            if (y < 100) y += 2000;
            billDate = DateTime(y, m, d);
            break;
          } catch (_) {}
        }
      }
    }

    // Find total amount
    for (final line in lines) {
      final match = RegExp(r'(?:total|grand total|amount|net amount|payable)\s*:?\s*(?:rs\.?|inr)?\s*([0-9,]+\.?\d*)', caseSensitive: false).firstMatch(line);
      if (match != null) {
        final amtStr = match.group(1)!.replaceAll(',', '');
        amount = double.tryParse(amtStr);
        if (amount != null) break;
      }
    }

    // If no amount found, look for largest number near "total"
    if (amount == null) {
      for (final line in lines) {
        if (line.toLowerCase().contains('total')) {
          final nums = RegExp(r'([0-9,]+\.\d{2})').allMatches(line).toList();
          if (nums.isNotEmpty) {
            final last = nums.last.group(1)!.replaceAll(',', '');
            amount = double.tryParse(last);
            if (amount != null) break;
          }
        }
      }
    }

    return BillScanResult(
      billNumber: billNumber,
      billDate: billDate,
      amount: amount,
      rawText: text,
    );
  }
}

class ScanPreviewScreen extends StatelessWidget {
  final BillScanResult result;
  const ScanPreviewScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Result')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Extracted Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _field('Bill Number', result.billNumber ?? 'Not found'),
                  _field('Date', result.billDate != null ? DateFormat('dd/MM/yyyy').format(result.billDate!) : 'Not found'),
                  _field('Amount', result.amount != null ? '₹${result.amount!.toStringAsFixed(2)}' : 'Not found'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, result),
            icon: const Icon(Icons.check),
            label: const Text('Use This Data'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Raw Text'),
                  content: SingleChildScrollView(
                    child: SelectableText(result.rawText, style: const TextStyle(fontSize: 13)),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                ),
              );
            },
            icon: const Icon(Icons.text_snippet),
            label: const Text('View Raw Text'),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
