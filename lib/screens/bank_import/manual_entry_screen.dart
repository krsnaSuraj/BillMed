import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/bank_statement_service.dart';
import 'bank_view_screen.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _txns = <_TxnRow>[_TxnRow()];
  bool _saving = false;

  @override
  void dispose() {
    for (final t in _txns) { t.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Entry')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _txns.add(_TxnRow())),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                const Text('Enter transactions manually', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${_txns.length} row(s)', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SizedBox(width: 28),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: const [
                      Expanded(child: Text('Date', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                      SizedBox(width: 4),
                      Expanded(flex: 2, child: Text('Description', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
                SizedBox(width: 60, child: Text('Debit', style: TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                SizedBox(width: 60, child: Text('Credit', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                const SizedBox(width: 36),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _txns.length,
              itemBuilder: (ctx, i) => _buildRow(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save ${_txns.length} Transaction(s)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(int i) {
    final t = _txns[i];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Text('${i + 1}.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 4),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 28,
                    child: TextField(
                      controller: t.dateCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'DD/MM/YYYY',
                        hintStyle: TextStyle(fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.datetime,
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    child: TextField(
                      controller: t.descCtrl,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'Description',
                        hintStyle: TextStyle(fontSize: 11),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: t.debitCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 11),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                ),
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              width: 60,
              child: TextField(
                controller: t.creditCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(fontSize: 11),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                ),
                style: const TextStyle(fontSize: 12, color: AppColors.success),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
              ),
            ),
            if (_txns.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.danger),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  t.dispose();
                  setState(() => _txns.removeAt(i));
                },
              )
            else
              const SizedBox(width: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final valid = <ParsedTransaction>[];
    for (final t in _txns) {
      final debit = double.tryParse(t.debitCtrl.text.trim()) ?? 0.0;
      final credit = double.tryParse(t.creditCtrl.text.trim()) ?? 0.0;
      if (debit <= 0 && credit <= 0) continue;

      DateTime? date;
      try {
        final parts = t.dateCtrl.text.trim().split(RegExp(r'[\/\-]'));
        if (parts.length == 3) {
          var y = int.parse(parts[2]);
          if (y < 100) y += 2000;
          date = DateTime(y, int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}

      valid.add(ParsedTransaction(
        txnDate: date ?? DateTime.now(),
        description: t.descCtrl.text.trim().isEmpty ? 'Manual entry' : t.descCtrl.text.trim(),
        debit: debit,
        credit: credit,
        balance: 0,
      ));
    }

    if (valid.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid entries. Enter at least one debit or credit amount.')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      for (final t in valid) {
        await db.addBankTransaction(BankTransactionsCompanion(
          txnDate: Value(t.txnDate),
          description: Value(t.description),
          debit: Value(t.debit),
          credit: Value(t.credit),
          balance: Value(t.balance),
          sourceFile: const Value('manual'),
        ));
      }
      if (mounted) {
        ref.invalidate(bankTxnsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${valid.length} transaction(s) saved')),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TxnRow {
  final dateCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final debitCtrl = TextEditingController();
  final creditCtrl = TextEditingController();

  void dispose() {
    dateCtrl.dispose();
    descCtrl.dispose();
    debitCtrl.dispose();
    creditCtrl.dispose();
  }
}
