import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_export_service.dart';
import '../../services/export_service.dart';

class YearlyReportScreen extends ConsumerStatefulWidget {
  const YearlyReportScreen({super.key});
  @override
  ConsumerState<YearlyReportScreen> createState() => _YearlyReportScreenState();
}

class _YearlyReportScreenState extends ConsumerState<YearlyReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  int _selectedYear = DateTime.now().year;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('CA Report'),
        actions: [
          // Year selector
          PopupMenuButton<int>(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            tooltip: 'Select Year',
            onSelected: (y) => setState(() => _selectedYear = y),
            itemBuilder: (_) {
              final cur = DateTime.now().year;
              return List.generate(5, (i) => cur - i)
                  .map((y) => PopupMenuItem(
                        value: y,
                        child: Text('FY $y-${(y + 1) % 100}',
                            style: TextStyle(
                                fontWeight: y == _selectedYear ? FontWeight.bold : FontWeight.normal,
                                color: y == _selectedYear ? AppColors.accent : null)),
                      ))
                  .toList();
            },
          ),
          _exporting
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : PopupMenuButton<String>(
                  icon: const Icon(Icons.download, color: Colors.white),
                  tooltip: 'Export',
                  onSelected: (v) => _export(db, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'pdf', child: ListTile(leading: Icon(Icons.picture_as_pdf, color: AppColors.danger), title: Text('Export PDF'))),
                    PopupMenuItem(value: 'csv', child: ListTile(leading: Icon(Icons.table_chart, color: AppColors.success), title: Text('Export CSV'))),
                  ],
                ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Bank Txns'),
            Tab(text: 'Bills'),
          ],
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([db.getAllBills(), db.getAllBankTransactions(), db.getAllDistributors()]),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final allBills = snapshot.data![0] as List<Bill>;
          final allTxns = snapshot.data![1] as List<BankTransaction>;
          final allDists = snapshot.data![2] as List<Distributor>;

          // Filter by selected year
          final fyStart = DateTime(_selectedYear, 4, 1); // April 1 = FY start
          final fyEnd = DateTime(_selectedYear + 1, 3, 31, 23, 59, 59);
          final bills = allBills.where((b) => b.billDate.isAfter(fyStart) && b.billDate.isBefore(fyEnd)).toList();
          final txns = allTxns.where((t) => t.txnDate.isAfter(fyStart) && t.txnDate.isBefore(fyEnd)).toList()
            ..sort((a, b) => a.txnDate.compareTo(b.txnDate));

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _summaryTab(bills, txns, allDists),
              _bankTxnsTab(txns),
              _billsTab(bills, allDists),
            ],
          );
        },
      ),
    );
  }

  // ─── Tab 1: Summary ──────────────────────────────────────────────────────────
  Widget _summaryTab(List<Bill> bills, List<BankTransaction> txns, List<Distributor> dists) {
    final totalBilled = bills.fold<double>(0, (s, b) => s + b.amount);
    final txnDebit = txns.fold<double>(0, (s, t) => s + t.debit);
    final txnCredit = txns.fold<double>(0, (s, t) => s + t.credit);
    final net = txnCredit - txnDebit;

    // Monthly bank breakdown
    final months = <String, Map<String, double>>{};
    for (final t in txns) {
      final key = '${t.txnDate.year}-${t.txnDate.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => {'debit': 0.0, 'credit': 0.0, 'count': 0.0});
      months[key]!['debit'] = (months[key]!['debit'] ?? 0) + t.debit;
      months[key]!['credit'] = (months[key]!['credit'] ?? 0) + t.credit;
      months[key]!['count'] = (months[key]!['count'] ?? 0) + 1;
    }
    final sortedMonths = months.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // FY label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Text(
            'Financial Year $_selectedYear-${(_selectedYear + 1) % 100}  (Apr $_selectedYear – Mar ${_selectedYear + 1})',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),

        // Bills Card
        _sectionCard('Purchase / Bills', Icons.receipt_long, AppColors.info, [
          _kv('Total Bills', '${bills.length}', AppColors.info),
          _kv('Total Purchase Amount', _rs(totalBilled), AppColors.textPrimary),
          _kv('Avg per Bill', bills.isEmpty ? 'N/A' : _rs(totalBilled / bills.length), AppColors.textSecondary),
        ]),
        const SizedBox(height: 12),

        // Bank Card
        _sectionCard('Bank Turnover', Icons.account_balance, AppColors.success, [
          _kv('Total Transactions', '${txns.length}', AppColors.textPrimary),
          _kv('Total Debits (Outflow)', _rs(txnDebit), AppColors.danger),
          _kv('Total Credits (Inflow)', _rs(txnCredit), AppColors.success),
          const Divider(height: 16),
          _kv('Net (Inflow - Outflow)', _rs(net), net >= 0 ? AppColors.success : AppColors.danger),
          _kv('Closing Balance', txns.isEmpty ? 'N/A' : _rs(txns.last.balance), AppColors.info),
        ]),
        const SizedBox(height: 12),

        // Monthly breakdown
        if (sortedMonths.isNotEmpty) ...[
          _sectionCard('Monthly Breakdown', Icons.bar_chart, AppColors.accent, [
            Row(children: [
              const Expanded(flex: 2, child: Text('Month', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const Expanded(child: Text('Debit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.danger))),
              const Expanded(child: Text('Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success))),
              const Expanded(child: Text('Net', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ]),
            const Divider(),
            ...sortedMonths.map((e) {
              final dr = e.value['debit'] ?? 0;
              final cr = e.value['credit'] ?? 0;
              final n = cr - dr;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(flex: 2, child: Text(_fmtMonthKey(e.key), style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(_rs(dr), style: const TextStyle(fontSize: 11, color: AppColors.danger))),
                  Expanded(child: Text(_rs(cr), style: const TextStyle(fontSize: 11, color: AppColors.success))),
                  Expanded(child: Text(_rs(n), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: n >= 0 ? AppColors.success : AppColors.danger))),
                ]),
              );
            }),
          ]),
        ],
      ],
    );
  }

  // ─── Tab 2: Bank Transactions ─────────────────────────────────────────────────
  Widget _bankTxnsTab(List<BankTransaction> txns) {
    if (txns.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.account_balance_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text('No bank transactions for this year'),
        ]),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: txns.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          final dr = txns.fold<double>(0, (s, t) => s + t.debit);
          final cr = txns.fold<double>(0, (s, t) => s + t.credit);
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _miniStat('Transactions', '${txns.length}', AppColors.info),
                _miniStat('Total Debit', _rs(dr), AppColors.danger),
                _miniStat('Total Credit', _rs(cr), AppColors.success),
              ]),
            ),
          );
        }
        final t = txns[i - 1];
        final isCredit = t.credit > 0;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isCredit ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                    color: isCredit ? AppColors.success : AppColors.danger, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text('${t.txnDate.day}/${t.txnDate.month}/${t.txnDate.year}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              )),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  isCredit ? '+${_rs(t.credit)}' : '-${_rs(t.debit)}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isCredit ? AppColors.success : AppColors.danger),
                ),
                Text('Bal: ${_rs(t.balance)}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ]),
            ]),
          ),
        );
      },
    );
  }

  // ─── Tab 3: Bills ─────────────────────────────────────────────────────────────
  Widget _billsTab(List<Bill> bills, List<Distributor> dists) {
    if (bills.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text('No bills for this year'),
        ]),
      );
    }
    final distMap = {for (final d in dists) d.id: d};
    final total = bills.fold<double>(0, (s, b) => s + b.amount);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: bills.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _miniStat('Total Bills', '${bills.length}', AppColors.info),
                _miniStat('Total Amount', _rs(total), AppColors.danger),
                _miniStat('Avg/Bill', _rs(total / bills.length), AppColors.accent),
              ]),
            ),
          );
        }
        final b = bills[i - 1];
        final dist = distMap[b.distributorId];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('#${b.billNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(dist?.name ?? 'Unknown Supplier',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  Text('${b.billDate.day}/${b.billDate.month}/${b.billDate.year}',
                      style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                ],
              )),
              Text(_rs(b.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger)),
            ]),
          ),
        );
      },
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  String _rs(double v) => 'Rs.${v.toStringAsFixed(2)}';

  String _fmtMonthKey(String key) {
    const mns = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final parts = key.split('-');
    if (parts.length < 2) return key;
    final m = int.tryParse(parts[1]) ?? 0;
    return '${mns[m]} ${parts[0]}';
  }

  Widget _sectionCard(String title, IconData icon, Color color, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          ]),
          const Divider(height: 16),
          ...children,
        ]),
      ),
    );
  }

  Widget _kv(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
    ]));
  }

  Future<void> _export(BillMedDatabase db, String type) async {
    setState(() => _exporting = true);
    try {
      if (type == 'pdf') {
        await PdfExportService.generateCaReportPdf(db);
      } else {
        await ExportService.exportToCsv(db, type: 'bank');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
