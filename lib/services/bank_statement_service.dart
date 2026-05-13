import 'dart:io';

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
  final String status;
  final String message;
  final double totalDebit;
  final double totalCredit;

  BankStatementResult({
    required this.transactions,
    this.status = 'FAILED',
    this.message = '',
    this.totalDebit = 0,
    this.totalCredit = 0,
  });
}

class BankStatementService {
  static Future<BankStatementResult> parseStatement({required String pdfPath}) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      return BankStatementResult(status: 'FAILED', message: 'File not found', transactions: []);
    }

    final text = await _extractPdfText(file);
    if (text.isEmpty) {
      return BankStatementResult(status: 'FAILED', message: 'Could not read PDF text', transactions: []);
    }

    return _parseTransactions(text);
  }

  static Future<String> _extractPdfText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final str = String.fromCharCodes(bytes);
      final buffer = StringBuffer();
      final parenPattern = RegExp(r'\(([^)]*)\)');
      for (final match in parenPattern.allMatches(str)) {
        final text = match.group(1)!;
        if (text.length > 2 && RegExp(r'[a-zA-Z0-9₹]').hasMatch(text)) {
          buffer.writeln(text.replaceAll(RegExp(r'\\[0-9]{3}'), '').trim());
        }
      }
      if (buffer.isEmpty) {
        final btPattern = RegExp(r'BT([\s\S]*?)ET');
        for (final match in btPattern.allMatches(str)) {
          final tjPattern = RegExp(r'\(([^)]*)\)\s*Tj');
          for (final tj in tjPattern.allMatches(match.group(1)!)) {
            final t = tj.group(1)!.trim();
            if (t.length > 2) buffer.writeln(t);
          }
        }
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  static BankStatementResult _parseTransactions(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final transactions = <ParsedTransaction>[];
    final datePattern = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    double openingBal = 0, closingBal = 0;
    bool foundOpening = false, foundClosing = false;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('opening') || lower.contains('b/f')) {
        _extractNumbers(line).lastOrNull.also((v) { openingBal = v; foundOpening = true; });
      }
      if (lower.contains('closing') || lower.contains('c/f')) {
        _extractNumbers(line).lastOrNull.also((v) { closingBal = v; foundClosing = true; });
      }
      if (lower.contains('date') && (lower.contains('particular') || lower.contains('narration')) ||
          line.startsWith('---') || line.startsWith('===')) continue;

      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch == null) continue;

      try {
        var y = int.parse(dateMatch.group(3)!);
        if (y < 100) y += 2000;
        final date = DateTime(y, int.parse(dateMatch.group(2)!), int.parse(dateMatch.group(1)!));
        final amounts = _extractNumbers(line);
        if (amounts.isEmpty) continue;

        final desc = line.replaceAll(dateMatch.group(0)!, '').replaceAll(RegExp(r'[0-9,]+\.\d{2}'), '')
            .replaceAll(RegExp(r'\s+'), ' ').trim();
        double debit = 0, credit = 0, balance = 0;

        if (amounts.length == 3) {
          balance = amounts[2];
          if (lower.contains('dr') || lower.contains('debit') || lower.contains('withdrawal') ||
              lower.contains('neft') || lower.contains('upi') || lower.contains('atm') ||
              lower.contains('paid') || lower.contains('transfer') || lower.contains('chq')) {
            debit = amounts[1]; credit = amounts[0];
          } else {
            credit = amounts[1]; debit = amounts[0];
          }
        } else if (amounts.length == 2) {
          balance = amounts[1]; debit = amounts[0];
        } else {
          balance = amounts[0];
        }

        transactions.add(ParsedTransaction(txnDate: date, description: desc, debit: debit, credit: credit, balance: balance));
      } catch (_) {}
    }

    if (transactions.isEmpty) {
      return BankStatementResult(status: 'FAILED', message: 'No transactions found in PDF', transactions: []);
    }

    // Running balance check — strict
    int balanceErrors = 0;
    for (int i = 1; i < transactions.length; i++) {
      final prev = transactions[i - 1];
      final curr = transactions[i];
      final expected = prev.balance + curr.credit - curr.debit;
      if ((expected - curr.balance).abs() > 10) {
        balanceErrors++;
      }
    }

    // Golden rule check
    final totalDebit = transactions.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit = transactions.fold<double>(0, (s, t) => s + t.credit);

    String status = 'FAILED';
    String message = '';

    if (foundOpening && foundClosing) {
      final expectedClose = openingBal + totalCredit - totalDebit;
      if ((expectedClose - closingBal).abs() < 10 && balanceErrors == 0) {
        status = 'VERIFIED';
        message = '${transactions.length} transactions — balance verified';
      } else {
        message = 'Balance mismatch. Expected closing: ₹${expectedClose.toStringAsFixed(0)}';
      }
    } else if (balanceErrors == 0 && transactions.length > 1) {
      status = 'VERIFIED';
      message = '${transactions.length} transactions — running balance OK';
    } else if (balanceErrors < transactions.length * 0.3) {
      status = 'FAILED';
      message = '$balanceErrors balance mismatches found. Manual entry suggested.';
    } else {
      message = 'Could not verify balances. Try manual entry.';
    }

    return BankStatementResult(
      transactions: transactions,
      status: status,
      message: message,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
    );
  }

  static List<double> _extractNumbers(String text) {
    return RegExp(r'([0-9,]+\.\d{2})').allMatches(text).map((m) =>
        double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0).toList();
  }
}

extension _OptionalExt<T> on T? {
  void also(void Function(T) fn) {
    final v = this;
    if (v != null) fn(v);
  }
}
