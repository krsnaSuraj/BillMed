import 'dart:convert';
import 'dart:io';
import 'gemini_service.dart';

class ParsedTransaction {
  final DateTime txnDate;
  final String description;
  final double debit;
  final double credit;
  final double balance;
  final bool isReversal;
  ParsedTransaction({required this.txnDate, required this.description, this.debit = 0, this.credit = 0, this.balance = 0, this.isReversal = false});
}

class BankStatementResult {
  final List<ParsedTransaction> transactions;
  final String status;
  final String message;
  final double totalDebit;
  final double totalCredit;
  final String bankName;
  BankStatementResult({required this.transactions, this.status = 'FAILED', this.message = '', this.totalDebit = 0, this.totalCredit = 0, this.bankName = ''});
}



class BankStatementService {
  // ── Public entry point ─────────────────────────────────────────────────────
  static Future<BankStatementResult> parseStatement({required String pdfPath, String? geminiKey}) async {
    final file = File(pdfPath);
    if (!await file.exists()) return BankStatementResult(status: 'FAILED', message: 'File not found', transactions: []);

    // 1. Try Gemini AI
    if (geminiKey != null && geminiKey.isNotEmpty) {
      try {
        final bytes = await file.readAsBytes();
        final aiResult = await GeminiService.parsePdf(apiKey: geminiKey, pdfBytes: bytes);
        if (aiResult != null && !aiResult.startsWith('ERROR:')) {
          final parsed = _parseGeminiResponse(aiResult);
          if (parsed != null && parsed.transactions.isNotEmpty) return parsed;
        }
      } catch (_) {}
    }

    // 2. Built-in parser
    final rawText = await _extractPdfText(file);
    if (rawText.isNotEmpty) {
      final bank = _detectBank(rawText);
      final result = _parseUniversal(rawText, bank);
      if (result.transactions.isNotEmpty) return result;
    }

    return BankStatementResult(
      status: 'FAILED',
      message: 'Could not parse PDF.\n\n• Add Gemini API key in Settings for best results\n• PDF must be text-based (not scanned image)',
      transactions: [],
    );
  }

  // ── Bank detection ─────────────────────────────────────────────────────────
  static String _detectBank(String text) {
    // Only scan the first part (headers), not transaction descriptions
    final header = text.substring(0, text.length > 2000 ? 2000 : text.length).toLowerCase();
    final t = text.toLowerCase();
    if (header.contains('canara bank') || t.contains('cnrb')) return 'CANARA';
    if (header.contains('state bank of india') || header.contains('sbi')) return 'SBI';
    if (header.contains('hdfc bank') || t.contains('hdfc bank ltd')) return 'HDFC';
    if (header.contains('icici bank') || t.contains('icici bank')) return 'ICICI';
    if (header.contains('punjab national bank') || header.contains('pnb')) return 'PNB';
    if (header.contains('axis bank') || t.contains('axis bank')) return 'AXIS';
    if (header.contains('kotak mahindra') || header.contains('kotak bank')) return 'KOTAK';
    if (header.contains('bank of baroda') || header.contains('bob')) return 'BOB';
    if (header.contains('union bank')) return 'UNION';
    if (header.contains('bank of india')) return 'BOI';
    if (header.contains('yes bank')) return 'YES';
    if (header.contains('indusind bank')) return 'INDUSIND';
    if (header.contains('federal bank')) return 'FEDERAL';
    if (header.contains('idfc')) return 'IDFC';
    return 'GENERIC';
  }

  // ── Universal parser (works for all banks) ─────────────────────────────────
  static BankStatementResult _parseUniversal(String text, String bank) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Detect if Canara stream format (has datetime like "18-03-2026 22:13:45")
    final hasCanaraFormat = lines.any((l) => RegExp(r'^\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2}:\d{2}$').hasMatch(l));
    if (hasCanaraFormat || bank == 'CANARA') {
      return _parseCanaraStream(lines, bank);
    }

    // Parse transaction rows
    final txns = <ParsedTransaction>[];
    double openingBal = 0, closingBal = 0;
    bool foundOpening = false, foundClosing = false;

