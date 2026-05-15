import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_export_service.dart';
import '../../services/export_service.dart';
import 'ca_export_dialog.dart';

// Financial year runs Apr 1 → Mar 31 in India
// FY 2024-25 means Apr 2024 – Mar 2025  → stored as year=2024

class YearlyReportScreen extends ConsumerStatefulWidget {
  const YearlyReportScreen({super.key});
  @override
  ConsumerState<YearlyReportScreen> createState() => _YearlyReportScreenState();
}

class _YearlyReportScreenState extends ConsumerState<YearlyReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  // Default: current FY (April of current year if month>=April, else last year)
  late int _fyYear;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final now = DateTime.now();
    _fyYear = now.month >= 4 ? now.year : now.year - 1;
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  /// FY start = Apr 1 of _fyYear; FY end = Mar 31 of (_fyYear+1)
  DateTime get _fyStart => DateTime(_fyYear, 4, 1);
  DateTime get _fyEnd   => DateTime(_fyYear + 1, 3, 31, 23, 59, 59);
  String get _fyLabel   => 'FY ${_fyYear}-${(_fyYear + 1).toString().substring(2)}';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CA Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_fyLabel, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          // FY year picker — only shows years with data + current + past 5
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Select Financial Year',
            onSelected: (y) => setState(() => _fyYear = y),
            itemBuilder: (_) {
              final now = DateTime.now();
              final curFy = now.month >= 4 ? now.year : now.year - 1;
              // Show only past 5 FYs + current (no future)
              return List.generate(6, (i) => curFy - i).map((y) {
                final label = 'FY $y-${(y + 1).toString().substring(2)}';
                return PopupMenuItem(
                  value: y,
                  child: Row(children: [
                    Icon(_fyYear == y ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 16, color: _fyYear == y ? AppColors.accent : Colors.grey),
                    const SizedBox(width: 8),
                    Text(label, style: TextStyle(fontWeight: _fyYear == y ? FontWeight.bold : FontWeight.normal)),
                  ]),
                );
              }).toList();
            },
          ),
          _exporting
              ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.download),
                  tooltip: 'Export',
                  onSelected: (v) => _export(db, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pdf', child: ListTile(dense: true, leading: Icon(Icons.picture_as_pdf, color: AppColors.danger), title: Text('Export PDF Report'))),
                    PopupMenuItem(value: 'csv', child: ListTile(dense: true, leading: Icon(Icons.table_chart, color: AppColors.success), title: Text('Export CSV (All Data)'))),
                  ],
                ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: const [Tab(text: 'P&L Summary'), Tab(text: 'Bank Statement'), Tab(text: 'Purchases')],
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([
          db.getAllBills(),
          db.getAllBankTransactions(),
          db.getAllDistributors(),
          db.getAllPayments(),
        ]),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final allBills  = snapshot.data![0] as List<Bill>;
          final allTxns   = snapshot.data![1] as List<BankTransaction>;
          final allDists  = snapshot.data![2] as List<Distributor>;
          final allPay    = snapshot.data![3] as List<Payment>;

          // Filter to selected FY
          final bills = allBills.where((b) => _inFY(b.billDate)).toList()
            ..sort((a, b) => a.billDate.compareTo(b.billDate));
          final txns = allTxns.where((t) => _inFY(t.txnDate)).toList()
            ..sort((a, b) => a.txnDate.compareTo(b.txnDate));
          final pays = allPay.where((p) => _inFY(p.paymentDate)).toList();

          if (bills.isEmpty && txns.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_outlined, size: 64, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 12),
                Text('No data for $_fyLabel', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                Text('Select a different Financial Year using the calendar icon above.', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4)), textAlign: TextAlign.center),
              ],
            ));
          }

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _plTab(bills, txns, pays, allDists),
              _bankTab(txns, ctx),
              _purchasesTab(bills, pays, allDists, ctx),
            ],
          );
        },
      ),
    );
  }

  bool _inFY(DateTime d) => !d.isBefore(_fyStart) && !d.isAfter(_fyEnd);

  // ─── TAB 1: P&L / Summary ─────────────────────────────────────────────────
  Widget _plTab(List<Bill> bills, List<BankTransaction> txns, List<Payment> pays, List<Distributor> dists) {
    final totalPurchase   = bills.fold<double>(0, (s, b) => s + b.amount);
    final totalPaid       = pays.fold<double>(0, (s, p) => s + p.amount);
    final outstanding     = totalPurchase - totalPaid;
    final bankDebit       = txns.fold<double>(0, (s, t) => s + t.debit);
    final bankCredit      = txns.fold<double>(0, (s, t) => s + t.credit);
    final netCashFlow     = bankCredit - bankDebit;
    final closingBal      = txns.isNotEmpty ? txns.last.balance : 0.0;

    // GST estimate: medicines typically 5% / 12% / 18% GST
    // We show approximate GST on purchases (5% slab — most medicines)
    final gstApprox5      = totalPurchase / 1.05 * 0.05;

    // Monthly purchase trend
    final monthlyPurchase = <String, double>{};
    for (final b in bills) {
      final k = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2,'0')}';
      monthlyPurchase[k] = (monthlyPurchase[k] ?? 0) + b.amount;
    }
    final sortedMonths = monthlyPurchase.entries.toList()..sort((a,b)=>a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // FY Header badge
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]), borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fyLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Apr $_fyYear – Mar ${_fyYear+1}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Purchase Summary
        _section('Purchase / Payables', Icons.receipt_long, AppColors.danger, [
          _kv('Total Purchases (Gross)', _rs(totalPurchase), AppColors.textPrimary),
          _kv('Total Bills', '${bills.length}', AppColors.info),
          _kv('Avg. Bill Value', bills.isEmpty ? 'N/A' : _rs(totalPurchase / bills.length), AppColors.textSecondary),
          const Divider(height: 12),
          _kv('Total Paid to Suppliers', _rs(totalPaid), AppColors.success),
          _kv('Outstanding Payable', _rs(outstanding < 0 ? 0 : outstanding), AppColors.danger),
          _kv('Payment Rate', totalPurchase > 0 ? '${(totalPaid / totalPurchase * 100).toStringAsFixed(1)}%' : 'N/A', AppColors.info),
        ]),
        const SizedBox(height: 10),

        // Bank / Cash Flow
        _section('Bank Statement Summary', Icons.account_balance, AppColors.info, [
          _kv('Total Credits (Money In)', _rs(bankCredit), AppColors.success),
          _kv('Total Debits (Money Out)', _rs(bankDebit), AppColors.danger),
          _kv('Net Cash Flow', _rs(netCashFlow), netCashFlow >= 0 ? AppColors.success : AppColors.danger),
          _kv('Total Transactions', '${txns.length}', AppColors.info),
          if (txns.isNotEmpty) _kv('Closing Balance', _rs(closingBal), AppColors.accent),
        ]),
        const SizedBox(height: 10),

        // GST Estimate
        _section('GST Estimate (Approximate)', Icons.calculate, AppColors.accent, [
          _kv('Purchase Turnover', _rs(totalPurchase), AppColors.textPrimary),
          _kv('Approx. Input GST @5%', _rs(gstApprox5), AppColors.success),
          _kv('Net of GST (Base Value)', _rs(totalPurchase - gstApprox5), AppColors.info),
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Text('⚠️ GST slab varies: 0% / 5% / 12% / 18%. Verify with your actual invoices. This is only an estimate.', style: TextStyle(fontSize: 11, color: AppColors.warning)),
          ),
        ]),
        const SizedBox(height: 10),

        // Monthly Breakdown
        if (sortedMonths.isNotEmpty)
          _section('Monthly Purchase Trend', Icons.bar_chart, AppColors.success, [
            Row(children: const [
              Expanded(flex: 2, child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              SizedBox(width: 60),
            ]),
            const Divider(height: 10),
            ...sortedMonths.map((e) {
              final pct = totalPurchase > 0 ? (e.value / totalPurchase) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(flex: 2, child: Text(_fmtMonthKey(e.key), style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(_rs(e.value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  SizedBox(
                    width: 60,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                        color: AppColors.accent,
                        minHeight: 8,
                      ),
                    ),
                  ),
                ]),
              );
            }),
          ]),
      ],
    );
  }

  // ─── TAB 2: Bank Statement ─────────────────────────────────────────────────
  Widget _bankTab(List<BankTransaction> txns, BuildContext ctx) {
    if (txns.isEmpty) return _noData(ctx, 'No bank transactions for $_fyLabel');
    final totalDr = txns.fold<double>(0, (s, t) => s + t.debit);
    final totalCr = txns.fold<double>(0, (s, t) => s + t.credit);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: txns.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _miniStat('Txns', '${txns.length}', AppColors.info),
                _miniStat('Debit', _rs(totalDr), AppColors.danger),
                _miniStat('Credit', _rs(totalCr), AppColors.success),
                _miniStat('Net', _rs(totalCr - totalDr), (totalCr - totalDr) >= 0 ? AppColors.success : AppColors.danger),
              ]),
            ),
          );
        }
        final t = txns[i - 1];
        final isCr = t.credit > 0;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: (isCr ? AppColors.success : AppColors.danger).withValues(alpha: 0.12),
              child: Icon(isCr ? Icons.arrow_downward : Icons.arrow_upward, size: 14, color: isCr ? AppColors.success : AppColors.danger),
            ),
            title: Text(t.description, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${_fmtDate(t.txnDate)}  •  Bal: ${_rs(t.balance)}', style: const TextStyle(fontSize: 10)),
            trailing: Text(
              '${isCr ? '+' : '-'}${_rs(isCr ? t.credit : t.debit)}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isCr ? AppColors.success : AppColors.danger),
            ),
          ),
        );
      },
    );
  }

  // ─── TAB 3: Purchases / Bills ─────────────────────────────────────────────
  Widget _purchasesTab(List<Bill> bills, List<Payment> pays, List<Distributor> dists, BuildContext ctx) {
    if (bills.isEmpty) return _noData(ctx, 'No purchases for $_fyLabel');
    final distMap = {for (final d in dists) d.id: d};
    // Paid per bill
    final paidMap = <int, double>{};
    for (final p in pays) { paidMap[p.billId] = (paidMap[p.billId] ?? 0) + p.amount; }

    final total = bills.fold<double>(0, (s, b) => s + b.amount);
    final totalPaid = bills.fold<double>(0, (s, b) => s + (paidMap[b.id] ?? 0));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: bills.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _miniStat('Bills', '${bills.length}', AppColors.info),
                _miniStat('Total', _rs(total), AppColors.danger),
                _miniStat('Paid', _rs(totalPaid), AppColors.success),
                _miniStat('Due', _rs(total - totalPaid), total - totalPaid > 0 ? AppColors.warning : AppColors.success),
              ]),
            ),
          );
        }
        final b = bills[i - 1];
        final paid = paidMap[b.id] ?? 0;
        final due = b.amount - paid;
        final isPaid = due <= 0.01;
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: (isPaid ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
              child: Icon(isPaid ? Icons.check : Icons.hourglass_bottom, size: 14, color: isPaid ? AppColors.success : AppColors.warning),
            ),
            title: Text('#${b.billNumber}  •  ${distMap[b.distributorId]?.name ?? 'Unknown'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            subtitle: Text('${_fmtDate(b.billDate)}  •  ${isPaid ? 'PAID' : 'Due: ${_rs(due)}'}', style: TextStyle(fontSize: 10, color: isPaid ? AppColors.success : AppColors.warning)),
            trailing: Text(_rs(b.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        );
      },
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _noData(BuildContext ctx, String msg) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_outlined, size: 56, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2)),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4)), textAlign: TextAlign.center),
    ]));
  }

  Widget _section(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          ]),
          const Divider(height: 14),
          ...children,
        ]),
      ),
    );
  }

  Widget _kv(String k, String v, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(k, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)))),
        Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color), overflow: TextOverflow.ellipsis),
      Text(label, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
    ]));
  }

  String _rs(double v) => 'Rs.${v.toStringAsFixed(2)}';

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  String _fmtMonthKey(String k) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final p = k.split('-');
    return '${m[int.tryParse(p[1]) ?? 0]} ${p[0]}';
  }

  Future<void> _export(BillMedDatabase db, String type) async {
    if (type == 'pdf') {
      // Show options dialog first
      final cfg = await showDialog<CaReportConfig>(
        context: context,
        builder: (_) => CaExportDialog(fyYear: _fyYear),
      );
      if (cfg == null || !mounted) return; // user cancelled
      setState(() => _exporting = true);
      try {
        await PdfExportService.generateCaReportPdf(db, fyYear: _fyYear, config: cfg);
      } finally {
        if (mounted) setState(() => _exporting = false);
      }
    } else {
      setState(() => _exporting = true);
      try {
        await ExportService.exportToCsv(db, type: 'bank');
      } finally {
        if (mounted) setState(() => _exporting = false);
      }
    }
  }
}
