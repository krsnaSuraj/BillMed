import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../bills/add_bill_screen.dart';
import '../bills/bill_detail_screen.dart';
import '../scanner/bill_scanner.dart';
import 'package:image_picker/image_picker.dart';

final _billsProvider = FutureProvider.family<List<Bill>, int>((ref, distId) async {
  final db = ref.watch(databaseProvider);
  return db.getBillsByDistributor(distId);
});

class DistributorDetailScreen extends ConsumerWidget {
  final int distributorId;
  const DistributorDetailScreen({super.key, required this.distributorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distAsync = ref.watch(distributorListProvider);
    final billsAsync = ref.watch(_billsProvider(distributorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Bill',
            onPressed: () => _scanBill(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddBillScreen(distributorId: distributorId)));
          if (result == true) ref.invalidate(_billsProvider(distributorId));
        },
        child: const Icon(Icons.add),
      ),
      body: distAsync.when(
        data: (dists) {
          final dist = dists.where((d) => d.id == distributorId).firstOrNull;
          if (dist == null) return const Center(child: Text('Supplier not found'));
          return Column(
            children: [
              _header(context, dist),
              Expanded(child: _billsList(context, billsAsync, ref)),
            ],
          );
        },
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _header(BuildContext context, Distributor dist) {
    return Container(
      color: Theme.of(context).cardTheme.color,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(dist.name[0].toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dist.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (dist.company != null && dist.company!.isNotEmpty)
                  Text(dist.company!, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                if (dist.phone != null && dist.phone!.isNotEmpty)
                  Text(dist.phone!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billsList(BuildContext context, AsyncValue<List<Bill>> billsAsync, WidgetRef ref) {
    return billsAsync.when(
      data: (bills) {
        if (bills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary.withOpacity(0.3)),
                const SizedBox(height: 12),
                const Text('No bills yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddBillScreen(distributorId: distributorId)));
                    if (result == true) ref.invalidate(_billsProvider(distributorId));
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Bill'),
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
            itemBuilder: (ctx, i) => _billCard(context, bills[i], ref),
          ),
        );
      },
      error: (e, _) => Center(child: Text('$e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _billCard(BuildContext context, Bill bill, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)));
          ref.invalidate(_billsProvider(distributorId));
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.receipt, color: AppColors.info, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Text('₹${bill.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              StatusBadgeWidget(billId: bill.id),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _scanBill(BuildContext context, WidgetRef ref) async {
  final source = await showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Scan Bill'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.camera), child: const Text('Camera')),
        TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.gallery), child: const Text('Gallery')),
      ],
    ),
  );
  if (source == null || !context.mounted) return;
  BillScanResult? result;
  if (source == ImageSource.camera) {
    result = await BillScanner.scanFromCamera(context);
  } else {
    result = await BillScanner.scanFromGallery(context);
  }
  if (result == null || !context.mounted) return;
  final confirmed = await Navigator.push<BillScanResult>(
    context,
    MaterialPageRoute(builder: (_) => ScanPreviewScreen(result: result!)),
  );
  if (confirmed != null && context.mounted) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddBillScreen(
        prefillNumber: confirmed.billNumber,
        prefillAmount: confirmed.amount,
        prefillDate: confirmed.billDate,
      )),
    );
  }
}

class StatusBadgeWidget extends ConsumerWidget {
  final int billId;
  const StatusBadgeWidget({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(billStatusProvider(billId));
    return statusAsync.when(
      data: (status) {
        final color = status == 'Paid' ? AppColors.success : status == 'Partial' ? AppColors.warning : AppColors.danger;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        );
      },
      error: (_, __) => const SizedBox(),
      loading: () => const SizedBox(),
    );
  }
}
