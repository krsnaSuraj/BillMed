import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../database/daos.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import 'add_distributor_screen.dart';
import 'distributor_detail_screen.dart';

final distributorBalancesProvider = FutureProvider<List<DistributorBalance>>((ref) async {
  final db = ref.watch(databaseProvider);
  final dao = BillMedDao(db);
  final summary = await dao.getDashboardSummary();
  return summary.distributorBalances;
});

class DistributorListScreen extends ConsumerStatefulWidget {
  const DistributorListScreen({super.key});

  @override
  ConsumerState<DistributorListScreen> createState() => _DistributorListScreenState();
}

class _DistributorListScreenState extends ConsumerState<DistributorListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final balancesAsync = ref.watch(distributorBalancesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDistributorScreen()));
          ref.invalidate(distributorBalancesProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: balancesAsync.when(
        data: (all) {
          final list = _query.isEmpty ? all : all.where((b) =>
            b.distributor.name.toLowerCase().contains(_query) ||
            (b.distributor.company?.toLowerCase().contains(_query) ?? false)
          ).toList();
          return Column(
            children: [
              _buildSearch(),
              Expanded(child: list.isEmpty ? _emptyState(context, ref) : _buildList(list, ref)),
            ],
          );
        },
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search suppliers...',
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: _query.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildList(List<DistributorBalance> list, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(distributorBalancesProvider),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: list.length,
        itemBuilder: (ctx, i) => _buildCard(context, list[i], ref),
      ),
    );
  }

  Widget _buildCard(BuildContext context, DistributorBalance b, WidgetRef ref) {
    final colors = [AppColors.info, AppColors.accent, AppColors.primary, AppColors.success, AppColors.warning];
    final color = colors[b.distributor.id % colors.length];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => DistributorDetailScreen(distributorId: b.distributor.id)));
          ref.invalidate(distributorBalancesProvider);
        },
        onLongPress: () => _showOptions(context, b.distributor, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.1),
                child: Text(b.distributor.name[0].toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.distributor.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    if (b.distributor.company != null && b.distributor.company!.isNotEmpty)
                      Text(b.distributor.company!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${b.pendingAmount.toStringAsFixed(0)}',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16,
                          color: b.pendingAmount > 0 ? AppColors.danger : AppColors.success)),
                  Text('${b.billCount} bills', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, Distributor d, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.info),
              title: const Text('Edit Supplier'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => AddDistributorScreen(distributor: d)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: const Text('Delete Supplier'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, d, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Distributor d, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier?'),
        content: Text('Delete ${d.name} and all their bills and payments?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(databaseProvider);
              final bills = await db.getBillsByDistributor(d.id);
              for (final bill in bills) {
                final payments = await db.getPaymentsByBill(bill.id);
                for (final p in payments) { await db.deletePayment(p.id); }
                await db.deleteBill(bill.id);
              }
              await db.deleteDistributor(d.id);
              ref.invalidate(distributorBalancesProvider);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 72, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(_query.isNotEmpty ? 'No suppliers match your search' : 'No suppliers yet',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          if (_query.isEmpty) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDistributorScreen()));
                ref.invalidate(distributorBalancesProvider);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Supplier'),
            ),
          ],
        ],
      ),
    );
  }
}
