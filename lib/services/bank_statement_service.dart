import 'dart:io';
import 'package:drift/drift.dart';
import '../database/database.dart';

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

class BankStatementResult {
  final List<ParsedTransaction> transactions;
  final String status; // VERIFIED, AMBER, FAILED
  final String message;
  final int totalPages;

  BankStatementResult({
    required this.transactions,
    this.status = 'VERIFIED',
    this.message = '',
    this.totalPages = 0,
  });
}

class BankStatementService {
  static Future<BankStatementResult> parseStatement({required String pdfPath}) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      return BankStatementResult(transactions: [], status: 'FAILED', message: 'File not found');
    }

    final text = await _extractPdfText(file);
    if (text.isEmpty) {
      return BankStatementResult(transactions: [], status: 'FAILED', message: 'Could not read PDF');
    }

    return _parseTransactions(text);
  }

  static Future<String> _extractPdfText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final str = String.fromCharCodes(bytes);
      final buffer = StringBuffer();

      // Method 1: Extract text between parentheses (most common in PDF)
      final parenPattern = RegExp(r'\(([^)]*)\)');
      for (final match in parenPattern.allMatches(str)) {
        final text = match.group(1)!;
        if (text.length > 2 && RegExp(r'[a-zA-Z0-9]').hasMatch(text)) {
          buffer.writeln(_cleanPdfText(text));
        }
      }

      // Method 2: Extract text between BT...ET markers (PDF text objects)
      if (buffer.isEmpty) {
        final btPattern = RegExp(r'BT([\s\S]*?)ET');
        for (final match in btPattern.allMatches(str)) {
          final block = match.group(1)!;
          final tjPattern = RegExp(r'\(([^)]*)\)\s*Tj');
          for (final tj in tjPattern.allMatches(block)) {
            final text = _cleanPdfText(tj.group(1)!);
            if (text.length > 2) buffer.writeln(text);
          }
        }
      }

      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  static String _cleanPdfText(String text) {
    return text
        .replaceAll(RegExp(r'\\[0-9]{3}'), '')
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\r')
        .trim();
  }

  static BankStatementResult _parseTransactions(String text) {
    final lines = text.split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final transactions = <ParsedTransaction>[];
    final datePattern = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');

    double openingBalance = 0;
    double closingBalance = 0;
    bool foundOpening = false, foundClosing = false;

    for (final line in lines) {
      final lower = line.toLowerCase();

      // Detect opening/closing balance
      if (lower.contains('opening') || lower.contains('b/f') || lower.contains('brought')) {
        final nums = _extractNumbers(line);
        if (nums.isNotEmpty) { openingBalance = nums.last; foundOpening = true; }
      }
      if (lower.contains('closing') || lower.contains('c/f') || lower.contains('carried')) {
        final nums = _extractNumbers(line);
        if (nums.isNotEmpty) { closingBalance = nums.last; foundClosing = true; }
      }

      // Skip header lines
      if (lower.contains('date') && lower.contains('particular') ||
          lower.contains('date') && lower.contains('narration') ||
          lower.contains('transaction') && lower.contains('amount') ||
          line.startsWith('---') || line.startsWith('===')) continue;

      // Find date
      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch == null) continue;

      try {
        final d = int.parse(dateMatch.group(1)!);
        final m = int.parse(dateMatch.group(2)!);
        var y = int.parse(dateMatch.group(3)!);
        if (y < 100) y += 2000;
        final date = DateTime(y, m, d);

        final amounts = _extractNumbers(line);
        if (amounts.isEmpty) continue;

        double debit = 0, credit = 0, balance = 0;
        final desc = line
            .replaceAll(dateMatch.group(0)!, '')
            .replaceAll(RegExp(r'[0-9,]+\.\d{2}'), '')
            .trim();

        if (amounts.length >= 3) {
          balance = amounts.last;
          // Determine debit/credit: if description contains specific words
          if (lower.contains('dr') || lower.contains('debit') || lower.contains('withdrawal') ||
              lower.contains('paid') || lower.contains('transfer') || lower.contains('neft') ||
              lower.contains('upi')) {
            debit = amounts[amounts.length - 2];
            credit = amounts[amounts.length - 3];
          } else if (lower.contains('cr') || lower.contains('credit') || lower.contains('deposit') ||
                     lower.contains('interest') || lower.contains('salary')) {
            credit = amounts[amounts.length - 2];
            debit = amounts[amounts.length - 3];
          } else {
            // Auto-detect: larger amount is the transaction, smaller is balance
            final sorted = [...amounts]..sort();
            if (amounts[0] > amounts[1]) {
              debit = amounts[1];
              credit = amounts[0];
            } else {
              debit = amounts[0];
              credit = amounts[1];
            }
          }
        } else if (amounts.length == 2) {
          balance = amounts.last;
          debit = amounts.first;
        } else if (amounts.length == 1) {
          balance = amounts.first;
        }

        transactions.add(ParsedTransaction(
          txnDate: date,
          description: _cleanDescription(desc),
          debit: debit,
          credit: credit,
          balance: balance,
        ));
      } catch (_) {}
    }

    // Golden Rule verification
    String status = 'VERIFIED';
    String message = '${transactions.length} transactions found';

    if (transactions.isNotEmpty) {
      final totalDebit = transactions.fold<double>(0, (s, t) => s + t.debit);
      final totalCredit = transactions.fold<double>(0, (s, t) => s + t.credit);
      final firstBal = transactions.first.balance;
      final lastBal = transactions.last.balance;

      if (foundOpening && foundClosing) {
        final expected = openingBalance + totalCredit - totalDebit;
        final diff = (expected - closingBalance).abs();
        if (diff > 10) {
          status = 'FAILED';
          message = 'Balance mismatch: expected ₹${expected.toStringAsFixed(0)}, got ₹${closingBalance.toStringAsFixed(0)}';
        }
      } else if (transactions.length > 2) {
        // Internal consistency check
        final runningMatch = _checkRunningBalance(transactions);
        if (!runningMatch) {
          status = 'AMBER';
          message = '${transactions.length} transactions (some balances may not match)';
        }
      }
    }

    return BankStatementResult(
      transactions: transactions,
      status: status,
      message: message,
      totalPages: text.split('\f').length,
    );
  }

  static bool _checkRunningBalance(List<ParsedTransaction> txns) {
    int mismatch = 0;
    for (int i = 1; i < txns.length; i++) {
      final expected = txns[i - 1].balance + txns[i].credit - txns[i].debit;
      if ((expected - txns[i].balance).abs() > 50) mismatch++;
    }
    return mismatch < txns.length * 0.2; // Allow 20% mismatch
  }

  static List<double> _extractNumbers(String text) {
    return RegExp(r'([0-9,]+\.\d{2})').allMatches(text).map((m) =>
        double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0).toList();
  }

  static String _cleanDescription(String desc) {
    return desc
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^(dr|cr)\s*', caseSensitive: false), '')
        .trim();
  }
}
