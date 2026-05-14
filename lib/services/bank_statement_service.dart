import 'dart:convert';
import 'dart:io';

import 'gemini_service.dart';

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
  static Future<BankStatementResult> parseStatement({required String pdfPath, String? geminiKey}) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      return BankStatementResult(status: 'FAILED', message: 'File not found', transactions: []);
    }

    // Try Gemini AI with full PDF (bypasses text extraction)
    if (geminiKey != null && geminiKey.isNotEmpty) {
      try {
        final bytes = await file.readAsBytes();
        final aiResult = await GeminiService.parsePdf(apiKey: geminiKey, pdfBytes: bytes);
        if (aiResult != null) {
          // Check if it's an error message from Gemini
          if (aiResult.startsWith('ERROR:')) {
            return BankStatementResult(
              status: 'FAILED',
              message: aiResult.substring(6),
              transactions: [],
            );
          }
          final parsed = _parseGeminiResponse(aiResult);
          if (parsed != null && parsed.transactions.isNotEmpty) return parsed;
        }
      } catch (e) {
        return BankStatementResult(
          status: 'FAILED',
          message: 'AI error: ${e.toString().substring(0, e.toString().length.clamp(0, 100))}',
          transactions: [],
        );
      }
    }

    // Fallback: regex parser on extracted text
    final text = await _extractPdfText(file);
    if (text.isNotEmpty) {
      final result = _parseTransactions(text);
      if (result.transactions.isNotEmpty) return result;
    }

    return BankStatementResult(status: 'FAILED', message: 'Could not parse statement. Try manual entry.', transactions: []);
  }

  static BankStatementResult? _parseGeminiResponse(String jsonText) {
    try {
      // Extract JSON array - use greedy match to get full array
      final start = jsonText.indexOf('[');
      final end = jsonText.lastIndexOf(']');
      if (start == -1 || end == -1 || end <= start) return null;
      
      final jsonStr = jsonText.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List;
      if (list.isEmpty) return null;

      final txns = list.map((t) => ParsedTransaction(
        txnDate: _parseDate(t['date']?.toString() ?? ''),
        description: t['description']?.toString() ?? '',
        debit: (t['debit'] ?? 0).runtimeType == double ? t['debit'] as double : double.tryParse(t['debit']?.toString() ?? '0') ?? 0,
        credit: (t['credit'] ?? 0).runtimeType == double ? t['credit'] as double : double.tryParse(t['credit']?.toString() ?? '0') ?? 0,
        balance: (t['balance'] ?? 0).runtimeType == double ? t['balance'] as double : double.tryParse(t['balance']?.toString() ?? '0') ?? 0,
      )).toList();

      if (txns.isEmpty) return null;

      final totalDebit = txns.fold<double>(0, (s, t) => s + t.debit);
      final totalCredit = txns.fold<double>(0, (s, t) => s + t.credit);

      return BankStatementResult(
        transactions: txns,
        status: 'VERIFIED',
        message: '${txns.length} transactions parsed via AI',
        totalDebit: totalDebit,
        totalCredit: totalCredit,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime _parseDate(String str) {
    try {
      if (str.contains('-')) {
        final d = DateTime.tryParse(str);
        if (d != null) return d;
      }
      final parts = str.split(RegExp(r'[\/\-]'));
      if (parts.length >= 3) {
        var y = int.parse(parts[2]);
        if (y < 100) y += 2000;
        return DateTime(y, int.parse(parts[1]), int.parse(parts[0]));
      }
    } catch (_) {}
    return DateTime.now();
  }

  static Future<String> _extractPdfText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileStr = String.fromCharCodes(bytes);

      // Method 1: Decompress FlateDecode streams and extract text
      final textFromStreams = _extractFromStreams(bytes, fileStr);
      if (textFromStreams.isNotEmpty) return textFromStreams;

      // Method 2: Extract from raw content operators (uncompressed PDFs)
      final operatorsText = _extractPdfOperators(fileStr);
      if (operatorsText.isNotEmpty) return operatorsText;

      // Method 3: Fallback to parenthesized text extraction
      return _extractParenthesizedText(fileStr);
    } catch (_) {
      return '';
    }
  }

  static String _extractFromStreams(List<int> bytes, String fileStr) {
    final result = StringBuffer();
    int searchFrom = 0;

    while (true) {
      final streamStart = fileStr.indexOf('stream', searchFrom);
      if (streamStart == -1) break;

      // Check if preceding dict has FlateDecode
      final dictEnd = streamStart;
      final dictStart = fileStr.lastIndexOf('<<', dictEnd);
      final dict = dictStart != -1 ? fileStr.substring(dictStart, dictEnd) : '';
      final isFlate = dict.contains('FlateDecode');

      // Find end of stream data
      final dataStart = fileStr.indexOf('\n', streamStart);
      if (dataStart == -1 || dataStart > streamStart + 20) { searchFrom = streamStart + 6; continue; }

      final dataBegin = dataStart + 1;
      final endstreamIdx = fileStr.indexOf('endstream', dataBegin);
      if (endstreamIdx == -1) break;

      final rawData = bytes.sublist(dataBegin, endstreamIdx);
      searchFrom = endstreamIdx + 9;

      String extracted;
      if (isFlate) {
        try {
          final decoder = ZLibDecoder();
          extracted = String.fromCharCodes(decoder.convert(rawData));
        } catch (_) {
          try {
            int trim = rawData.length;
            while (trim > 0 && (rawData[trim - 1] == 10 || rawData[trim - 1] == 13)) { trim--; }
            final decoder = ZLibDecoder();
            extracted = String.fromCharCodes(decoder.convert(rawData.sublist(0, trim)));
          } catch (_) { continue; }
        }
      } else {
        extracted = String.fromCharCodes(rawData);
      }

      result.writeln(_extractPdfOperators(extracted));
    }

    return result.toString().trim();
  }

  static String _extractPdfOperators(String content) {
    final buffer = StringBuffer();

    // TJ arrays: [(text) num (text) ...] TJ
    for (final match in RegExp(r'\[(.*?)\]\s*TJ').allMatches(content)) {
      for (final part in RegExp(r'\(([^)]*)\)').allMatches(match.group(1)!)) {
        final text = part.group(1)!
            .replaceAll('\\n', '\n').replaceAll('\\r', '\r')
            .replaceAll('\\t', '\t').replaceAll('\\(', '(')
            .replaceAll('\\)', ')').replaceAll('\\\\', '\\');
        if (text.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9₹]').hasMatch(text)) {
          buffer.write('${text.trim()} ');
        }
      }
    }

    // Tj operators: (text) Tj
    for (final match in RegExp(r'\(([^)]*)\)\s*Tj').allMatches(content)) {
      final text = match.group(1)!
          .replaceAll('\\n', '\n').replaceAll('\\r', '\r')
          .replaceAll('\\t', '\t').replaceAll('\\(', '(')
          .replaceAll('\\)', ')').replaceAll('\\\\', '\\');
      if (text.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9₹]').hasMatch(text)) {
        buffer.writeln(text.trim());
      }
    }

    return buffer.toString().trim();
  }

  static String _extractParenthesizedText(String str) {
    final buffer = StringBuffer();
    for (final match in RegExp(r'\(([^)]*)\)').allMatches(str)) {
      final text = match.group(1)!;
      if (text.length > 2 && RegExp(r'[a-zA-Z0-9₹]').hasMatch(text)) {
        buffer.writeln(text.replaceAll(RegExp(r'\\[0-9]{3}'), '').trim());
      }
    }
    return buffer.toString();
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
        final v = _numbers(line).lastOrNull;
        if (v != null) { openingBal = v; foundOpening = true; }
      }
      if (lower.contains('closing') || lower.contains('c/f')) {
        final v = _numbers(line).lastOrNull;
        if (v != null) { closingBal = v; foundClosing = true; }
      }
      if ((lower.contains('date') && (lower.contains('particular') || lower.contains('narration'))) ||
          line.startsWith('---') || line.startsWith('===')) { continue; }

      final dateMatch = datePattern.firstMatch(line);
      if (dateMatch == null) continue;

      try {
        var y = int.parse(dateMatch.group(3)!);
        if (y < 100) y += 2000;
        final date = DateTime(y, int.parse(dateMatch.group(2)!), int.parse(dateMatch.group(1)!));
        final amounts = _numbers(line);
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

    int balanceErrors = 0;
    for (int i = 1; i < transactions.length; i++) {
      final expected = transactions[i - 1].balance + transactions[i].credit - transactions[i].debit;
      if ((expected - transactions[i].balance).abs() > 10) balanceErrors++;
    }

    final totalDebit = transactions.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit = transactions.fold<double>(0, (s, t) => s + t.credit);

    String status = 'FAILED';
    String message = '';

    if (foundOpening && foundClosing) {
      final expectedClose = openingBal + totalCredit - totalDebit;
      if ((expectedClose - closingBal).abs() < 10 && balanceErrors == 0) {
        status = 'VERIFIED';
        message = '${transactions.length} transactions - balance verified';
      } else {
        message = 'Balance mismatch. Expected closing: \u20B9${expectedClose.toStringAsFixed(0)}';
      }
    } else if (balanceErrors == 0 && transactions.length > 1) {
      status = 'VERIFIED';
      message = '${transactions.length} transactions - running balance OK';
    } else if (balanceErrors < transactions.length * 0.3) {
      status = 'FAILED';
      message = '$balanceErrors balance mismatches found. Try manual entry.';
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

  static List<double> _numbers(String text) {
    return RegExp(r'([0-9,]+\.\d{2})').allMatches(text).map((m) =>
        double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0).toList();
  }
}
