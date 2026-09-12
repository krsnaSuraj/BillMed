import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../database/database.dart';
import '../models/bill_status.dart';
import '../utils/money.dart';

class PdfExportService {
  static final Future<(ByteData?, ByteData?)> _fonts = _loadFonts();

  static Future<(ByteData?, ByteData?)> _loadFonts() async {
    ByteData? regular;
    ByteData? bold;
    try {
      regular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    } catch (_) {}
    try {
      bold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
    } catch (_) {}
    return (regular, bold);
  }

  /// Single money-formatting rule lives in [formatPaise]; only the symbol
  /// differs here (Helvetica has no rupee glyph, so fall back to Rs.).
  static String _money(int paise, {required bool unicodeRupee}) {
    final formatted = formatPaise(paise);
    if (unicodeRupee) return formatted;
    return formatted.replaceFirst('\u{20B9}', 'Rs. ');
  }

  static String _sanitize(String name) =>
      name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Generates a supplier statement PDF in the system temp directory.
  /// Returns null on any failure; never throws.
  static Future<File?> generateSupplierStatement({
    required Distributor distributor,
    required List<BillPaid> items,
  }) async {
    try {
      final (regular, bold) = await _fonts;

      final pw.Font baseFont;
      final pw.Font boldFont;
      final bool unicodeRupee;
      if (regular != null && bold != null) {
        baseFont = pw.Font.ttf(regular);
        boldFont = pw.Font.ttf(bold);
        unicodeRupee = true;
      } else {
        baseFont = pw.Font.helvetica();
        boldFont = pw.Font.helveticaBold();
        unicodeRupee = false;
      }

      final theme = pw.ThemeData.withFont(base: baseFont, bold: boldFont);

      final bills = [...items]
        ..sort((a, b) => a.bill.billDate.compareTo(b.bill.billDate));

      final nowLabel = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      String period;
      if (bills.isEmpty) {
        period = DateFormat('dd/MM/yyyy').format(DateTime.now());
      } else {
        final first = bills.first.bill.billDate;
        final last = bills.last.bill.billDate;
        final sameDay = first.year == last.year &&
            first.month == last.month &&
            first.day == last.day;
        period = sameDay
            ? DateFormat('dd/MM/yyyy').format(first)
            : '${DateFormat('dd/MM/yyyy').format(first)} - ${DateFormat('dd/MM/yyyy').format(last)}';
      }

      var totalAmount = 0;
      var totalPaid = 0;
      var totalBalance = 0;
      for (final item in bills) {
        totalAmount += item.bill.amountPaise;
        totalPaid += item.paidPaise;
        totalBalance += item.remainingPaise;
      }

      pw.Widget cell(String text, {bool isBold = false, bool right = false}) =>
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: pw.Text(
              text,
              textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          );

      final rows = <pw.TableRow>[
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
          children: [
            for (final h in const [
              'Date',
              'Bill No',
              'Amount',
              'Paid',
              'Balance',
              'Status'
            ])
              cell(h, isBold: true),
          ],
        ),
      ];

      for (var i = 0; i < bills.length; i++) {
        final item = bills[i];
        rows.add(pw.TableRow(
          decoration:
              i.isOdd ? const pw.BoxDecoration(color: PdfColors.grey100) : null,
          children: [
            cell(DateFormat('dd/MM/yyyy').format(item.bill.billDate)),
            cell(item.bill.billNumber),
            cell(_money(item.bill.amountPaise, unicodeRupee: unicodeRupee),
                right: true),
            cell(_money(item.paidPaise, unicodeRupee: unicodeRupee),
                right: true),
            cell(_money(item.remainingPaise, unicodeRupee: unicodeRupee),
                right: true),
            cell(
                computeBillStatus(item.bill.amountPaise, item.paidPaise).label),
          ],
        ));
      }

      rows.add(pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.indigo50),
        children: [
          cell('TOTAL', isBold: true),
          cell('', isBold: true),
          cell(_money(totalAmount, unicodeRupee: unicodeRupee),
              isBold: true, right: true),
          cell(_money(totalPaid, unicodeRupee: unicodeRupee),
              isBold: true, right: true),
          cell(_money(totalBalance, unicodeRupee: unicodeRupee),
              isBold: true, right: true),
          cell('', isBold: true),
        ],
      ));

      final table = pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: const {
          0: pw.FixedColumnWidth(62),
          1: pw.FlexColumnWidth(),
          2: pw.FixedColumnWidth(78),
          3: pw.FixedColumnWidth(78),
          4: pw.FixedColumnWidth(78),
          5: pw.FixedColumnWidth(56),
        },
        children: rows,
      );

      final pdf = pw.Document(theme: theme);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          footer: (_) => pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              'Generated by BillMed',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ),
          build: (_) => [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'STATEMENT OF ACCOUNT',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo800,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  distributor.name,
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                if ((distributor.company ?? '').isNotEmpty)
                  pw.Text(distributor.company!,
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey)),
                if ((distributor.phone ?? '').isNotEmpty)
                  pw.Text(distributor.phone!,
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey)),
                pw.SizedBox(height: 8),
                pw.Text('Generated on: $nowLabel',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
                pw.Text('Period: $period',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 4),
              ],
            ),
            table,
          ],
        ),
      );

      final now = DateTime.now();
      final ts =
          '${DateFormat('yyyyMMdd_HHmm').format(now)}${now.millisecond.toString().padLeft(3, '0')}';
      final file = File(p.join(Directory.systemTemp.path,
          'Statement_${_sanitize(distributor.name)}_$ts.pdf'));
      await file.writeAsBytes(await pdf.save());
      return file;
    } catch (e) {
      debugPrint('PdfExportService.generateSupplierStatement failed: $e');
      return null;
    }
  }

  /// Returns false only if the PDF could not be generated or shared setup
  /// failed outright; user cancelling the share sheet still returns true.
  static Future<bool> shareSupplierStatement({
    required Distributor distributor,
    required List<BillPaid> items,
  }) async {
    final file = await generateSupplierStatement(
      distributor: distributor,
      items: items,
    );
    if (file == null) return false;
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Statement of account - ${distributor.name}',
      );
    } catch (_) {
      // Share cancelled/unavailable; PDF was generated fine.
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
    return true;
  }
}
