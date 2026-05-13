import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../distributors/distributor_detail_screen.dart';
import '../distributors/add_distributor_screen.dart';

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  final dao = BillMedDao(db);
  return dao.getDashboardSummary();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BillMed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 28),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: async.when(
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              _buildSummaryCard(context, summary),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Distributors Summary',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(height: 4),
              if (summary.distributorBalances.isEmpty)
                _buildEmptyState(context)
              else
                ...summary.distributorBalances.map(
                  (d) => _buildDistributorTile(context, d, ref),
                ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e', style: const TextStyle(fontSize: 18)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, DashboardSummary summary) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(
                  '₹${summary.totalAmount.toStringAsFixed(0)}',
                  'Total Billed',
                  Colors.blue,
                ),
                _summaryItem(
                  '₹${summary.totalPaid.toStringAsFixed(0)}',
                  'Total Paid',
                  AppTheme.successColor,
                ),
                _summaryItem(
                  '₹${summary.totalPending.toStringAsFixed(0)}',
                  'Pending',
                  AppTheme.dangerColor,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(
                  '${summary.totalDistributors}',
                  'Distributors',
                  Colors.grey,
                ),
                _summaryItem(
                  '${summary.totalBills}',
                  'Total Bills',
                  Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDistributorTile(
      BuildContext context, DistributorBalance d, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DistributorDetailScreen(
                distributorId: d.distributor.id,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                child: Text(
                  d.distributor.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.distributor.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    if (d.distributor.company != null &&
                        d.distributor.company!.isNotEmpty)
                      Text(d.distributor.company!,
                          style: const TextStyle(
                              fontSize: 15, color: Colors.grey)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${d.pendingAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: d.pendingAmount > 0
                              ? AppTheme.dangerColor
                              : AppTheme.successColor)),
                  Text(
                    '${d.billCount} bills | ${d.paidBillCount} paid',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No distributors yet',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddDistributorScreen()),
              );
            },
            child: const Text('Add Distributor'),
          ),
        ],
      ),
    );
  }
}
