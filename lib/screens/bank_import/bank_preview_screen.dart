import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../services/bank_statement_service.dart';
import '../../theme/app_theme.dart';
import 'bank_view_screen.dart';

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

    final statusColor = status == 'VERIFIED'
        ? AppColors.success
        : status == 'PARTIAL'
            ? AppColors.warning
            : AppColors.danger;

    final statusIcon = status == 'VERIFIED'
        ? Icons.verified
        : status == 'PARTIAL'
            ? Icons.warning_amber_rounded
            : Icons.error_outline;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Transactions'),
        actions: [
          TextButton.icon(
            onPressed: () => _save(context, ref),
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Status + message banner ──────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      status == 'VERIFIED'
                          ? 'Balance Verified'
                          : status == 'PARTIAL'
                              ? 'Partial Match'
                              : 'Balance Mismatch',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: statusColor),
                    ),
                    const Spacer(),
                    Text('${transactions.length} transactions',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(message,
                      style: TextStyle(fontSize: 12, color: statusColor)),
                ],
              ],
            ),
          ),

          // ── Summary row ──────────────────────────────────────────────────────
          Card(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _summaryCol(
                      'Total Debit',
                      '₹${totalDebit.toStringAsFixed(2)}',
                      AppColors.danger),
                  _summaryCol(
                      'Total Credit',
                      '₹${totalCredit.toStringAsFixed(2)}',
                      AppColors.success),
                  _summaryCol(
                      'Net',
                      '₹${(totalCredit - totalDebit).toStringAsFixed(2)}',
                      AppColors.info),
                ],
              ),
            ),
          ),

          // ── Transaction list ──────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
                          width: 42,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t.txnDate.day}/${t.txnDate.month}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              Text(
                                '${t.txnDate.year}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.description,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (t.debit > 0)
                              Text(
                                '-₹${t.debit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                            if (t.credit > 0)
                              Text(
                                '+₹${t.credit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12),
                              ),
                            if (t.balance > 0)
                              Text(
                                'Bal: ₹${t.balance.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _save(context, ref),
        icon: const Icon(Icons.save),
        label: const Text('Save All'),
      ),
    );
  }

  Widget _summaryCol(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    // For non-VERIFIED status, show a confirmation with the message
    if (status != 'VERIFIED' && context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(
                status == 'PARTIAL'
                    ? Icons.warning_amber_rounded
                    : Icons.error_outline,
                color: status == 'PARTIAL'
                    ? AppColors.warning
                    : AppColors.danger,
                size: 22,
              ),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('Save Anyway?',
                      style: TextStyle(fontSize: 16))),
            ],
          ),
          content: Text(
            message.isNotEmpty
                ? '$message\n\nYou can still save and correct the data manually later.'
                : 'Balance could not be fully verified. Save anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    try {
      final db = ref.read(databaseProvider);
      int saved = 0;
      for (final t in transactions) {
        await db.addBankTransaction(BankTransactionsCompanion(
          txnDate: Value(t.txnDate),
          description: Value(t.description),
          debit: Value(t.debit),
          credit: Value(t.credit),
          balance: Value(t.balance),
          sourceFile: Value(fileName),
        ));
        saved++;
      }
      if (context.mounted) {
        ref.invalidate(bankTxnsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$saved transactions imported successfully'),
              backgroundColor: AppColors.success),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
