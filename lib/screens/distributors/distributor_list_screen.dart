import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import 'add_distributor_screen.dart';
import 'distributor_detail_screen.dart';

class DistributorListScreen extends ConsumerWidget {
  const DistributorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(distributorListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Suppliers')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDistributorScreen()));
          ref.invalidate(distributorListProvider);
        },
        child: const Icon(Icons.add),
      ),
      body: async.when(
        data: (distributors) {
          if (distributors.isEmpty) return _emptyState(context, ref);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(distributorListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: distributors.length,
              itemBuilder: (ctx, i) => _distributorCard(context, distributors[i], ref),
            ),
          );
        },
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _distributorCard(BuildContext context, Distributor d, WidgetRef ref) {
    final colors = [AppColors.info, AppColors.accent, AppColors.primary, AppColors.success, AppColors.warning];
    final color = colors[d.id % colors.length];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => DistributorDetailScreen(distributorId: d.id)));
          ref.invalidate(distributorListProvider);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.1),
                child: Text(d.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    if (d.company != null && d.company!.isNotEmpty)
                      Text(d.company!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_outlined, size: 72, color: AppColors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No suppliers yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddDistributorScreen()));
              ref.invalidate(distributorListProvider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Supplier'),
          ),
        ],
      ),
    );
  }
}
