import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/daos.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';

final reportProvider = FutureProvider<DashboardSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  return BillMedDao(db).getDashboardSummary();
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(reportProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: reportAsync.when(
        data: (summary) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(height: 24),
                    _row('Total Distributors', summary.totalDistributors.toString(), AppColors.info),
                    _row('Total Bills', summary.totalBills.toString(), AppColors.info),
                    _row('Total Amount', '₹${summary.totalAmount.toStringAsFixed(0)}', AppColors.textPrimary),
                    _row('Total Paid', '₹${summary.totalPaid.toStringAsFixed(0)}', AppColors.success),
                    _row('Pending', '₹${summary.totalPending.toStringAsFixed(0)}', AppColors.danger),
                    if (summary.totalAmount > 0) ...[
                      const Divider(height: 20),
                      _row('Payment Rate', '${(summary.totalPaid / summary.totalAmount * 100).toStringAsFixed(1)}%', AppColors.accent),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
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
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
