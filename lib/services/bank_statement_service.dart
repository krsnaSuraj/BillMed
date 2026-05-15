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
  // ─── Entry Point ─────────────────────────────────────────────────────────────

  static Future<BankStatementResult> parseStatement({
    required String pdfPath,
    String? geminiKey,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      return BankStatementResult(
          status: 'FAILED', message: 'File not found', transactions: []);
    }

    // Try Gemini AI first — it reads PDF natively
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

    // Fallback: built-in text extraction + regex parser
    final text = await _extractPdfText(file);
    if (text.isNotEmpty) {
      final result = _parseTransactions(text);
      if (result.transactions.isNotEmpty) return result;
    }

    return BankStatementResult(
        status: 'FAILED',
        message: 'Could not parse statement. Try manual entry.',
        transactions: []);
  }

  // ─── Type-safe double conversion ─────────────────────────────────────────────

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '').trim();
    return double.tryParse(s) ?? 0.0;
  }

  // ─── Gemini Response Parser ───────────────────────────────────────────────────

  static BankStatementResult? _parseGeminiResponse(String jsonText) {
    try {
      // Strip markdown code fences if present
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
        if (debit == 0 && credit == 0 && balance == 0) continue; // skip junk rows
        txns.add(ParsedTransaction(
          txnDate: _parseDate(t['date']?.toString() ?? ''),
          description: (t['description']?.toString() ?? 'NA').trim().isEmpty
              ? 'NA'
              : t['description'].toString().trim(),
          debit: debit,
          credit: credit,
          balance: balance,
        ));
      }

      if (txns.isEmpty) return null;

      final totalDebit = txns.fold<double>(0, (s, t) => s + t.debit);
      final totalCredit = txns.fold<double>(0, (s, t) => s + t.credit);

      // ── Verify balance math from AI data ──────────────────────────────────────
      // Running-balance check: each row balance = prev balance + credit - debit
      int balanceErrors = 0;
      for (int i = 1; i < txns.length; i++) {
        final expected =
            txns[i - 1].balance + txns[i].credit - txns[i].debit;
        if ((expected - txns[i].balance).abs() > 1.0) balanceErrors++;
      }

      final verified = balanceErrors == 0;
      final pct = txns.isEmpty ? 0 : (balanceErrors / txns.length * 100).round();

      return BankStatementResult(
        transactions: txns,
        status: verified ? 'VERIFIED' : 'PARTIAL',
        message: verified
            ? '${txns.length} transactions parsed via AI — balance verified ✓'
            : '${txns.length} transactions parsed via AI ($pct% balance errors)',
        totalDebit: totalDebit,
        totalCredit: totalCredit,
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Date Parser ─────────────────────────────────────────────────────────────

  static DateTime _parseDate(String str) {
    try {
      final s = str.trim();
      if (s.isEmpty) return DateTime.now();

      // ISO: YYYY-MM-DD
      if (RegExp(r'^\d{4}-\d{1,2}-\d{1,2}$').hasMatch(s)) {
        final d = DateTime.tryParse(s);
        if (d != null) return d;
      }

      // DD/MM/YYYY  or  DD-MM-YYYY  or  DD Mon YYYY
      final parts = s.split(RegExp(r'[\s\/\-]'));
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
    const months = {
      'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
      'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
    };
    return months[s.toLowerCase().substring(0, 3)];
  }

  // ─── PDF Text Extraction ──────────────────────────────────────────────────────

  static Future<String> _extractPdfText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final fileStr = String.fromCharCodes(bytes);

      final fromStreams = _extractFromStreams(bytes, fileStr);
      if (fromStreams.isNotEmpty) return fromStreams;

      final fromOps = _extractPdfOperators(fileStr);
      if (fromOps.isNotEmpty) return fromOps;

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

      final dictEnd = streamStart;
      final dictStr = fileStr.substring(
          0, fileStr.length > dictEnd ? dictEnd : fileStr.length);
      final dictPos = dictStr.lastIndexOf('<<');
      final dict = dictPos != -1 ? dictStr.substring(dictPos, dictEnd) : '';
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
          final decoder = ZLibDecoder();
          extracted = String.fromCharCodes(decoder.convert(rawData));
        } catch (_) {
          continue;
        }
      } else {
        extracted = String.fromCharCodes(rawData);
      }

      result.writeln(_extractPdfOperators(extracted));
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

      for (final match in RegExp(r'\[(.*?)\]\s*TJ').allMatches(blockText)) {
        for (final part in RegExp(r'\(([^)]*)\)').allMatches(match.group(1)!)) {
          final text = _cleanPdfString(part.group(1)!);
          if (text.trim().isNotEmpty &&
              RegExp(r'[a-zA-Z0-9]').hasMatch(text)) {
            buffer.write('${text.trim()} ');
          }
        }
      }

      for (final match
          in RegExp(r'\(([^)]*)\)\s*Tj').allMatches(blockText)) {
        final text = _cleanPdfString(match.group(1)!);
        if (text.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(text)) {
          buffer.writeln(text.trim());
        }
      }

      for (final match
          in RegExp(r"\(([^)]*)\)\s*'").allMatches(blockText)) {
        final text = _cleanPdfString(match.group(1)!);
        if (text.trim().isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(text)) {
          buffer.writeln(text.trim());
        }
      }

      buffer.writeln();
    }

    if (buffer.toString().trim().isEmpty) {
      for (final match in RegExp(r'\(([^)]*)\)').allMatches(content)) {
        final text = _cleanPdfString(match.group(1)!);
        if (text.length > 3 && RegExp(r'[a-zA-Z0-9]').hasMatch(text)) {
          buffer.writeln(text.trim());
        }
      }
    }

    return buffer.toString().trim();
  }

  static String _cleanPdfString(String s) {
    return s
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\r')
        .replaceAll('\\t', '\t')
        .replaceAll('\\(', '(')
        .replaceAll('\\)', ')')
        .replaceAll('\\\\', '\\')
        .replaceAll(RegExp(r'\\[0-9]{3}'), '');
  }

  static String _extractParenthesizedText(String str) {
    final buffer = StringBuffer();
    for (final match in RegExp(r'\(([^)]*)\)').allMatches(str)) {
      final text = _cleanPdfString(match.group(1)!);
      if (text.length > 2 && RegExp(r'[a-zA-Z0-9]').hasMatch(text)) {
        buffer.writeln(text.trim());
      }
    }
    return buffer.toString();
  }

  // ─── Main Transaction Parser ──────────────────────────────────────────────────

  static BankStatementResult _parseTransactions(String text) {
    final rawLines =
        text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final lines = _mergeLines(rawLines);

    final transactions = <ParsedTransaction>[];
    // Match dates: DD/MM/YYYY  DD-MM-YYYY  DD/MM/YY  etc.
    final dateRe = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    // Amount pattern: numbers with optional commas and exactly 2 decimal places
    final amtRe = RegExp(r'(\d{1,3}(?:,\d{2,3})*\.\d{2})');

    double openingBal = 0, closingBal = 0;
    bool foundOpening = false, foundClosing = false;

    for (final line in lines) {
      final lower = line.toLowerCase();

      // ── Opening / Closing balance ───────────────────────────────────────────
      if (lower.contains('opening balance') ||
          lower.contains('op bal') ||
          lower.contains('opening bal')) {
        final nums = _extractAmounts(line);
        if (nums.isNotEmpty && !foundOpening) {
          openingBal = nums.last;
          foundOpening = true;
        }
        continue;
      }
      if (lower.contains('closing balance') ||
          lower.contains('cl bal') ||
          lower.contains('closing bal')) {
        final nums = _extractAmounts(line);
        if (nums.isNotEmpty && !foundClosing) {
          closingBal = nums.last;
          foundClosing = true;
        }
        continue;
      }

      // ── Transaction line ───────────────────────────────────────────────────
      final dateMatch = dateRe.firstMatch(line);
      if (dateMatch == null) continue;

      try {
        var day = int.parse(dateMatch.group(1)!);
        var mon = int.parse(dateMatch.group(2)!);
        var yr = int.parse(dateMatch.group(3)!);
        if (yr < 100) yr += 2000;
        if (mon < 1 || mon > 12 || day < 1 || day > 31) continue;
        final date = DateTime(yr, mon, day);

        // Remove the date part, then extract amounts from remainder
        final rest = line.substring(dateMatch.end);
        final amounts = _extractAmounts(rest);
        if (amounts.isEmpty) continue;

        // Build description: strip amounts from rest
        final desc = rest
            .replaceAll(amtRe, '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // ── Assign debit / credit / balance ─────────────────────────────────
        // Indian bank statements come in 3 main column layouts:
        //  A) date | narration | debit | credit | balance   → 3 amounts max
        //  B) date | narration | amount | Dr/Cr | balance   → 2 amounts
        //  C) date | narration | amount | balance           → 2 amounts
        double debit = 0, credit = 0, balance = 0;

        final hasDr = lower.contains(' dr ') ||
            lower.contains('/dr/') ||
            lower.contains(' dr\n') ||
            lower.endsWith(' dr') ||
            lower.contains('(dr)') ||
            lower.contains('debit') ||
            lower.contains('withdrawal') ||
            lower.contains('atm-wd') ||
            lower.contains('neft dr') ||
            lower.contains('imps dr') ||
            lower.contains('chq paid') ||
            lower.contains('ecs dr') ||
            lower.contains('si debit') ||
            lower.contains('pos ') ||
            lower.contains('mb_') ||
            lower.contains('ib_');

        final hasCr = !hasDr &&
            (lower.contains(' cr ') ||
                lower.contains('/cr/') ||
                lower.contains(' cr\n') ||
                lower.endsWith(' cr') ||
                lower.contains('(cr)') ||
                lower.contains('credit') ||
                lower.contains('deposit') ||
                lower.contains('interest') ||
                lower.contains('refund') ||
                lower.contains('neft cr') ||
                lower.contains('imps cr') ||
                lower.contains('ecs cr') ||
                lower.contains('upi/cr') ||
                lower.contains('by clg') ||
                lower.contains('by tfr'));

        if (amounts.length >= 3) {
          // Layout A: last = balance, second-last = credit/debit amount,
          // third-last may be the other column (often 0 or not printed).
          // Most banks print only ONE non-zero amount per row in debit/credit cols.
          balance = amounts.last;
          final a1 = amounts[amounts.length - 3]; // potential debit col
          final a2 = amounts[amounts.length - 2]; // potential credit col

          if (hasDr) {
            // Debit column has the amount, credit col is blank/0
            debit = a1 > 0 ? a1 : a2;
            credit = 0;
          } else if (hasCr) {
            credit = a2 > 0 ? a2 : a1;
            debit = 0;
          } else {
            // Use balance-delta heuristic: if we have a previous balance,
            // determine direction from delta
            if (transactions.isNotEmpty) {
              final prevBal = transactions.last.balance;
              final delta = balance - prevBal; // positive = credit, negative = debit
              final txnAmt = a2 > 0 ? a2 : a1;
              if (delta < 0) {
                debit = txnAmt;
              } else {
                credit = txnAmt;
              }
            } else {
              // No previous balance — use the larger of the two as the amount
              final txnAmt = a1 > a2 ? a1 : a2;
              debit = txnAmt; // conservative default
            }
          }
        } else if (amounts.length == 2) {
          // Layout B/C: first = transaction amount, second = running balance
          balance = amounts[1];
          final txnAmt = amounts[0];
          if (hasCr) {
            credit = txnAmt;
          } else if (hasDr) {
            debit = txnAmt;
          } else if (transactions.isNotEmpty) {
            // Balance delta tells us direction
            final delta = balance - transactions.last.balance;
            if (delta < 0) {
              debit = txnAmt;
            } else {
              credit = txnAmt;
            }
          } else {
            debit = txnAmt;
          }
        } else {
          // Only one amount — treat as balance
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
          message: 'No transactions found in PDF. Try manual entry.',
          transactions: []);
    }

    // ── Verify balances ──────────────────────────────────────────────────────
    int runningErrors = 0;
    for (int i = 1; i < transactions.length; i++) {
      final expected = transactions[i - 1].balance +
          transactions[i].credit -
          transactions[i].debit;
      if ((expected - transactions[i].balance).abs() > 1.0) runningErrors++;
    }

    final totalDebit =
        transactions.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit =
        transactions.fold<double>(0, (s, t) => s + t.credit);

    String status;
    String message;

    if (foundOpening && foundClosing) {
      final expectedClose = openingBal + totalCredit - totalDebit;
      final diff = (expectedClose - closingBal).abs();
      if (diff < 2.0 && runningErrors == 0) {
        status = 'VERIFIED';
        message =
            '${transactions.length} transactions — balance verified ✓';
      } else if (diff < 2.0) {
        status = 'PARTIAL';
        message =
            '${transactions.length} txns — opening/closing OK but $runningErrors running errors';
      } else {
        // Show diagnostic: expected vs actual — helps user understand
        status = 'FAILED';
        message =
            'Balance mismatch: Expected closing ₹${expectedClose.toStringAsFixed(2)}, '
            'PDF closing ₹${closingBal.toStringAsFixed(2)}. '
            'Diff ₹${diff.toStringAsFixed(2)}. $runningErrors running errors. '
            'You can still save and correct manually.';
      }
    } else if (runningErrors == 0 && transactions.length > 1) {
      status = 'VERIFIED';
      message =
          '${transactions.length} transactions — running balance OK ✓';
    } else if (runningErrors < transactions.length * 0.3) {
      status = 'PARTIAL';
      message =
          '$runningErrors of ${transactions.length} balance mismatches. '
          'Review before saving.';
    } else {
      status = 'FAILED';
      message =
          'Could not verify balances ($runningErrors errors). '
          'You can still save and correct manually.';
    }

    return BankStatementResult(
      transactions: transactions,
      status: status,
      message: message,
      totalDebit: totalDebit,
      totalCredit: totalCredit,
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  /// Extract monetary amounts (numbers with exactly 2 decimal places).
  /// Strips dates first so date-numbers are not picked up.
  static List<double> _extractAmounts(String text) {
    // Remove date patterns like 12/03/2025 or 12-03-25
    final noDate =
        text.replaceAll(RegExp(r'\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}'), '');
    return RegExp(r'(\d{1,3}(?:,\d{2,3})*\.\d{2})')
        .allMatches(noDate)
        .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '')) ?? 0.0)
        .where((v) => v > 0)
        .toList();
  }

  /// Merge multi-line transactions into single lines.
  static List<String> _mergeLines(List<String> lines) {
    final dateAtStart = RegExp(r'^\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}');
    final hasAmount = RegExp(r'\d{1,3}(?:,\d{2,3})*\.\d{2}');
    final merged = <String>[];
    final buffer = StringBuffer();
    bool inTxn = false;

    // Lines to skip entirely
    bool isJunk(String l) {
      final lw = l.toLowerCase();
      return lw.startsWith('page ') ||
          lw.startsWith('date ') ||
          lw.startsWith('txn date') ||
          lw.startsWith('narration') ||
          lw.startsWith('particulars') ||
          lw.startsWith('cheque') ||
          lw.startsWith('ref no') ||
          lw.startsWith('value date') ||
          lw.startsWith('----') ||
          lw.startsWith('====') ||
          lw.startsWith('disclaimer') ||
          lw.startsWith('end of statement') ||
          lw.startsWith('unless the') ||
          lw.startsWith('generated on') ||
          lw.startsWith('statement period') ||
          lw.startsWith('account') ||
          l.length < 3;
    }

    // Accumulate opening/closing balance lines (may span 2 lines)
    String? ocBuf;

    for (final line in lines) {
      if (isJunk(line)) continue;
      final lower = line.toLowerCase();

      // Opening / closing balance accumulation
      if (ocBuf != null ||
          lower.contains('opening') ||
          lower.contains('closing') ||
          lower.contains('op bal') ||
          lower.contains('cl bal')) {
        ocBuf = ocBuf == null ? line : '$ocBuf $line'.trim();
        if (hasAmount.hasMatch(ocBuf)) {
          merged.add(ocBuf);
          ocBuf = null;
        }
        continue;
      }

      if (dateAtStart.hasMatch(line)) {
        if (inTxn && buffer.isNotEmpty) {
          merged.add(buffer.toString().trim());
          buffer.clear();
        }
        buffer.write(line);
        inTxn = true;
      } else if (inTxn) {
        // Continuation line
        buffer.write(' $line');
      }
    }

    if (inTxn && buffer.isNotEmpty) {
      merged.add(buffer.toString().trim());
    }
    return merged;
  }
}
