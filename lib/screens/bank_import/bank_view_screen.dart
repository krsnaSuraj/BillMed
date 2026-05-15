import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';

final bankTxnsProvider = FutureProvider<List<BankTransaction>>((ref) async {
  final db = ref.watch(databaseProvider);
  final txns = await db.getAllBankTransactions();
  txns.sort((a, b) => b.txnDate.compareTo(a.txnDate)); // newest first
  return txns;
});

class BankViewScreen extends ConsumerStatefulWidget {
  const BankViewScreen({super.key});
  @override
  ConsumerState<BankViewScreen> createState() => _BankViewScreenState();
}

class _BankViewScreenState extends ConsumerState<BankViewScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filter = 'All'; // All | Debit | Credit

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final txnsAsync = ref.watch(bankTxnsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Transactions'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(bankTxnsProvider)),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear All',
            onPressed: () => _confirmClearAll(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Filter chips
              _filterChip('All', AppColors.info),
              const SizedBox(width: 4),
              _filterChip('Credit', AppColors.success),
              const SizedBox(width: 4),
              _filterChip('Debit', AppColors.danger),
            ]),
          ),
          Expanded(
            child: txnsAsync.when(
              data: (txns) {
                // Apply filters
                var filtered = txns.where((t) {
                  final matchSearch = _query.isEmpty || t.description.toLowerCase().contains(_query) || (t.category?.toLowerCase().contains(_query) ?? false);
                  final matchFilter = _filter == 'All' || (_filter == 'Credit' && t.credit > 0) || (_filter == 'Debit' && t.debit > 0);
                  return matchSearch && matchFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 12),
                      Text(_query.isNotEmpty || _filter != 'All' ? 'No matching transactions' : 'No transactions imported yet',
                          style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ));
                }

                final totalDebit = filtered.fold<double>(0, (s, t) => s + t.debit);
                final totalCredit = filtered.fold<double>(0, (s, t) => s + t.credit);

                return Column(children: [
                  // Summary bar
                  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      child: Row(children: [
                        _stat('${filtered.length}', 'Txns', AppColors.info),
                        _vDivider(),
                        _stat('Rs.${totalDebit.toStringAsFixed(0)}', 'Total Out', AppColors.danger),
                        _vDivider(),
                        _stat('Rs.${totalCredit.toStringAsFixed(0)}', 'Total In', AppColors.success),
                        _vDivider(),
                        _stat('Rs.${(totalCredit - totalDebit).toStringAsFixed(0)}', 'Net', (totalCredit - totalDebit) >= 0 ? AppColors.success : AppColors.danger),
                      ]),
                    ),
                  ),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final t = filtered[i];
                        final isCredit = t.credit > 0;
                        final amountColor = isCredit ? AppColors.success : AppColors.danger;
                        final amount = isCredit ? t.credit : t.debit;
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              // Icon
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: amountColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  color: amountColor, size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Description
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t.description,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                    maxLines: 2, overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_dayName(t.txnDate.weekday)}, ${t.txnDate.day} ${_monthName(t.txnDate.month)} ${t.txnDate.year}',
                                    style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                                  ),
                                ],
                              )),
                              const SizedBox(width: 8),
                              // Amount + Balance
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(
                                  '${isCredit ? '+' : '-'}Rs.${amount.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: amountColor),
                                ),
                                Text(
                                  'Bal: Rs.${t.balance.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 10, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                                ),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ]);
              },
              error: (e, _) => Center(child: Text('Error: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, Color color) {
    final selected = _filter == label;
    return GestureDetector(
      onTap: () => setState(() => _filter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, color: selected ? color : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _stat(String value, String label, Color color) {
    return Expanded(child: Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color), overflow: TextOverflow.ellipsis),
      Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
    ]));
  }

  Widget _vDivider() => Container(width: 1, height: 30, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1));

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
              await ref.read(databaseProvider).deleteAllBankTransactions();
              ref.invalidate(bankTxnsProvider);
            },
            child: const Text('Delete All', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }

  static String _dayName(int d) => const ['','Mon','Tue','Wed','Thu','Fri','Sat','Sun'][d];
  static String _monthName(int m) => const ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m];
}
