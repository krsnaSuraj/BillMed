import 'dart:convert';
import 'dart:io';

import 'gemini_service.dart';

// ─── Data Models ──────────────────────────────────────────────────────────────

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

// ─── Service ──────────────────────────────────────────────────────────────────

class BankStatementService {
  /// Primary entry point. Tries Gemini AI first, then built-in PDF parser.
  static Future<BankStatementResult> parseStatement({
    required String pdfPath,
    String? geminiKey,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      return BankStatementResult(
          status: 'FAILED', message: 'File not found', transactions: []);
    }

    // ── 1. Gemini AI path ─────────────────────────────────────────────────────
    if (geminiKey != null && geminiKey.isNotEmpty) {
      try {
        final bytes = await file.readAsBytes();
        final aiResult =
            await GeminiService.parsePdf(apiKey: geminiKey, pdfBytes: bytes);
        if (aiResult != null && !aiResult.startsWith('ERROR:')) {
          final parsed = _parseGeminiResponse(aiResult);
          if (parsed != null && parsed.transactions.isNotEmpty) return parsed;
        }
      } catch (_) {}
    }

    // ── 2. Built-in PDF text extraction + regex parser ────────────────────────
    final text = await _extractPdfText(file);
    if (text.isNotEmpty) {
      final result = _parseTransactions(text);
      if (result.transactions.isNotEmpty) return result;
    }

    return BankStatementResult(
      status: 'FAILED',
      message: 'Could not extract transactions from this PDF.\n\n'
          'Tips:\n'
          '• Use a Gemini API key (Settings) for best results\n'
          '• Make sure the PDF is not a scanned image\n'
          '• Try downloading the statement again from your bank',
      transactions: [],
    );
  }

