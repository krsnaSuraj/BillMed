import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  // Use 'Rs.' instead of '₹' because the default PDF font doesn't support
  // the Rupee symbol (U+20B9). Using latin fallback avoids garbled output.
  static String _money(double v) => 'Rs.${v.toStringAsFixed(2)}';
  static String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String _dateShort(DateTime d) => DateFormat('dd/MM/yy').format(d);
  static String _now() =>
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  // ─── Bill PDF ──────────────────────────────────────────────────────────────

  static Future<void> generateBillPdf(BillMedDatabase db, int billId) async {
    final bill = await db.getBill(billId);
    if (bill == null) return;

    final dists = await db.getAllDistributors();
    final dist = dists.cast<Distributor?>().firstWhere(
      (d) => d?.id == bill.distributorId,
      orElse: () => null,
    );
    final payments = await db.getPaymentsByBill(billId);
    final paid = await db.getTotalPaidForBill(billId);
    final remaining = (bill.amount - paid).clamp(0.0, bill.amount);

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BillMed',
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.indigo800,
                        )),
                    pw.Text('Bill Statement',
                        style: const pw.TextStyle(
                            fontSize: 13, color: PdfColors.grey)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: remaining > 0 ? PdfColors.red50 : PdfColors.green50,
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(6)),
                    border: pw.Border.all(
                        color: remaining > 0
                            ? PdfColors.red200
                            : PdfColors.green200),
                  ),
                  child: pw.Text(
                    remaining > 0 ? 'PENDING' : 'PAID',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color:
                          remaining > 0 ? PdfColors.red700 : PdfColors.green700,
                    ),
                  ),
                ),
              ],
            ),
            pw.Divider(height: 20, color: PdfColors.grey300),

            // Bill Info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _infoRow('Bill No.', bill.billNumber),
                    _infoRow('Date', _date(bill.billDate)),
                  ],
                ),
                if (dist != null)
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(dist.name,
                          style: pw.TextStyle(
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.indigo700)),
                      if (dist.company != null && dist.company!.isNotEmpty)
                        pw.Text(dist.company!,
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.grey)),
                      if (dist.phone != null && dist.phone!.isNotEmpty)
                        pw.Text(dist.phone!,
                            style: const pw.TextStyle(
                                fontSize: 11, color: PdfColors.grey)),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 20),

            // Amount Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.indigo100),
              ),
              child: pw.Column(
                children: [
                  _amtRow('Bill Amount', _money(bill.amount),
                      PdfColors.black),
                  _amtRow('Total Paid', _money(paid), PdfColors.green700),
                  pw.Divider(height: 12, color: PdfColors.indigo200),
                  _amtRow('Remaining', _money(remaining),
                      remaining > 0 ? PdfColors.red700 : PdfColors.green700),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Notes
            if (bill.notes != null && bill.notes!.isNotEmpty) ...[
              pw.Text('Notes:',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text(bill.notes!,
                  style:
                      const pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
              pw.SizedBox(height: 16),
            ],

            // Payments Table
            if (payments.isNotEmpty) ...[
              pw.Text('Payment History',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.indigo50),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellHeight: 22,
                headers: ['Date', 'Amount', 'Mode', 'Reference', 'Notes'],
                data: payments
                    .map((p) => [
                          _date(p.paymentDate),
                          _money(p.amount),
                          p.mode,
                          p.referenceNo ?? '-',
                          p.notes ?? '-',
                        ])
                    .toList(),
              ),
            ] else ...[
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                ),
                child: pw.Text('No payments recorded for this bill.',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.orange800)),
              ),
            ],

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by BillMed',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey)),
                pw.Text(_now(),
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey)),
              ],
            ),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/Bill_${bill.billNumber}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)],
        text: 'Bill #${bill.billNumber} - BillMed');
  }

  // ─── CA Report PDF ─────────────────────────────────────────────────────────

  static Future<void> generateCaReportPdf(BillMedDatabase db) async {
    var allTxns = await db.getAllBankTransactions();
    allTxns.sort((a, b) => a.txnDate.compareTo(b.txnDate));

    final allBills = await db.getAllBills();
    final billIds = allBills.map((b) => b.id).toList();
    final paidMap =
        billIds.isEmpty ? <int, double>{} : await db.getTotalPaidForBills(billIds);
    final totalBilled = allBills.fold<double>(0, (s, b) => s + b.amount);
    final totalBillsPaid =
        paidMap.values.fold<double>(0, (s, v) => s + v);

    final totalDebit =
        allTxns.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit =
        allTxns.fold<double>(0, (s, t) => s + t.credit);
    final net = totalCredit - totalDebit;

    // Monthly breakdown
    final months = <String, Map<String, double>>{};
    for (final t in allTxns) {
      final key =
          '${t.txnDate.year}-${t.txnDate.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => {'debit': 0.0, 'credit': 0.0});
      months[key]!['debit'] = (months[key]!['debit'] ?? 0) + t.debit;
      months[key]!['credit'] = (months[key]!['credit'] ?? 0) + t.credit;
    }
    final sortedMonths = months.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BillMed - CA Report',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo800)),
                    pw.Text('Bank & Business Summary',
                        style: const pw.TextStyle(
                            fontSize: 12, color: PdfColors.grey)),
                  ],
                ),
                pw.Text('Generated: ${_now()}',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey)),
              ],
            ),
            pw.Divider(height: 14, color: PdfColors.grey300),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('BillMed - Confidential',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ],
        ),
        build: (ctx) => [
          // Bills Summary
          pw.Header(level: 1, text: 'Bills Summary'),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: PdfColors.blue100),
            ),
            child: pw.Column(
              children: [
                _amtRow('Total Bills', '${allBills.length}', PdfColors.black),
                _amtRow('Total Billed', _money(totalBilled), PdfColors.indigo700),
                _amtRow('Total Collected', _money(totalBillsPaid), PdfColors.green700),
                pw.Divider(height: 10, color: PdfColors.blue200),
                _amtRow(
                    'Outstanding',
                    _money(totalBilled - totalBillsPaid),
                    (totalBilled - totalBillsPaid) > 0
                        ? PdfColors.red700
                        : PdfColors.green700),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Bank Summary
          pw.Header(level: 1, text: 'Bank Transactions Summary'),
          if (allTxns.isEmpty)
            pw.Text('No bank transactions imported.',
                style: const pw.TextStyle(color: PdfColors.grey))
          else ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.green100),
              ),
              child: pw.Column(
                children: [
                  _amtRow('Total Transactions',
                      '${allTxns.length}', PdfColors.black),
                  _amtRow(
                      'Total Debits', _money(totalDebit), PdfColors.red700),
                  _amtRow('Total Credits', _money(totalCredit),
                      PdfColors.green700),
                  pw.Divider(height: 10, color: PdfColors.green200),
                  _amtRow('Net (Credits - Debits)', _money(net),
                      net >= 0 ? PdfColors.green700 : PdfColors.red700),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Monthly Breakdown
            pw.Header(level: 1, text: 'Monthly Breakdown'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.indigo700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellHeight: 20,
              headers: ['Month', 'Debits', 'Credits', 'Net'],
              data: sortedMonths
                  .map((e) => [
                        e.key,
                        _money(e.value['debit'] ?? 0),
                        _money(e.value['credit'] ?? 0),
                        _money(
                            (e.value['credit'] ?? 0) -
                                (e.value['debit'] ?? 0)),
                      ])
                  .toList(),
            ),
            pw.SizedBox(height: 20),

            // Transaction Details
            pw.Header(level: 1, text: 'Transaction Details'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
                  color: PdfColors.white),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.indigo700),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellHeight: 18,
              columnWidths: {
                0: const pw.FixedColumnWidth(52),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(60),
                3: const pw.FixedColumnWidth(60),
                4: const pw.FixedColumnWidth(62),
              },
              headers: ['Date', 'Description', 'Debit', 'Credit', 'Balance'],
              data: allTxns
                  .map((t) => [
                        _dateShort(t.txnDate),
                        t.description.length > 45
                            ? '${t.description.substring(0, 45)}...'
                            : t.description,
                        t.debit > 0 ? _money(t.debit) : '',
                        t.credit > 0 ? _money(t.credit) : '',
                        _money(t.balance),
                      ])
                  .toList(),
            ),
          ],
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/BillMed_CA_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'BillMed CA Report');
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 70,
            child: pw.Text(label,
                style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey)),
          ),
          pw.Text(': $value',
              style: pw.TextStyle(
                  fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static pw.Widget _amtRow(String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}
