import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../payments/add_payment_screen.dart';

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
      appBar: AppBar(title: const Text('Bill Details')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddPaymentScreen(billId: billId)),
          );
          ref.invalidate(_paymentsProvider(billId));
          ref.invalidate(paidAmountProvider(billId));
        },
        icon: const Icon(Icons.payments_rounded),
        label: const Text('Add Payment'),
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
                      decoration: BoxDecoration(
                        color: AppColors.info.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
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
                Icon(Icons.payments_outlined, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
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
            ...payments.map((p) => _paymentCard(p)),
          ],
        );
      },
      error: (e, _) => Center(child: Text('$e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _paymentCard(Payment p) {
    IconData modeIcon;
    Color modeColor;
    switch (p.mode) {
      case 'Cash':
        modeIcon = Icons.money;
        modeColor = AppColors.success;
        break;
      case 'UPI':
        modeIcon = Icons.phone_android;
        modeColor = AppColors.info;
        break;
      case 'Cheque':
        modeIcon = Icons.receipt;
        modeColor = AppColors.warning;
        break;
      case 'NEFT':
      case 'RTGS':
        modeIcon = Icons.account_balance;
        modeColor = AppColors.primary;
        break;
      default:
        modeIcon = Icons.payment;
        modeColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
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
                  decoration: BoxDecoration(
                    color: modeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
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
    );
  }
}
