import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/daos.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../distributors/distributor_detail_screen.dart';
import '../distributors/add_distributor_screen.dart';

final dashboardProvider = FutureProvider<DashboardSummary>((ref) async {
  final db = ref.watch(databaseProvider);
  return BillMedDao(db).getDashboardSummary();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.medical_services, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('BillMed'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dashboardProvider),
          ),
        ],
      ),
      body: summaryAsync.when(
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardProvider),
          child: ListView(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            children: [
              _buildSummaryGrid(data),
              const SizedBox(height: 8),
              _buildRecentHeader(context),
              ...data.distributorBalances.map(
                (d) => _distributorTile(context, d, ref),
              ),
              if (data.distributorBalances.isEmpty) _emptyState(context, ref),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _buildSummaryGrid(DashboardSummary data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _summaryCard('Total Billed', '₹${data.totalAmount.toStringAsFixed(0)}', AppColors.info, Icons.receipt_long, flex: 2),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              children: [
                _miniCard('Paid', '₹${data.totalPaid.toStringAsFixed(0)}', AppColors.success, Icons.check_circle),
                const SizedBox(height: 8),
                _miniCard('Pending', '₹${data.totalPending.toStringAsFixed(0)}', AppColors.danger, Icons.pending),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniCard(String label, String value, Color color, IconData icon) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text('Distributors', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text('Pending', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _distributorTile(BuildContext context, DistributorBalance d, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DistributorDetailScreen(distributorId: d.distributor.id),
            ),
          ).then((_) => ref.invalidate(dashboardProvider));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  d.distributor.name[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.distributor.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    if (d.distributor.company != null && d.distributor.company!.isNotEmpty)
                      Text(d.distributor.company!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${d.pendingAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: d.pendingAmount > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  Text('${d.billCount} bills', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 72, color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No distributors yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDistributorScreen()));
              ref.invalidate(dashboardProvider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Distributor'),
          ),
        ],
      ),
    );
  }
}
