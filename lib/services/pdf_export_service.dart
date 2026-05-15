import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';
import 'package:intl/intl.dart';

class PdfExportService {
  // Use 'Rs.' instead of 'â‚¹' because the default PDF font doesn't support
  // the Rupee symbol (U+20B9). Using latin fallback avoids garbled output.
  static String _money(double v) => 'Rs.${v.toStringAsFixed(2)}';
  static String _date(DateTime d) => DateFormat('dd/MM/yyyy').format(d);
  static String _dateShort(DateTime d) => DateFormat('dd/MM/yy').format(d);
  static String _now() =>
      DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

  // â”€â”€â”€ Bill PDF â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€â”€ CA Report PDF â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static Future<void> generateCaReportPdf(BillMedDatabase db, {int? fyYear}) async {
    // FY: Apr 1 of fyYear â†’ Mar 31 of fyYear+1
    final now = DateTime.now();
    final fy = fyYear ?? (now.month >= 4 ? now.year : now.year - 1);
    final fyStart = DateTime(fy, 4, 1);
    final fyEnd   = DateTime(fy + 1, 3, 31, 23, 59, 59);
    final fyLabel = 'FY $fy-${(fy + 1).toString().substring(2)}';

    bool inFY(DateTime d) => !d.isBefore(fyStart) && !d.isAfter(fyEnd);

    var allTxns = (await db.getAllBankTransactions()).where((t) => inFY(t.txnDate)).toList()
      ..sort((a, b) => a.txnDate.compareTo(b.txnDate));

    final allBills = (await db.getAllBills()).where((b) => inFY(b.billDate)).toList()
      ..sort((a, b) => a.billDate.compareTo(b.billDate));

    final allPays  = (await db.getAllPayments()).where((p) => inFY(p.paymentDate)).toList();
    final allDists = await db.getAllDistributors();
    final distMap  = {for (final d in allDists) d.id: d};
    final paidMap  = <int, double>{};
    for (final p in allPays) { paidMap[p.billId] = (paidMap[p.billId] ?? 0) + p.amount; }

    final totalPurchase  = allBills.fold<double>(0, (s, b) => s + b.amount);
    final totalPaid      = allPays.fold<double>(0, (s, p) => s + p.amount);
    final outstanding    = (totalPurchase - totalPaid).clamp(0, double.infinity);
    final totalDebit     = allTxns.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit    = allTxns.fold<double>(0, (s, t) => s + t.credit);
    final net            = totalCredit - totalDebit;
    final gstApprox      = totalPurchase / 1.05 * 0.05;
    final closingBal     = allTxns.isNotEmpty ? allTxns.last.balance : 0.0;

