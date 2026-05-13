import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/bank_statement_service.dart';

class ManualEntryScreen extends ConsumerStatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  final _txns = <_TxnRow>[_TxnRow()];
  bool _saving = false;

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
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Text('${i + 1}.', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 32,
                    child: TextField(
                      controller: t.dateCtrl,
                      decoration: const InputDecoration(isDense: true, hintText: 'Date', hintStyle: TextStyle(fontSize: 12), border: InputBorder.none),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: TextField(
                      controller: t.descCtrl,
                      decoration: const InputDecoration(isDense: true, hintText: 'Description', hintStyle: TextStyle(fontSize: 12), border: InputBorder.none),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 70,
              child: TextField(
                controller: t.amountCtrl,
                decoration: const InputDecoration(isDense: true, hintText: '₹', hintStyle: TextStyle(fontSize: 12), border: InputBorder.none),
                style: const TextStyle(fontSize: 12),
                keyboardType: TextInputType.number,
              ),
            ),
            if (_txns.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.danger),
                onPressed: () {
                  t.dispose();
                  setState(() => _txns.removeAt(i));
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final valid = <ParsedTransaction>[];
    for (final t in _txns) {
      if (t.amountCtrl.text.trim().isEmpty) continue;
      final amt = double.tryParse(t.amountCtrl.text.trim());
      if (amt == null || amt <= 0) continue;
      DateTime? date;
      try {
        final parts = t.dateCtrl.text.trim().split(RegExp(r'[\/\-]'));
        if (parts.length == 3) {
          date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
      valid.add(ParsedTransaction(
        txnDate: date ?? DateTime.now(),
        description: t.descCtrl.text.trim().isEmpty ? 'Manual entry' : t.descCtrl.text.trim(),
        debit: amt,
        credit: 0,
        balance: 0,
      ));
    }

    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No valid entries')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${valid.length} transaction(s) saved')));
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
  final amountCtrl = TextEditingController();
  void dispose() { dateCtrl.dispose(); descCtrl.dispose(); amountCtrl.dispose(); }
}
