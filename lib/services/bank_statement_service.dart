import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import '../database/database.dart';

class BankStatementResult {
  final List<ParsedTransaction> transactions;
  final String status;
  final String message;
  final String method;

  BankStatementResult({
    required this.transactions,
    this.status = 'VERIFIED',
    this.message = '',
    this.method = 'api',
  });
}

class ParsedTransaction {
  final DateTime txnDate;
  final String description;
  final double debit;
  final double credit;
  final double balance;

  ParsedTransaction({
    required this.txnDate,
    required this.description,
    this.debit = 0,
    this.credit = 0,
    this.balance = 0,
  });
}

class BankStatementService {
  // Cloudflare Worker URL (API key yaha safe hai)
  static const String _workerUrl = 'https://billmed-bank-parser.your-worker.workers.dev';

  static Future<BankStatementResult> parseStatement({
    required String pdfPath,
    String? password,
  }) async {
    // Try API first
    try {
      final result = await _parseViaWorker(pdfPath, password);
      if (result.status != 'FAILED' && result.transactions.isNotEmpty) {
        return result;
      }
    } catch (_) {}

    // Fallback: regex parser
    try {
      final result = await _parseViaRegex(pdfPath);
      if (result.transactions.isNotEmpty) {
        return result;
      }
    } catch (_) {}

    return BankStatementResult(
      transactions: [],
      status: 'FAILED',
      message: 'Could not parse statement. Try manual entry.',
      method: 'manual',
    );
  }

  static Future<BankStatementResult> _parseViaWorker(String pdfPath, String? password) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      return BankStatementResult(transactions: [], status: 'FAILED', message: 'File not found');
    }

    final bytes = await file.readAsBytes();
    final base64 = base64Encode(bytes);

    final response = await http
        .post(
          Uri.parse(_workerUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'pdf_base64': base64,
            'password': password ?? '',
            'filename': pdfPath.split('/').last.split('\\').last,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      return BankStatementResult(transactions: [], status: 'FAILED', message: 'API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final txnList = (data['transactions'] as List?) ?? [];
    final status = data['status'] as String? ?? 'FAILED';

    return BankStatementResult(
      transactions: txnList.map((t) {
        DateTime? date;
        if (t['date'] != null) {
          date = DateTime.tryParse(t['date'].toString());
        }
        return ParsedTransaction(
          txnDate: date ?? DateTime.now(),
          description: t['description']?.toString() ?? '',
          debit: (t['debit'] ?? 0).runtimeType == double
              ? t['debit'] as double
              : double.tryParse(t['debit']?.toString() ?? '0') ?? 0,
          credit: (t['credit'] ?? 0).runtimeType == double
              ? t['credit'] as double
              : double.tryParse(t['credit']?.toString() ?? '0') ?? 0,
          balance: (t['balance'] ?? 0).runtimeType == double
              ? t['balance'] as double
              : double.tryParse(t['balance']?.toString() ?? '0') ?? 0,
        );
      }).toList(),
      status: status,
      message: data['message'] as String? ?? '',
      method: 'api',
    );
  }

  static Future<BankStatementResult> _parseViaRegex(String pdfPath) async {
    // Extract text using basic PDF text reading
    final file = File(pdfPath);
    final bytes = await file.readAsBytes();
    final text = _extractTextFromPdf(bytes);

    if (text.isEmpty) {
      return BankStatementResult(transactions: [], status: 'FAILED', message: 'No text found in PDF');
    }

    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final transactions = <ParsedTransaction>[];
    final datePattern = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    final amountPattern = RegExp(r'([0-9,]+\.\d{2})');

    for (final line in lines) {
      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch == null) continue;

      try {
        final d = int.parse(dateMatch.group(1)!);
        final m = int.parse(dateMatch.group(2)!);
        var y = int.parse(dateMatch.group(3)!);
        if (y < 100) y += 2000;
        final date = DateTime(y, m, d);

        final amounts = amountPattern.allMatches(line).map((a) =>
            double.tryParse(a.group(1)!.replaceAll(',', '')) ?? 0).toList();

        if (amounts.isEmpty) continue;

        double debit = 0, credit = 0, balance = 0;
        if (amounts.length >= 3) {
          balance = amounts.last;
          debit = amounts[amounts.length - 2];
          credit = amounts[amounts.length - 3];
        } else if (amounts.length == 2) {
          balance = amounts.last;
          debit = amounts.first;
        }

        transactions.add(ParsedTransaction(
          txnDate: date,
          description: line.replaceAll(dateMatch.group(0)!, '').trim(),
          debit: debit,
          credit: credit,
          balance: balance,
        ));
      } catch (_) {}
    }

    return BankStatementResult(
      transactions: transactions,
      status: transactions.isNotEmpty ? 'AMBER' : 'FAILED',
      message: 'Regex parsed ${transactions.length} transactions. Please verify.',
      method: 'regex',
    );
  }

  static String _extractTextFromPdf(List<int> bytes) {
    // Simple PDF text extraction - looks for text between parentheses in PDF stream
    final str = String.fromCharCodes(bytes);
    final buffer = StringBuffer();
    final textPattern = RegExp(r'\(([^)]*)\)');
    for (final match in textPattern.allMatches(str)) {
      final text = match.group(1)!;
      if (text.length > 3 && RegExp(r'[a-zA-Z0-9]').hasMatch(text)) {
        buffer.writeln(text);
      }
    }
    return buffer.toString();
  }
}
