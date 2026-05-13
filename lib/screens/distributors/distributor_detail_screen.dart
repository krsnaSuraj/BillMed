import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import '../bills/add_bill_screen.dart';
import '../bills/bill_detail_screen.dart';

final _distributorProvider =
    FutureProvider.family<Distributor?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return db.getDistributor(id);
});

final _billsProvider =
    FutureProvider.family<List<Bill>, int>((ref, distId) async {
  final db = ref.watch(databaseProvider);
  return db.getBillsByDistributor(distId);
});

class DistributorDetailScreen extends ConsumerWidget {
  final int distributorId;
  const DistributorDetailScreen({super.key, required this.distributorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distAsync = ref.watch(_distributorProvider(distributorId));
    final billsAsync = ref.watch(_billsProvider(distributorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Distributor Details')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddBillScreen(distributorId: distributorId),
            ),
          );
          ref.invalidate(_billsProvider(distributorId));
        },
        child: const Icon(Icons.add, size: 32),
      ),
      body: distAsync.when(
        data: (dist) {
          if (dist == null) {
            return const Center(child: Text('Distributor not found'));
          }
          return Column(
            children: [
              _buildHeader(context, dist),
              Expanded(
                child: billsAsync.when(
                  data: (bills) => _buildBillList(context, bills, ref),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  loading: () => const Center(
                      child: CircularProgressIndicator()),
                ),
              ),
            ],
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Distributor dist) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              dist.name[0].toUpperCase(),
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(dist.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (dist.company != null && dist.company!.isNotEmpty)
            Text(dist.company!,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
          if (dist.phone != null && dist.phone!.isNotEmpty)
            Text(dist.phone!,
                style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildBillList(
      BuildContext context, List<Bill> bills, WidgetRef ref) {
    if (bills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No bills yet',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddBillScreen(distributorId: distributorId),
                  ),
                );
                ref.invalidate(_billsProvider(distributorId));
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Bill'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(_billsProvider(distributorId)),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: bills.length,
        itemBuilder: (context, index) {
          final bill = bills[index];
          return _buildBillCard(context, bill, ref);
        },
      ),
    );
  }

  Widget _buildBillCard(BuildContext context, Bill bill, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BillDetailScreen(billId: bill.id),
            ),
          );
          ref.invalidate(_billsProvider(distributorId));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bill #${bill.billNumber}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}',
                      style: const TextStyle(fontSize: 15, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${bill.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  StatusBadge(billId: bill.id),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
