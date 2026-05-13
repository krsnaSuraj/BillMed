import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../database/daos.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';

final reportProvider = FutureProvider<DashboardSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  return BillMedDao(db).getDashboardSummary();
});

final turnoverProvider = FutureProvider<Map<String, double>>((ref) async {
  final db = ref.watch(databaseProvider);
  final allBills = await db.getAllBills();
  final result = <String, double>{};
  for (final bill in allBills) {
    final key = '${bill.billDate.year}-${bill.billDate.month.toString().padLeft(2, '0')}';
    result[key] = (result[key] ?? 0) + bill.amount;
  }
  return result;
});

final overdueCountProvider = FutureProvider<int>((ref) async {
  final db = ref.watch(databaseProvider);
  final allBills = await db.getAllBills();
  final paidMap = await db.getTotalPaidForBills(allBills.map((b) => b.id).toList());
  return allBills.where((b) {
    final paid = paidMap[b.id] ?? 0.0;
    return paid <= 0 && DateTime.now().difference(b.billDate).inDays > 30;
  }).length;
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportProvider);
    final turnoverAsync = ref.watch(turnoverProvider);
    final overdueAsync = ref.watch(overdueCountProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: summaryAsync.when(
        data: (summary) {
          final turnover = turnoverAsync.valueOrNull ?? {};
          final overdue = overdueAsync.valueOrNull ?? 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryCard(summary, overdue),
              const SizedBox(height: 12),
              _turnoverCard(turnover, summary.totalAmount),
              const SizedBox(height: 12),
              _barChartCard(turnover),
              const SizedBox(height: 12),
              _breakdownCard(summary),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _summaryCard(DashboardSummary s, int overdue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 24),
            _row('Distributors', s.totalDistributors.toString(), AppColors.info),
            _row('Total Bills', s.totalBills.toString(), AppColors.info),
            _row('Total Amount', '₹${s.totalAmount.toStringAsFixed(0)}', AppColors.textPrimary),
            _row('Total Paid', '₹${s.totalPaid.toStringAsFixed(0)}', AppColors.success),
            _row('Pending', '₹${s.totalPending.toStringAsFixed(0)}', AppColors.danger),
            if (overdue > 0) _row('Overdue Bills', overdue.toString(), AppColors.danger),
            if (s.totalAmount > 0) ...[
              const Divider(height: 20),
              _row('Collection Rate', '${(s.totalPaid / s.totalAmount * 100).toStringAsFixed(1)}%', AppColors.accent),
            ],
          ],
        ),
      ),
    );
  }

  Widget _turnoverCard(Map<String, double> turnover, double total) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Turnover', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            if (turnover.isEmpty)
              const Text('No data', style: TextStyle(color: AppColors.textSecondary))
            else
              ...turnover.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: total > 0 ? e.value / total : 0,
                        backgroundColor: AppColors.divider,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('₹${e.value.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Widget _barChartCard(Map<String, double> turnover) {
    if (turnover.isEmpty) return const SizedBox();

    final entries = turnover.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Chart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= entries.length) return const SizedBox();
                          final label = entries[i].key.split('-').last;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(label, style: const TextStyle(fontSize: 9)),
                          );
                        },
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: entries.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value,
                          color: AppColors.accent,
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _breakdownCard(DashboardSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Distributor Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            ...summary.distributorBalances.map((d) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.distributor.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text('${d.billCount} bills', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Text('₹${d.billedAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 16),
                  Text('₹${d.pendingAmount.toStringAsFixed(0)}', style: TextStyle(color: d.pendingAmount > 0 ? AppColors.danger : AppColors.success, fontWeight: FontWeight.w600)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
