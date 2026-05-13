import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/pdf_export_service.dart';
import '../../services/export_service.dart';

class YearlyReportScreen extends ConsumerWidget {
  const YearlyReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CA Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export as PDF',
            onPressed: () async {
              // Generate PDF report for CA
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export as CSV',
            onPressed: () async {
              await ExportService.exportToCsv(db, type: 'bank');
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: Future.wait([
          db.getAllBills(),
          db.getAllBankTransactions(),
        ]),
        builder: (ctx, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allBills = snapshot.data![0] as List<Bill>;
          final allTxns = snapshot.data![1] as List<BankTransaction>;

          // Yearly summary from bills
          final billTotal = allBills.fold<double>(0, (s, b) => s + b.amount);
          final billCount = allBills.length;

          // Yearly summary from bank transactions
          final txnDebit = allTxns.fold<double>(0, (s, t) => s + t.debit);
          final txnCredit = allTxns.fold<double>(0, (s, t) => s + t.credit);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Annual Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Divider(height: 24),

                      // Bills section
                      const Text('Bills', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.info)),
                      const SizedBox(height: 8),
                      _row('Total Bills', billCount.toString(), AppColors.info),
                      _row('Total Amount', '₹${billTotal.toStringAsFixed(0)}', AppColors.textPrimary),

                      const Divider(height: 20),

                      // Bank Transactions section
                      const Text('Bank Transactions', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.accent)),
                      const SizedBox(height: 8),
                      _row('Total Debits', '₹${txnDebit.toStringAsFixed(0)}', AppColors.danger),
                      _row('Total Credits', '₹${txnCredit.toStringAsFixed(0)}', AppColors.success),
                      _row('Net (Credits - Debits)', '₹${(txnCredit - txnDebit).toStringAsFixed(0)}',
                          (txnCredit - txnDebit) >= 0 ? AppColors.success : AppColors.danger),
                      _row('Total Transactions', allTxns.length.toString(), AppColors.info),

                      if (allTxns.isNotEmpty) ...[
                        const Divider(height: 20),
                        const Text('Monthly Breakdown', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ..._monthlyBreakdown(allTxns),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _monthlyBreakdown(List<BankTransaction> txns) {
    final months = <String, Map<String, double>>{};
    for (final t in txns) {
      final key = '${t.txnDate.year}-${t.txnDate.month.toString().padLeft(2, '0')}';
      months.putIfAbsent(key, () => {'debit': 0.0, 'credit': 0.0});
      months[key]!['debit'] = (months[key]!['debit'] ?? 0) + t.debit;
      months[key]!['credit'] = (months[key]!['credit'] ?? 0) + t.credit;
    }

    final sorted = months.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return sorted.map((e) {
      final net = (e.value['credit'] ?? 0) - (e.value['debit'] ?? 0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 70, child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
            Expanded(child: Text('Dr: ₹${(e.value['debit'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.danger))),
            Expanded(child: Text('Cr: ₹${(e.value['credit'] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.success))),
            Text('Net: ₹${net.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: net >= 0 ? AppColors.success : AppColors.danger)),
          ],
        ),
      );
    }).toList();
  }

  Widget _row(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
