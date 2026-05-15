import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../payments/add_payment_screen.dart';
import 'add_bill_screen.dart';

import '../../services/pdf_export_service.dart';
import '../dashboard/dashboard_screen.dart';

final _billProvider = FutureProvider.family<Bill?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return db.getBill(id);
});

final _paymentsProvider = FutureProvider.family<List<Payment>, int>((ref, billId) async {
  final db = ref.watch(databaseProvider);
  return db.getPaymentsByBill(billId);
});

class BillDetailScreen extends ConsumerWidget {
  final int billId;
  const BillDetailScreen({super.key, required this.billId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billAsync = ref.watch(_billProvider(billId));
    final paymentsAsync = ref.watch(_paymentsProvider(billId));
    final paidAsync = ref.watch(paidAmountProvider(billId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await PdfExportService.generateBillPdf(db, billId);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDeleteBill(context, ref),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            width: 40,
            child: FloatingActionButton.small(
              heroTag: 'edit',
              onPressed: () async {
                final db = ref.read(databaseProvider);
                final bill = await db.getBill(billId);
                if (bill != null && context.mounted) {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddBillScreen(bill: bill)));
                  if (result == true) {
                    ref.invalidate(_billProvider(billId));
                    ref.invalidate(_paymentsProvider(billId));
                    ref.invalidate(paidAmountProvider(billId));
                    ref.invalidate(allBillsProvider);
                    ref.invalidate(dashboardProvider);
                  }
                }
              },
              child: const Icon(Icons.edit, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'payment',
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddPaymentScreen(billId: billId)));
              if (result == true) {
                ref.invalidate(_paymentsProvider(billId));
                ref.invalidate(paidAmountProvider(billId));
              }
            },
            icon: const Icon(Icons.payments_rounded),
            label: const Text('Add Payment'),
          ),
        ],
      ),
      body: billAsync.when(
        data: (bill) {
          if (bill == null) return const Center(child: Text('Bill not found'));
          return ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _buildHeader(context, bill, paidAsync),
              _buildPaymentHistory(context, paymentsAsync, ref),
            ],
          );
        },
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _confirmDeleteBill(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: const Text('This will also delete all payments for this bill.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(databaseProvider);
              final payments = await db.getPaymentsByBill(billId);
              for (final p in payments) { await db.deletePayment(p.id); }
              await db.deleteBill(billId);
              // Refresh all dependent providers after deletion
              ref.invalidate(allBillsProvider);
              ref.invalidate(dashboardProvider);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Bill bill, AsyncValue<double> paidAsync) {
    return paidAsync.when(
      data: (paid) {
        final remaining = (bill.amount - paid).clamp(0, bill.amount);
        final status = paid <= 0 ? 'Unpaid' : paid < bill.amount ? 'Partial' : 'Paid';
        final statusColor = status == 'Paid' ? AppColors.success : status == 'Partial' ? AppColors.warning : AppColors.danger;

        return Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.receipt, color: AppColors.info, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bill #${bill.billNumber}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 14)),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    _amountCol('Bill Amount', '₹${bill.amount.toStringAsFixed(0)}', AppColors.info),
                    _amountCol('Paid', '₹${paid.toStringAsFixed(0)}', AppColors.success),
                    _amountCol('Remaining', '₹${remaining.toStringAsFixed(0)}', remaining > 0 ? AppColors.danger : AppColors.success),
                  ],
                ),
                if (bill.notes != null && bill.notes!.isNotEmpty) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.notes, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(bill.notes!, style: const TextStyle(color: AppColors.textSecondary))),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
      error: (e, _) => Text('$e'),
      loading: () => const CircularProgressIndicator(),
    );
  }

  Widget _amountCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(BuildContext context, AsyncValue<List<Payment>> paymentsAsync, WidgetRef ref) {
    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(Icons.payments_outlined, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('No payments recorded yet', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text('${payments.length} payment${payments.length > 1 ? 's' : ''}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            ...payments.map((p) => _paymentCard(context, p, ref)),
          ],
        );
      },
      error: (e, _) => Center(child: Text('$e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _paymentCard(BuildContext context, Payment p, WidgetRef ref) {
    final (modeIcon, modeColor) = _paymentModeStyle(p.mode);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => _showPaymentOptions(context, p, ref),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: modeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(modeIcon, color: modeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₹${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    Text('${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: modeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(p.mode, style: TextStyle(fontSize: 12, color: modeColor, fontWeight: FontWeight.w500)),
                  ),
                  if (p.referenceNo != null && p.referenceNo!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('Ref: ${p.referenceNo}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (IconData, Color) _paymentModeStyle(String mode) {
    switch (mode) {
      case 'Cash': return (Icons.money, AppColors.success);
      case 'UPI': return (Icons.phone_android, AppColors.info);
      case 'Cheque': return (Icons.receipt, AppColors.warning);
      case 'NEFT':
      case 'RTGS': return (Icons.account_balance, AppColors.primary);
      default: return (Icons.payment, AppColors.textSecondary);
    }
  }

  void _showPaymentOptions(BuildContext context, Payment p, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.info),
              title: const Text('Edit Payment'),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => AddPaymentScreen(billId: billId, payment: p)),
                );
                if (result == true) {
                  ref.invalidate(_paymentsProvider(billId));
                  ref.invalidate(paidAmountProvider(billId));
                  ref.invalidate(dashboardProvider);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.danger),
              title: const Text('Delete Payment'),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeletePayment(context, p, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, Payment p, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment?'),
        content: Text('Delete payment of ₹${p.amount.toStringAsFixed(0)} from ${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(databaseProvider).deletePayment(p.id);
              ref.invalidate(_paymentsProvider(billId));
              ref.invalidate(paidAmountProvider(billId));
              ref.invalidate(allBillsProvider);
              ref.invalidate(dashboardProvider);
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}