    for (final line in lines) {
      final lower = line.toLowerCase();

      // Opening/closing balance
      if (!foundOpening && (lower.contains('opening balance') || lower.contains('op bal') || lower.contains('opening bal'))) {
        final amts = _amtsFromStr(line);
        if (amts.isNotEmpty) { openingBal = amts.last; foundOpening = true; }
        continue;
      }
      if (!foundClosing && (lower.contains('closing balance') || lower.contains('cl bal') || lower.contains('closing bal'))) {
        final amts = _amtsFromStr(line);
        if (amts.isNotEmpty) { closingBal = amts.last; foundClosing = true; }
        continue;
      }

      // Split line into tokens by 2+ spaces (tab-like separation in PDFs)
      final cols = line.split(RegExp(r'\s{2,}')).where((c) => c.trim().isNotEmpty).toList();
      if (cols.isEmpty) continue;

      // Try to find a date in the row
      DateTime? date;
      int dateColIdx = -1;
      for (int i = 0; i < cols.length; i++) {
        final d = _parseDate(cols[i]);
        if (d != null) { date = d; dateColIdx = i; break; }
      }
      if (date == null) continue;

      // Extract all amounts from the row (excluding the date col)
      final amounts = <double>[];
      for (int i = 0; i < cols.length; i++) {
        if (i == dateColIdx) continue;
        final v = _parseAmt(cols[i]);
        if (v != null && v > 0) amounts.add(v);
      }
      if (amounts.isEmpty) continue;

      // Description = non-date, non-amount columns
      final desc = cols.where((c) {
        if (_parseDate(c) != null) return false;
        if (_parseAmt(c) != null) return false;
        if (c.trim().length < 2) return false;
        return true;
      }).join(' ').trim();

      // Determine debit/credit
      double debit = 0, credit = 0, balance = 0;
      final rowLower = line.toLowerCase();

      // Check for explicit Dr/Cr marker in the row
      final hasDr = _hasDebitMarker(rowLower);
      final hasCr = _hasCreditMarker(rowLower);

      // HDFC: Withdrawal(Dr) | Deposit(Cr) | Balance — always 3 amounts
      // SBI/PNB/Axis: Debit | Credit | Balance — 3 amounts, one is 0
      // ICICI: Amount | Dr/Cr marker | Balance — or Debit | Credit | Balance
      if (amounts.length >= 3) {
        // 3-col format: debit_col | credit_col | balance
        balance = amounts.last;
        final a1 = amounts[amounts.length - 3];
        final a2 = amounts[amounts.length - 2];
        if (hasDr) { debit = a1 > 0 ? a1 : a2; }
        else if (hasCr) { credit = a2 > 0 ? a2 : a1; }
        else {
          // Heuristic: bigger amount gap between a1 and a2
          // If a1 > 0 and a2 == 0 → debit=a1; if a2 > 0 and a1 == 0 → credit=a2
          // Use balance delta vs previous transaction
          if (txns.isNotEmpty) {
            final delta = balance - txns.last.balance;
            if (delta < 0) { debit = a1 > 0 ? a1 : a2; }
            else { credit = a2 > 0 ? a2 : a1; }
          } else {
            debit = a1; // assume first is debit if no context
          }
        }
      } else if (amounts.length == 2) {
        balance = amounts[1];
        final amt = amounts[0];
        if (hasCr) { credit = amt; }
        else if (hasDr) { debit = amt; }
        else if (txns.isNotEmpty) {
          final delta = balance - txns.last.balance;
          if (delta < 0) { debit = amt; } else { credit = amt; }
        } else { debit = amt; }
      } else {
        // Only 1 amount — treat as balance
        balance = amounts[0];
      }

      if (debit == 0 && credit == 0 && balance == 0) continue;

      final isRev = _isReversal(desc, rowLower, credit);

      txns.add(ParsedTransaction(
        txnDate: date,
        description: desc.isEmpty ? (hasCr ? 'Credit' : 'Debit') : desc,
        debit: debit, credit: credit, balance: balance,
        isReversal: isRev,
      ));
    }