    // Monthly bank breakdown
    final months = <String, Map<String, double>>{};
    for (final t in allTxns) {
      final key = '${t.txnDate.year}-${t.txnDate.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => {'debit': 0.0, 'credit': 0.0});
      months[key]!['debit'] = (months[key]!['debit'] ?? 0) + t.debit;
      months[key]!['credit'] = (months[key]!['credit'] ?? 0) + t.credit;
    }
    final sortedMonths = months.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: pw.Font.helvetica(), bold: pw.Font.helveticaBold()),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('BillMed â€” CA Report',
                      style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
                  pw.Text('$fyLabel  |  ${DateFormat('dd MMM yyyy').format(fyStart)} â€“ ${DateFormat('dd MMM yyyy').format(DateTime(fy+1,3,31))}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.indigo600)),
                ]),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text('Generated: ${_now()}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                  pw.Text('Confidential â€” For CA Use Only', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ]),
              ],
            ),
            pw.Divider(height: 12, color: PdfColors.indigo200),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('BillMed | $fyLabel', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
          ],
        ),
        build: (ctx) => [
          // â”€â”€ 1. Purchase / Payables â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _sectionHeader('1. Purchase & Payables Summary'),
          _summaryBox(PdfColors.red50, PdfColors.red100, [
            _amtRow('Total Purchases (Gross)', _money(totalPurchase), PdfColors.black),
            _amtRow('Total Bills', '${allBills.length}', PdfColors.grey700),
            _amtRow('Avg. Bill Value', allBills.isEmpty ? 'N/A' : _money(totalPurchase / allBills.length), PdfColors.grey700),
            pw.Divider(height: 8, color: PdfColors.red200),
            _amtRow('Total Paid to Suppliers', _money(totalPaid), PdfColors.green700),
            _amtRow('Outstanding Payable', _money(outstanding.toDouble()), outstanding > 0 ? PdfColors.red700 : PdfColors.green700),
            _amtRow('Payment Rate', totalPurchase > 0 ? '${(totalPaid/totalPurchase*100).toStringAsFixed(1)}%' : 'N/A', PdfColors.indigo700),
          ]),
          pw.SizedBox(height: 14),

          // â”€â”€ 2. Bank / Cash Flow â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _sectionHeader('2. Bank Account â€” Cash Flow Summary'),
          if (allTxns.isEmpty)
            pw.Text('No bank transactions for $fyLabel.', style: const pw.TextStyle(color: PdfColors.grey))
          else ...[
            _summaryBox(PdfColors.green50, PdfColors.green100, [
              _amtRow('Total Credits (Money In)', _money(totalCredit), PdfColors.green700),
              _amtRow('Total Debits (Money Out)', _money(totalDebit), PdfColors.red700),
              pw.Divider(height: 8, color: PdfColors.green200),
              _amtRow('Net Cash Flow', _money(net), net >= 0 ? PdfColors.green700 : PdfColors.red700),
              _amtRow('Closing Balance', _money(closingBal), PdfColors.indigo700),
              _amtRow('Total Transactions', '${allTxns.length}', PdfColors.grey700),
            ]),
            pw.SizedBox(height: 14),
          ],

          // â”€â”€ 3. GST Estimate â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _sectionHeader('3. GST Input Tax Estimate (Approximate)'),
          _summaryBox(PdfColors.orange50, PdfColors.orange100, [
            _amtRow('Purchase Turnover', _money(totalPurchase), PdfColors.black),
            _amtRow('Estimated Input GST @5%', _money(gstApprox), PdfColors.green700),
            _amtRow('Net Purchase (Base Value)', _money(totalPurchase - gstApprox), PdfColors.indigo700),
            pw.SizedBox(height: 4),
            pw.Text('* GST slabs vary: 0%/5%/12%/18%. Verify with actual invoices.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange700)),
          ]),
          pw.SizedBox(height: 14),

          // â”€â”€ 4. Monthly Bank Breakdown â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (sortedMonths.isNotEmpty) ...[
            _sectionHeader('4. Monthly Bank Breakdown ($fyLabel)'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellHeight: 20,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['Month', 'Credits (In)', 'Debits (Out)', 'Net'],
              data: sortedMonths.map((e) {
                final dr = e.value['debit'] ?? 0;
                final cr = e.value['credit'] ?? 0;
                return [_fmtMonthKey(e.key), _money(cr), _money(dr), _money(cr - dr)];
              }).toList(),
            ),
            pw.SizedBox(height: 14),
          ],

          // â”€â”€ 5. Supplier-wise Purchase â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (allBills.isNotEmpty) ...[
            _sectionHeader('5. Supplier-wise Purchase ($fyLabel)'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 18,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              columnWidths: {
                0: const pw.FixedColumnWidth(52),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FlexColumnWidth(),
                3: const pw.FixedColumnWidth(62),
                4: const pw.FixedColumnWidth(62),
                5: const pw.FixedColumnWidth(52),
              },
              headers: ['Bill Date', 'Bill No.', 'Supplier', 'Amount', 'Paid', 'Status'],
              data: allBills.map((b) {
                final paid = paidMap[b.id] ?? 0;
                final due = b.amount - paid;
                return [
                  _date(b.billDate),
                  '#${b.billNumber}',
                  (distMap[b.distributorId]?.name ?? 'Unknown').length > 20
                      ? '${(distMap[b.distributorId]?.name ?? 'Unknown').substring(0, 20)}...'
                      : (distMap[b.distributorId]?.name ?? 'Unknown'),
                  _money(b.amount),
                  _money(paid),
                  due <= 0.01 ? 'PAID' : 'DUE',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 14),
          ],

          // â”€â”€ 6. Transaction Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (allTxns.isNotEmpty) ...[
            _sectionHeader('6. Bank Transaction Details ($fyLabel)'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
              cellStyle: const pw.TextStyle(fontSize: 7),
              cellHeight: 16,
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              columnWidths: {
                0: const pw.FixedColumnWidth(48),
                1: const pw.FlexColumnWidth(),
                2: const pw.FixedColumnWidth(58),
                3: const pw.FixedColumnWidth(58),
                4: const pw.FixedColumnWidth(60),
              },
              headers: ['Date', 'Description', 'Debit', 'Credit', 'Balance'],
              data: allTxns.map((t) => [
                _dateShort(t.txnDate),
                t.description.length > 50 ? '${t.description.substring(0, 50)}...' : t.description,
                t.debit > 0 ? _money(t.debit) : '',
                t.credit > 0 ? _money(t.credit) : '',
                _money(t.balance),
              ]).toList(),
            ),
          ],
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/BillMed_CA_Report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    Share.shareXFiles([XFile(file.path)], text: 'BillMed CA Report â€” $fyLabel');
  }

  static pw.Widget _sectionHeader(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
  );

  static pw.Widget _summaryBox(PdfColor bg, PdfColor border, List<pw.Widget> children) =>
    pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(color: bg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)), border: pw.Border.all(color: border)),
      child: pw.Column(children: children),
    );

  static String _fmtMonthKey(String k) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final p = k.split('-');
    return '${m[int.tryParse(p[1]) ?? 0]} ${p[0]}';
  }


  // â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
