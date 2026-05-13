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

final _paymentsProvider =
    FutureProvider.family<List<Payment>, int>((ref, billId) async {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPaymentScreen(billId: billId),
            ),
          );
          ref.invalidate(_paymentsProvider(billId));
          ref.invalidate(paidAmountProvider(billId));
        },
        child: const Icon(Icons.payments_rounded, size: 28),
      ),
      body: billAsync.when(
        data: (bill) {
          if (bill == null) {
            return const Center(child: Text('Bill not found'));
          }
          return Column(
            children: [
              _buildBillHeader(context, bill, paidAsync),
              Expanded(
                child: paymentsAsync.when(
                  data: (payments) =>
                      _buildPaymentsList(context, payments, ref),
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

  Widget _buildBillHeader(BuildContext context, Bill bill,
      AsyncValue<double> paidAsync) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: paidAsync.when(
          data: (paid) {
            final remaining = bill.amount - paid;
            final status = paid <= 0
                ? 'Unpaid'
                : paid < bill.amount
                    ? 'Partial'
                    : 'Paid';
            final statusColor = status == 'Paid'
                ? AppTheme.successColor
                : status == 'Partial'
                    ? AppTheme.warningColor
                    : AppTheme.dangerColor;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bill #${bill.billNumber}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _headerItem('Bill Amount', '₹${bill.amount.toStringAsFixed(0)}', Colors.blue),
                    _headerItem('Paid', '₹${paid.toStringAsFixed(0)}', AppTheme.successColor),
                    _headerItem('Remaining', '₹${remaining.toStringAsFixed(0)}',
                        remaining > 0 ? AppTheme.dangerColor : AppTheme.successColor),
                  ],
                ),
              ],
            );
          },
          error: (e, _) => Text('Error: $e'),
          loading: () => const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _headerItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style:
                TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildPaymentsList(
      BuildContext context, List<Payment> payments, WidgetRef ref) {
    if (payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No payments yet',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddPaymentScreen(billId: billId),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Payment'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_paymentsProvider(billId));
        ref.invalidate(paidAmountProvider(billId));
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: payments.length,
        itemBuilder: (context, index) {
          final p = payments[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                    child: Icon(Icons.payment_rounded,
                        color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('₹${p.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        Text(
                          '${p.paymentDate.day}/${p.paymentDate.month}/${p.paymentDate.year}',
                          style: const TextStyle(
                              fontSize: 15, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(p.mode,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                      if (p.referenceNo != null && p.referenceNo!.isNotEmpty)
                        Text('Ref: ${p.referenceNo}',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