    if (txns.isEmpty) return BankStatementResult(status: 'FAILED', message: 'No transactions found in PDF.', transactions: []);
    return _buildResult(txns, openingBal, closingBal, foundOpening, foundClosing, bank);
  }

  // ── Universal bank parser (handles single-line & multi-line formats) ────────
  static BankStatementResult _parseCanaraStream(List<String> lines, String bank) {
    final txns = <ParsedTransaction>[];
    double openingBal = 0, closingBal = 0;
    bool foundOpen = false, foundClose = false;
    final dtRe = RegExp(r'^(\d{2})[\/\-](\d{2})[\/\-](\d{4})');
    final amtRe = RegExp(r'^[\d,]+\.\d{2}$');
    final valueDateRe = RegExp(r'^\d{1,2}\s+[A-Za-z]{3}\s+\d{4}$');

    // Detect opening/closing from any line
    for (final line in lines) {
      final l = line.toLowerCase();
      if (!foundOpen && (l.contains('opening balance') || l.contains('op bal'))) {
        final v = _amtsFromStr(line);
        if (v.isNotEmpty) { openingBal = v.last; foundOpen = true; }
      }
      if (!foundClose && (l.contains('closing balance') || l.contains('cl bal'))) {
        final v = _amtsFromStr(line);
        if (v.isNotEmpty) { closingBal = v.last; foundClose = true; }
      }
    }

    int i = 0;
    while (i < lines.length) {
      final raw = lines[i].trim();
      final dtMatch = dtRe.firstMatch(raw);
      if (dtMatch == null) { i++; continue; }

      final date = DateTime(int.parse(dtMatch.group(3)!), int.parse(dtMatch.group(2)!), int.parse(dtMatch.group(1)!));
      final afterDate = raw.substring(dtMatch.end).trim();
      final amountsInLine = _amtsFromStr(afterDate);

      // ── SINGLE-LINE MODE (date + description + amounts all on one line) ───
      if (amountsInLine.length >= 2) {
        String descPart = afterDate.replaceAll(RegExp(r'[\d,]+\.\d{2}'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
        final lowerDesc = descPart.toLowerCase();
        final isDebitOneLine = lowerDesc.contains('neft dr') || lowerDesc.contains('neft debit') ||
            lowerDesc.contains('/dr/') || lowerDesc.contains('-dr') ||
            lowerDesc.contains('chq') || lowerDesc.contains('transfer') ||
            lowerDesc.contains('withdrawal') || lowerDesc.contains('debit') || lowerDesc.contains('ift') ||
            lowerDesc.contains('imps dr') || lowerDesc.contains('sc ') || lowerDesc.contains('paid') ||
            lowerDesc.contains('chrg') || lowerDesc.contains('sms');
        final isCreditOneLine = !isDebitOneLine && (lowerDesc.contains('/cr/') || lowerDesc.contains('-cr') ||
            lowerDesc.contains('upi') || lowerDesc.contains('credit') || lowerDesc.contains('deposit') ||
            lowerDesc.contains('interest') || lowerDesc.contains('refund') ||
            lowerDesc.contains('by ') || lowerDesc.contains('cash') ||
            lowerDesc.contains('return'));

        double db = 0, cr = 0, bal = 0;
        if (amountsInLine.length >= 3) {
          bal = amountsInLine.last;
          if (isCreditOneLine) { cr = amountsInLine[amountsInLine.length - 2]; db = amountsInLine[amountsInLine.length - 3]; }
          else { db = amountsInLine[amountsInLine.length - 2]; cr = amountsInLine[amountsInLine.length - 3]; }
        } else if (amountsInLine.length == 2) {
          bal = amountsInLine[1];
          if (isCreditOneLine) { cr = amountsInLine[0]; } else { db = amountsInLine[0]; }
        } else {
          bal = amountsInLine[0];
        }
        txns.add(ParsedTransaction(txnDate: date, description: descPart.isEmpty ? 'Transaction' : descPart, debit: db, credit: cr, balance: bal, isReversal: _isReversal(descPart, descPart, cr)));
        i++;
        continue;
      }

      // ── MULTI-LINE MODE (Canara format: date, desc, branch code, amounts on separate lines) ───
      i++;

      // Skip value date
      if (i < lines.length && valueDateRe.hasMatch(lines[i].trim())) i++;

      // Optional cheque number (long digit string)
      if (i < lines.length && RegExp(r'^\d{6,}$').hasMatch(lines[i].trim())) { i++; }

      // Description lines
      final descLines = <String>[];
      while (i < lines.length) {
        final p = lines[i].trim();
        if (RegExp(r'^\d{2,4}$').hasMatch(p) || amtRe.hasMatch(p) || dtRe.hasMatch(p)) break;
        descLines.add(p); i++;
      }

      // Branch code (skip)
      if (i < lines.length && RegExp(r'^\d{2,4}$').hasMatch(lines[i].trim())) { i++; }

      // Amounts
      final amounts = <double>[];
      while (i < lines.length && amounts.length < 2) {
        final p = lines[i].trim();
        if (amtRe.hasMatch(p)) { final v = double.tryParse(p.replaceAll(',', '')); if (v != null && v > 0) { amounts.add(v); } i++; }
        else { break; }
      }
      if (amounts.isEmpty) continue;

      final desc = descLines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      final lower = desc.toLowerCase();
      final isDebitDesc = lower.contains('chq paid') || lower.contains('chq return') ||
          lower.contains('funds transfer debit') || lower.contains('neft dr') ||
          lower.contains('neft debit') || lower.contains('casa debit') ||
          lower.contains('stamp') || lower.contains('atm txn') || lower.contains('atm / imps') ||
          lower.contains('non judicial') || lower.contains('debit') ||
          lower.contains('/dr/') || lower.contains('-dr') ||
          lower.contains('imps dr') || lower.contains('ib-') ||
          lower.contains('imps sc') || lower.contains('chq rtn') || lower.contains('inw chq') ||
          lower.contains('transaction charges');
      final hasInterest = lower.contains('interest');
      final isCredit = !isDebitDesc && (
          lower.contains('upi/cr') || lower.contains('/cr/') || lower.contains('-cr') ||
          (hasInterest && !lower.contains('debit')) || lower.contains('deposit') ||
          lower.contains('inward') || lower.contains('neft cr') ||
          lower.contains('cash deposit') || lower.contains('by ') ||
          lower.contains('refun') || lower.contains('return'));

      double db = 0, cr = 0, bal = 0;
      if (amounts.length == 2) {
        bal = amounts[1];
        if (isCredit) { cr = amounts[0]; } else { db = amounts[0]; }
      } else {
        bal = amounts[0];
        if (txns.isNotEmpty) {
          final delta = bal - txns.last.balance;
          if (delta > 0) { cr = delta; } else { db = -delta; }
        }
      }

      // Self-heal: if debit/credit amount matches previous balance exactly,
      // the parser picked up the wrong field — recalculate from actual delta
      if (txns.isNotEmpty) {
        final prevBal = txns.last.balance;
        if (db > 0 && (db - prevBal).abs() < 1) {
          db = prevBal - bal;
          if (db < 0) { cr = -db; db = 0; }
        }
        if (cr > 0 && (cr - prevBal).abs() < 1) {
          cr = bal - prevBal;
          if (cr < 0) { db = -cr; cr = 0; }
        }
      }

      txns.add(ParsedTransaction(txnDate: date, description: desc.isEmpty ? (isCredit ? 'Credit' : 'Debit') : desc, debit: db, credit: cr, balance: bal, isReversal: _isReversal(desc, lower, cr)));
    }

    if (txns.isEmpty) return BankStatementResult(status: 'FAILED', message: 'No transactions found.', transactions: []);
    return _buildResult(txns, openingBal, closingBal, foundOpen, foundClose, bank);
  }

  // ── Gemini response parser ─────────────────────────────────────────────────
  static BankStatementResult? _parseGeminiResponse(String jsonText) {
    try {
      var s = jsonText.trim();
      if (s.startsWith('```')) s = s.replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: true), '').replaceAll(RegExp(r'```$', multiLine: true), '').trim();
      final start = s.indexOf('['), end = s.lastIndexOf(']');
      if (start == -1 || end <= start) return null;
      final list = jsonDecode(s.substring(start, end + 1)) as List;
      final txns = <ParsedTransaction>[];
      for (final t in list) {
        if (t is! Map) continue;
        final debit = _td(t['debit']), credit = _td(t['credit']), balance = _td(t['balance']);
        if (debit == 0 && credit == 0 && balance == 0) continue;
        txns.add(ParsedTransaction(txnDate: _parseDate(t['date']?.toString() ?? '') ?? DateTime.now(), description: (t['description']?.toString() ?? 'Transaction').trim(), debit: debit, credit: credit, balance: balance));
      }
      if (txns.isEmpty) return null;
      final totalDebit = txns.fold<double>(0, (s, t) => s + t.debit);
      final totalCredit = txns.fold<double>(0, (s, t) => s + t.credit);
      int errs = 0;
      for (int i = 1; i < txns.length; i++) {
        if ((txns[i-1].balance + txns[i].credit - txns[i].debit - txns[i].balance).abs() > 2) errs++;
      }
      return BankStatementResult(transactions: txns, status: errs == 0 ? 'VERIFIED' : 'PARTIAL', message: '${txns.length} transactions via AI${errs == 0 ? " — balance verified ✓" : " ($errs balance mismatches)"}', totalDebit: totalDebit, totalCredit: totalCredit, bankName: 'AI');
    } catch (_) { return null; }
  }

  // ── Result builder ─────────────────────────────────────────────────────────
  static BankStatementResult _buildResult(List<ParsedTransaction> txns, double opBal, double clBal, bool foundOp, bool foundCl, String bank) {
    final totalDebit = txns.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit = txns.fold<double>(0, (s, t) => s + t.credit);
    int runErrs = 0;
    for (int i = 1; i < txns.length; i++) {
      if ((txns[i-1].balance + txns[i].credit - txns[i].debit - txns[i].balance).abs() > 2) runErrs++;
    }
    String status, message;
    if (foundOp && foundCl) {
      final expected = opBal + totalCredit - totalDebit;
      final diff = (expected - clBal).abs();
      if (diff < 2 && runErrs == 0) { status = 'VERIFIED'; message = '${txns.length} transactions ($bank) — balance verified ✓'; }
      else if (diff < 2) { status = 'PARTIAL'; message = '${txns.length} txns — opening/closing OK, $runErrs row errors'; }
      else { status = 'FAILED'; message = 'Balance mismatch: Expected Rs.${expected.toStringAsFixed(2)}, PDF has Rs.${clBal.toStringAsFixed(2)}\nDiff: Rs.${diff.toStringAsFixed(2)}\nYou can still save and correct manually.'; }
    } else if (runErrs == 0 && txns.length > 1) {
      status = 'VERIFIED'; message = '${txns.length} transactions ($bank) — running balance OK ✓';
    } else if (txns.isNotEmpty && runErrs < (txns.length * 0.4).ceil()) {
      status = 'PARTIAL'; message = '$runErrs of ${txns.length} balance mismatches. Review before saving.';
    } else {
      status = 'FAILED'; message = '${txns.length} transactions found but balance unverified. You can save anyway.';
    }
    return BankStatementResult(transactions: txns, status: status, message: message, totalDebit: totalDebit, totalCredit: totalCredit, bankName: bank);
  }



  // ── Reversal detection ────────────────────────────────────────────────────
  static bool _isReversal(String desc, String lower, double credit) {
    if (lower.contains('chq return') || lower.contains('chq rtn') ||
        lower.contains('chq ret') || lower.contains('cheque return') ||
        lower.contains('cheque rtn')) {
      // Cheque return is a DEBIT (cheque bounced), but tag it as reversal
      return true;
    }
    // Generic reversal keywords (RETURN, REVERSAL, REFUND, REV, RTN)
    // Must NOT match "value date" or similar header text
    if (lower.contains('return') || lower.contains('reversal') ||
        lower.contains('rev of') || lower.contains('ret of') ||
        lower.contains('rtn of') || lower.contains('refund') ||
        (lower.contains('rev ') && !lower.startsWith('value'))) {
      return true;
    }
    return false;
  }

  // ── Keyword helpers ────────────────────────────────────────────────────────
  static bool _hasDebitMarker(String l) =>
    l.contains(' dr') || l.contains('(dr)') || l.contains('/dr/') || l.contains('debit') ||
    l.contains('withdrawal') || l.contains('atm') || l.contains('oth-payment') ||
    l.contains('ib ift') || l.contains('ib neft dr') || l.contains('sc neft') ||
    l.contains('neft dr') || l.contains('imps dr') || l.contains('upi/dr') ||
    l.contains('chq paid') || l.contains('chq return') || l.contains('chq rtn') ||
    l.contains('chq ret') || l.contains('ach dr') || l.contains('ecs dr') ||
    l.contains('pos ') || l.contains('outward');

  static bool _hasCreditMarker(String l) =>
    l.contains(' cr') || l.contains('(cr)') || l.contains('/cr/') || l.contains('credit') ||
    l.contains('deposit') || l.contains('interest') || l.contains('refund') ||
    l.contains('upi/cr') || l.contains('neft cr') || l.contains('imps cr') ||
    l.contains('ach cr') || l.contains('ecs cr') || l.contains('inward') ||
    l.contains('received') || l.contains('by clg') || l.contains('by tfr');

  // ── PDF text extraction ────────────────────────────────────────────────────
  static Future<String> _extractPdfText(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final buf = StringBuffer();
      int i = 0;
      while (i < bytes.length - 6) {
        // Look for 'stream' keyword
        if (bytes[i]==115&&bytes[i+1]==116&&bytes[i+2]==114&&bytes[i+3]==101&&bytes[i+4]==97&&bytes[i+5]==109) {
          // Check if FlateDecode in preceding dict
          final pre = String.fromCharCodes(bytes.sublist(i > 300 ? i - 300 : 0, i), );
          final isFlate = pre.contains('FlateDecode');
          int ds = i + 6;
          while (ds < bytes.length && (bytes[ds] == 10 || bytes[ds] == 13)) { ds++; }
          // Find endstream
          int de = ds;
          while (de < bytes.length - 9) {
            if (bytes[de]==101&&bytes[de+1]==110&&bytes[de+2]==100&&bytes[de+3]==115&&bytes[de+4]==116&&bytes[de+5]==114&&bytes[de+6]==101&&bytes[de+7]==97&&bytes[de+8]==109) break;
            de++;
          }
          if (de > ds && de < bytes.length) {
            int end = de;
            while (end > ds && (bytes[end-1]==10||bytes[end-1]==13||bytes[end-1]==32)) { end--; }
            final raw = bytes.sublist(ds, end);
            String content;
            if (isFlate) {
              try { content = String.fromCharCodes(ZLibDecoder().convert(raw)); } catch (_) { i = de + 9; continue; }
            } else {
              content = String.fromCharCodes(raw);
            }
            // Extract parenthesized strings
            for (final m in RegExp(r'\(([^)]*)\)').allMatches(content)) {
              final t = m.group(1)!.replaceAll('\\n', '\n').replaceAll('\\(', '(').replaceAll('\\)', ')').trim();
              if (t.isNotEmpty && RegExp(r'[a-zA-Z0-9]').hasMatch(t)) {
                buf.writeln(t);
              }
            }
            i = de + 9;
          } else {
            i++;
          }
        } else {
          i++;
        }
      }
      // Fallback: raw parenthesized text if stream extraction yielded nothing
      final result = buf.toString().trim();
      if (result.isEmpty) {
        final raw = String.fromCharCodes(bytes);
        final fb = StringBuffer();
        for (final m in RegExp(r'\(([^)]{2,80})\)').allMatches(raw)) {
          final t = m.group(1)!.trim();
          if (RegExp(r'[a-zA-Z0-9]').hasMatch(t)) fb.writeln(t);
        }
        return fb.toString().trim();
      }
      return result;
    } catch (_) { return ''; }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  static double _td(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  static double? _parseAmt(String s) {
    final clean = s.replaceAll(',', '').trim();
    if (!RegExp(r'^\d+\.\d{2}$').hasMatch(clean)) return null;
    return double.tryParse(clean);
  }

  static List<double> _amtsFromStr(String s) =>
    RegExp(r'\d{1,3}(?:,\d{2,3})*\.\d{2}').allMatches(s)
      .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')) ?? 0.0)
      .where((v) => v > 0).toList();

  static DateTime? _parseDate(String s) {
    s = s.trim();
    if (s.isEmpty) return null;
    // DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final r1 = RegExp(r'^(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})');
    final m1 = r1.firstMatch(s);
    if (m1 != null) {
      int d = int.parse(m1.group(1)!), mo = int.parse(m1.group(2)!), y = int.parse(m1.group(3)!);
      if (y < 100) y += 2000;
      if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12 && y >= 2000) return DateTime(y, mo, d);
    }
    // YYYY-MM-DD (ISO)
    final r2 = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');
    final m2 = r2.firstMatch(s);
    if (m2 != null) {
      final y = int.parse(m2.group(1)!), mo = int.parse(m2.group(2)!), d = int.parse(m2.group(3)!);
      if (y >= 2000 && mo >= 1 && mo <= 12 && d >= 1 && d <= 31) return DateTime(y, mo, d);
    }
    // DD Mon YYYY (e.g., 18 Mar 2026)
    final r3 = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})');
    final m3 = r3.firstMatch(s);
    if (m3 != null) {
      final d = int.parse(m3.group(1)!), mo = _mon(m3.group(2)!), y = int.parse(m3.group(3)!);
      if (mo != null && d >= 1 && d <= 31) return DateTime(y, mo, d);
    }
    return null;
  }

  static int? _mon(String s) {
    const m = {'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
    return m[s.toLowerCase().substring(0, 3 < s.length ? 3 : s.length)];
  }
}
