import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../services/bank_statement_service.dart';
import '../../theme/app_theme.dart';

class BankPreviewScreen extends ConsumerWidget {
  final List<ParsedTransaction> transactions;
  final String fileName;
  final String status;
  final String message;

  const BankPreviewScreen({
    super.key,
    required this.transactions,
    required this.fileName,
    required this.status,
    required this.message,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalDebit = transactions.fold<double>(0, (s, t) => s + t.debit);
    final totalCredit = transactions.fold<double>(0, (s, t) => s + t.credit);
    final balanceColor = status == 'VERIFIED' ? AppColors.success : AppColors.warning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _save(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(status == 'VERIFIED' ? Icons.verified : Icons.warning_amber,
                          color: balanceColor, size: 20),
                      const SizedBox(width: 8),
                      Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: balanceColor)),
                      const Spacer(),
                      Text('${transactions.length} transactions', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      _summaryCol('Total Debit', '₹${totalDebit.toStringAsFixed(0)}', AppColors.danger),
                      _summaryCol('Total Credit', '₹${totalCredit.toStringAsFixed(0)}', AppColors.success),
                      _summaryCol('Net', '₹${(totalCredit - totalDebit).toStringAsFixed(0)}', AppColors.info),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Transaction list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: transactions.length,
              itemBuilder: (ctx, i) {
                final t = transactions[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
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
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      for (final t in transactions) {
        await db.addBankTransaction(BankTransactionsCompanion(
          txnDate: Value(t.txnDate),
          description: Value(t.description),
          debit: Value(t.debit),
          credit: Value(t.credit),
          balance: Value(t.balance),
          sourceFile: Value(fileName),
        ));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${transactions.length} transactions imported successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e')),
        );
      }
    }
  }
}