  // ─── Type-safe numeric conversion ─────────────────────────────────────────

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '').trim();
    return double.tryParse(s) ?? 0.0;
  }

  // ─── Gemini JSON Response Parser ──────────────────────────────────────────

  static BankStatementResult? _parseGeminiResponse(String jsonText) {
    try {
      // Strip markdown code fences
      var cleaned = jsonText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '')
            .replaceAll(RegExp(r'```$', multiLine: true), '')
            .trim();
      }

      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');
      if (start == -1 || end == -1 || end <= start) return null;

      final jsonStr = cleaned.substring(start, end + 1);
      final list = jsonDecode(jsonStr) as List;
      if (list.isEmpty) return null;

      final txns = <ParsedTransaction>[];
      for (final t in list) {
        if (t is! Map) continue;
        final debit = _toDouble(t['debit']);
        final credit = _toDouble(t['credit']);
        final balance = _toDouble(t['balance']);
        // Skip rows where everything is zero (header/footer rows Gemini included)
        if (debit == 0 && credit == 0 && balance == 0) continue;
        final desc = (t['description']?.toString() ?? '').trim();
        txns.add(ParsedTransaction(
          txnDate: _parseDate(t['date']?.toString() ?? ''),
          description: desc.isEmpty ? 'Transaction' : desc,
          debit: debit,
          credit: credit,
          balance: balance,
        ));
      }

      if (txns.isEmpty) return null;

      // Verify running balance from AI data
      int balanceErrors = 0;
      for (int i = 1; i < txns.length; i++) {
        final expected = txns[i - 1].balance + txns[i].credit - txns[i].debit;
        if ((expected - txns[i].balance).abs() > 2.0) balanceErrors++;
      }

      final totalDebit = txns.fold<double>(0, (s, t) => s + t.debit);
      final totalCredit = txns.fold<double>(0, (s, t) => s + t.credit);
      final verified = balanceErrors == 0;

      return BankStatementResult(
        transactions: txns,
        status: verified ? 'VERIFIED' : 'PARTIAL',
        message: verified
            ? '${txns.length} transactions parsed via AI — balance verified ✓'
            : '${txns.length} transactions via AI ($balanceErrors balance mismatches)',
        totalDebit: totalDebit,
        totalCredit: totalCredit,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Date Parser ──────────────────────────────────────────────────────────

  static DateTime _parseDate(String str) {
    try {
      final s = str.trim();
      if (s.isEmpty) return DateTime.now();

      // ISO: YYYY-MM-DD
      if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(s)) {
        final d = DateTime.tryParse(s);
        if (d != null) return d;
      }

      // DD/MM/YYYY  DD-MM-YYYY  DD Mon YYYY
      final parts = s.split(RegExp(r'[\s/\-]'));
      if (parts.length >= 3) {
        var day = int.tryParse(parts[0]);
        var month = int.tryParse(parts[1]) ?? _monthFromName(parts[1]);
        var year = int.tryParse(parts[2]);
        if (day != null && month != null && year != null) {
          if (year < 100) year += 2000;
          if (day >= 1 && day <= 31 && month >= 1 && month <= 12) {
            return DateTime(year, month, day);
          }
        }
      }
    } catch (_) {}
    return DateTime.now();
  }

  static int? _monthFromName(String s) {
    if (s.length < 3) return null;
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    return months[s.toLowerCase().substring(0, 3)];
  }

  // ─── PDF Text Extraction ──────────────────────────────────────────────────

  static Future<String> _extractPdfText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileStr = String.fromCharCodes(bytes);

      // Method 1: decompress FlateDecode streams (works for most modern PDFs)
      final fromStreams = _extractFromStreams(bytes, fileStr);
      if (fromStreams.trim().isNotEmpty &&
          RegExp(r'\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}').hasMatch(fromStreams)) {
        return fromStreams;
      }

      // Method 2: raw PDF content operators (uncompressed / plain PDFs)
      final fromOps = _extractPdfOperators(fileStr);
      if (fromOps.trim().isNotEmpty) return fromOps;

      // Method 3: last-resort parenthesized string extraction
      return _extractParenthesizedText(fileStr);
    } catch (_) {
      return '';
    }
  }

  static String _extractFromStreams(List<int> bytes, String fileStr) {
    final result = StringBuffer();
    int searchFrom = 0;

    while (true) {
      final streamStart =
          _findBytes(bytes, [115, 116, 114, 101, 97, 109], searchFrom);
      if (streamStart == -1) break;

      // Check dict for FlateDecode
      final safeEnd =
          fileStr.length > streamStart ? streamStart : fileStr.length;
      final dictStr = fileStr.substring(0, safeEnd);
      final dictPos = dictStr.lastIndexOf('<<');
      final dict =
          dictPos != -1 ? dictStr.substring(dictPos, safeEnd) : '';
      final isFlate = dict.contains('FlateDecode');

      int dataStart = streamStart + 6;
      while (dataStart < bytes.length &&
          (bytes[dataStart] == 10 || bytes[dataStart] == 13)) {
        dataStart++;
      }

      final endstreamPos = _findBytes(
          bytes, [101, 110, 100, 115, 116, 114, 101, 97, 109], dataStart);
      if (endstreamPos == -1) break;

      int dataEnd = endstreamPos;
      while (dataEnd > dataStart &&
          (bytes[dataEnd - 1] == 10 ||
              bytes[dataEnd - 1] == 13 ||
              bytes[dataEnd - 1] == 32)) {
        dataEnd--;
      }

      final rawData = bytes.sublist(dataStart, dataEnd);
      searchFrom = endstreamPos + 9;

      String extracted;
      if (isFlate) {
        try {
          extracted =
              String.fromCharCodes(ZLibDecoder().convert(rawData));
        } catch (_) {
          continue;
        }
      } else {
        extracted = String.fromCharCodes(rawData);
      }

      final text = _extractPdfOperators(extracted);
      if (text.isNotEmpty) result.writeln(text);
    }

    return result.toString().trim();
  }

  static int _findBytes(List<int> bytes, List<int> pattern, int start) {
    for (int i = start; i <= bytes.length - pattern.length; i++) {
      bool match = true;
      for (int j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  static String _extractPdfOperators(String content) {
    final buffer = StringBuffer();
    final btEt = RegExp(r'BT(.*?)ET', dotAll: true);

    for (final block in btEt.allMatches(content)) {
      final blockText = block.group(1)!;

      // TJ array: [(text) num (text)] TJ
      for (final m in RegExp(r'\[(.*?)\]\s*TJ').allMatches(blockText)) {
        for (final part in RegExp(r'\(([^)]*)\)').allMatches(m.group(1)!)) {
          final text = _cleanPdfString(part.group(1)!);
          if (text.trim().isNotEmpty && _hasMeaning(text)) {
            buffer.write('${text.trim()} ');
          }
        }
      }

      // (text) Tj
      for (final m in RegExp(r'\(([^)]*)\)\s*Tj').allMatches(blockText)) {
        final text = _cleanPdfString(m.group(1)!);
        if (text.trim().isNotEmpty && _hasMeaning(text)) {
          buffer.writeln(text.trim());
        }
      }

      // (text) '
      for (final m in RegExp(r"\(([^)]*)\)\s*'").allMatches(blockText)) {
        final text = _cleanPdfString(m.group(1)!);
        if (text.trim().isNotEmpty && _hasMeaning(text)) {
          buffer.writeln(text.trim());
        }
      }

      buffer.writeln();
    }

    if (buffer.toString().trim().isEmpty) {
      for (final m in RegExp(r'\(([^)]*)\)').allMatches(content)) {
        final text = _cleanPdfString(m.group(1)!);
        if (text.length > 3 && _hasMeaning(text)) {
          buffer.writeln(text.trim());
        }
      }
    }

    return buffer.toString().trim();
  }

  static bool _hasMeaning(String s) =>
      RegExp(r'[a-zA-Z0-9]').hasMatch(s);

  static String _cleanPdfString(String s) => s
      .replaceAll('\\n', '\n')
      .replaceAll('\\r', '\r')
      .replaceAll('\\t', '\t')
      .replaceAll('\\(', '(')
      .replaceAll('\\)', ')')
      .replaceAll('\\\\', '\\')
      .replaceAll(RegExp(r'\\[0-9]{3}'), '');

  static String _extractParenthesizedText(String str) {
    final buffer = StringBuffer();
    for (final m in RegExp(r'\(([^)]*)\)').allMatches(str)) {
      final text = _cleanPdfString(m.group(1)!);
      if (text.length > 2 && _hasMeaning(text)) {
        buffer.writeln(text.trim());
      }
    }
    return buffer.toString();
  }

  // ─── Main Transaction Parser ──────────────────────────────────────────────

  static BankStatementResult _parseTransactions(String text) {
    final rawLines =
        text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final lines = _mergeLines(rawLines);

    final transactions = <ParsedTransaction>[];
    // Match DD/MM/YYYY, DD-MM-YYYY, DD/MM/YY etc at START of line
    final dateRe = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    final amtRe = RegExp(r'(\d{1,3}(?:,\d{2,3})*\.\d{2})');

    double openingBal = 0, closingBal = 0;
    bool foundOpening = false, foundClosing = false;

    for (final line in lines) {
      final lower = line.toLowerCase();

      // Opening balance
      if ((lower.contains('opening balance') ||
              lower.contains('op bal') ||
              lower.contains('opening bal') ||
              lower.contains('b/f') ||
              lower.contains('brought forward')) &&
          !foundOpening) {
        final nums = _extractAmounts(line);
        if (nums.isNotEmpty) {
          openingBal = nums.last;
          foundOpening = true;
        }
        continue;
      }

      // Closing balance
      if ((lower.contains('closing balance') ||
              lower.contains('cl bal') ||
              lower.contains('closing bal') ||
              lower.contains('c/f') ||
              lower.contains('carried forward')) &&
          !foundClosing) {
        final nums = _extractAmounts(line);
        if (nums.isNotEmpty) {
          closingBal = nums.last;
          foundClosing = true;
        }
        continue;
      }

      // Transaction line: must start with a date
      final dateMatch = dateRe.firstMatch(line);
      if (dateMatch == null) continue;

      try {
        var day = int.parse(dateMatch.group(1)!);
        var mon = int.parse(dateMatch.group(2)!);
        var yr = int.parse(dateMatch.group(3)!);
        if (yr < 100) yr += 2000;
        if (mon < 1 || mon > 12 || day < 1 || day > 31) continue;
        final date = DateTime(yr, mon, day);

        final rest = line.substring(dateMatch.end);
        final amounts = _extractAmounts(rest);
        if (amounts.isEmpty) continue;

        // Description = rest with all amounts stripped
        final desc = rest
            .replaceAll(amtRe, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        double debit = 0, credit = 0, balance = 0;

        // ── Keyword-based Dr/Cr detection ────────────────────────────────────
        final hasDr = _isDebitLine(lower);
        final hasCr = !hasDr && _isCreditLine(lower);

        if (amounts.length >= 3) {
          // Format: ...debit_col | credit_col | balance
          balance = amounts.last;
          final a1 = amounts[amounts.length - 3];
          final a2 = amounts[amounts.length - 2];

          if (hasDr) {
            debit = a1 > 0 ? a1 : a2;
            credit = 0;
          } else if (hasCr) {
            credit = a2 > 0 ? a2 : a1;
            debit = 0;
          } else {
            // Use balance-delta heuristic
            if (transactions.isNotEmpty) {
              final delta = balance - transactions.last.balance;
              final amt = a1 > 0 ? a1 : a2;
              if (delta < 0) {
                debit = amt;
              } else {
                credit = amt;
              }
            } else {
              debit = a1 > 0 ? a1 : a2;
            }
          }
        } else if (amounts.length == 2) {
          balance = amounts[1];
          final amt = amounts[0];
          if (hasCr) {
            credit = amt;
          } else if (hasDr) {
            debit = amt;
          } else if (transactions.isNotEmpty) {
            final delta = balance - transactions.last.balance;
            if (delta < 0) {
              debit = amt;
            } else {
              credit = amt;
            }
          } else {
            debit = amt;
          }
        } else {
          balance = amounts[0];
        }

        transactions.add(ParsedTransaction(
          txnDate: date,
          description: desc.isEmpty ? 'Transaction' : desc,
          debit: debit,
          credit: credit,
          balance: balance,
        ));
      } catch (_) {
        continue;
      }
    }

    if (transactions.isEmpty) {
      return BankStatementResult(
          status: 'FAILED',
          message: 'No transactions found. PDF may be scanned image — use Gemini AI.',
          transactions: []);
    }

    // ── Balance verification ───────────────────────────────────────────────
    int runningErrors = 0;
    for (int i = 1; i < transactions.length; i++) {
      final expected = transactions[i - 1].balance +
          transactions[i].credit -
          transactions[i].debit;
      if ((expected - transactions[i].balance).abs() > 2.0) runningErrors++;
    }

    final totalDebit = transactions.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit = transactions.fold<double>(0, (s, t) => s + t.credit);

    String status;
    String message;

    if (foundOpening && foundClosing) {
      final expectedClose = openingBal + totalCredit - totalDebit;
      final diff = (expectedClose - closingBal).abs();

      if (diff < 2.0 && runningErrors == 0) {
        status = 'VERIFIED';
        message = '${transactions.length} transactions — balance verified ✓';
      } else if (diff < 2.0 && runningErrors > 0) {
        status = 'PARTIAL';
        message = '${transactions.length} txns — opening/closing OK, $runningErrors row errors';
      } else {
        status = 'FAILED';
        // Show helpful diagnostic
        message = 'Balance mismatch detected.\n'
            'Opening: Rs.${openingBal.toStringAsFixed(2)}\n'
            'Expected closing: Rs.${expectedClose.toStringAsFixed(2)}\n'
            'PDF closing: Rs.${closingBal.toStringAsFixed(2)}\n'
            'Diff: Rs.${diff.toStringAsFixed(2)}\n'
            'You can still save and correct manually.';
      }
    } else if (runningErrors == 0 && transactions.length > 1) {
      status = 'VERIFIED';
      message = '${transactions.length} transactions — running balance OK ✓';
    } else if (runningErrors < (transactions.length * 0.3).ceil()) {
      status = 'PARTIAL';
      message =
          '$runningErrors of ${transactions.length} balance mismatches. Review before saving.';
    } else {
      status = 'FAILED';
      message = '${transactions.length} transactions found but balance could not be verified.\n'
          'You can still save the data.';
    }

    return BankStatementResult(
      transactions: transactions,
      status: status,
      message: message,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
    );
  }

  // ─── Keyword Detection ────────────────────────────────────────────────────

  static bool _isDebitLine(String lower) {
    return lower.contains(' dr ') ||
        lower.contains('/dr/') ||
        lower.contains('(dr)') ||
        lower.contains(' dr\n') ||
        lower.endsWith(' dr') ||
        lower.contains('debit') ||
        lower.contains('withdrawal') ||
        lower.contains('atm-wd') ||
        lower.contains('atm/') ||
        lower.contains('neft dr') ||
        lower.contains('imps dr') ||
        lower.contains('ecs dr') ||
        lower.contains('chq paid') ||
        lower.contains('si debit') ||
        lower.contains('ach debit') ||
        lower.contains('pos ') ||
        lower.contains('mb_') ||
        lower.contains('ib_') ||
        lower.contains('upi/dr') ||
        lower.contains('outward') ||
        lower.contains('payment to');
  }

  static bool _isCreditLine(String lower) {
    return lower.contains(' cr ') ||
        lower.contains('/cr/') ||
        lower.contains('(cr)') ||
        lower.contains(' cr\n') ||
        lower.endsWith(' cr') ||
        lower.contains('credit') ||
        lower.contains('deposit') ||
        lower.contains('interest') ||
        lower.contains('refund') ||
        lower.contains('neft cr') ||
        lower.contains('imps cr') ||
        lower.contains('ecs cr') ||
        lower.contains('upi/cr') ||
        lower.contains('by clg') ||
        lower.contains('by tfr') ||
        lower.contains('inward') ||
        lower.contains('received from');
  }

  // ─── Amount Extraction ────────────────────────────────────────────────────

  static List<double> _extractAmounts(String text) {
    // Remove dates so date-digits don't get parsed as amounts
    final noDate =
        text.replaceAll(RegExp(r'\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}'), '');
    return RegExp(r'(\d{1,3}(?:,\d{2,3})*\.\d{2})')
        .allMatches(noDate)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
        .where((v) => v > 0)
        .toList();
  }

  // ─── Line Merging ─────────────────────────────────────────────────────────

  static List<String> _mergeLines(List<String> lines) {
    final dateAtStart = RegExp(r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}');
    final hasAmount = RegExp(r'\d{1,3}(?:,\d{2,3})*\.\d{2}');
    final merged = <String>[];
    final buffer = StringBuffer();
    bool inTxn = false;
    String? ocBuf; // opening/closing balance buffer

    bool isJunk(String l) {
      final lw = l.toLowerCase();
      return lw.startsWith('page ') ||
          lw.startsWith('date ') ||
          lw.startsWith('txn date') ||
          lw.startsWith('value date') ||
          lw.startsWith('narration') ||
          lw.startsWith('particulars') ||
          lw.startsWith('cheque') ||
          lw.startsWith('ref no') ||
          lw.startsWith('ref number') ||
          lw.startsWith('chq') && l.length < 8 ||
          lw.startsWith('----') ||
          lw.startsWith('====') ||
          lw.startsWith('disclaimer') ||
          lw.startsWith('end of statement') ||
          lw.startsWith('end of report') ||
          lw.startsWith('unless the') ||
          lw.startsWith('generated on') ||
          lw.startsWith('statement period') ||
          lw.startsWith('branch') ||
          lw.startsWith('ifsc') ||
          lw.startsWith('micr') ||
          l.length < 3;
    }

    for (final line in lines) {
      if (isJunk(line)) continue;
      final lower = line.toLowerCase();

      // Accumulate opening/closing balance lines (may span 2 lines)
      if (ocBuf != null ||
          lower.contains('opening') ||
          lower.contains('closing') ||
          lower.contains('op bal') ||
          lower.contains('cl bal') ||
          lower.contains('b/f') ||
          lower.contains('c/f') ||
          lower.contains('brought forward') ||
          lower.contains('carried forward')) {
        ocBuf = ocBuf == null ? line : '$ocBuf $line'.trim();
        if (hasAmount.hasMatch(ocBuf)) {
          merged.add(ocBuf);
          ocBuf = null;
        }
        continue;
      }

      if (dateAtStart.hasMatch(line)) {
        // Save previous transaction
        if (inTxn && buffer.isNotEmpty) {
          merged.add(buffer.toString().trim());
          buffer.clear();
        }
        buffer.write(line);
        inTxn = true;
      } else if (inTxn) {
        // Continuation of current transaction (description on next line)
        buffer.write(' $line');
      }
    }

    if (inTxn && buffer.isNotEmpty) {
      merged.add(buffer.toString().trim());
    }

    return merged;
  }
}
