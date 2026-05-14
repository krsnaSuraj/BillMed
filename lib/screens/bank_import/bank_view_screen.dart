import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';

final bankTxnsProvider = FutureProvider<List<BankTransaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getAllBankTransactions();
});

class BankViewScreen extends ConsumerStatefulWidget {
  const BankViewScreen({super.key});

  @override
  ConsumerState<BankViewScreen> createState() => _BankViewScreenState();
}

class _BankViewScreenState extends ConsumerState<BankViewScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(bankTxnsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(bankTxnsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All Transactions',
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search transactions...',
                prefixIcon: const Icon(Icons.search, size: 22),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: txnsAsync.when(
              data: (txns) {
                final filtered = _query.isEmpty
                    ? txns
                    : txns.where((t) =>
                        t.description.toLowerCase().contains(_query) ||
                        (t.category?.toLowerCase().contains(_query) ?? false))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(_query.isNotEmpty ? 'No matching transactions' : 'No transactions imported yet',
                            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                final totalDebit = filtered.fold<double>(0, (s, t) => s + t.debit);
                final totalCredit = filtered.fold<double>(0, (s, t) => s + t.credit);

                return Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.all(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            _stat('Debits', '₹${totalDebit.toStringAsFixed(0)}', AppColors.danger),
                            _stat('Credits', '₹${totalCredit.toStringAsFixed(0)}', AppColors.success),
                            _stat('Net', '₹${(totalCredit - totalDebit).toStringAsFixed(0)}', AppColors.info),
                            _stat('Count', '${filtered.length}', AppColors.textPrimary),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) {
                          final t = filtered[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 65,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${t.txnDate.day}/${t.txnDate.month}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text('${t.txnDate.year}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(t.description, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (t.debit > 0) Text('-₹${t.debit.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 12)),
                                      if (t.credit > 0) Text('+₹${t.credit.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              error: (e, _) => Center(child: Text('$e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Transactions?'),
        content: const Text('This will permanently delete all imported bank transactions. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = ref.read(databaseProvider);
              await db.deleteAllBankTransactions();
              ref.invalidate(bankTxnsProvider);
            },
            child: const Text('Delete All', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
