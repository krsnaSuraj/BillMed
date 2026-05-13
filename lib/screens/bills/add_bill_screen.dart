import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/database.dart';
import '../../providers/database_provider.dart';

class AddBillScreen extends ConsumerStatefulWidget {
  final int? distributorId;
  final String? prefillNumber;
  final double? prefillAmount;
  final DateTime? prefillDate;
  final String? prefillDistributor;
  final Bill? bill;

  const AddBillScreen({
    super.key,
    this.distributorId,
    this.prefillNumber,
    this.prefillAmount,
    this.prefillDate,
    this.prefillDistributor,
    this.bill,
  });

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billNoCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late DateTime _billDate;
  int? _selectedDistributorId;
  bool _saving = false;
  bool get _isEditing => widget.bill != null;

  @override
  void initState() {
    super.initState();
    _selectedDistributorId = widget.distributorId;
    _billDate = widget.prefillDate ?? DateTime.now();
    if (widget.prefillNumber != null) _billNoCtrl.text = widget.prefillNumber!;
    if (widget.prefillAmount != null) _amountCtrl.text = widget.prefillAmount!.toStringAsFixed(0);
    if (widget.prefillDistributor != null) {}

    if (_isEditing) {
      _billNoCtrl.text = widget.bill!.billNumber;
      _amountCtrl.text = widget.bill!.amount.toStringAsFixed(0);
      _billDate = widget.bill!.billDate;
      _selectedDistributorId = widget.bill!.distributorId;
      _notesCtrl.text = widget.bill!.notes ?? '';
    }
  }

  @override
  void dispose() {
    _billNoCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final distributorsAsync = ref.watch(distributorListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Bill' : 'Add Bill')),
      body: distributorsAsync.when(
        data: (dists) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.distributorId == null) ...[
                  DropdownButtonFormField<int>(
                    value: _selectedDistributorId,
                    decoration: const InputDecoration(labelText: 'Supplier *', prefixIcon: Icon(Icons.business)),
                    items: dists.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                    onChanged: (v) => setState(() => _selectedDistributorId = v),
                    validator: (v) => v == null ? 'Select supplier' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _billNoCtrl,
                  decoration: const InputDecoration(labelText: 'Bill Number *', hintText: 'e.g. INV/2026-27/001', prefixIcon: Icon(Icons.receipt)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Bill Date *', prefixIcon: Icon(Icons.calendar_today)),
                    child: Text('${_billDate.day}/${_billDate.month}/${_billDate.year}'),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v) == null) return 'Invalid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes)),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Bill'),
                ),
              ],
            ),
          ),
        ),
        error: (e, _) => Center(child: Text('$e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _billDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      if (_isEditing) {
        await db.updateBill(widget.bill!.copyWith(
          distributorId: _selectedDistributorId ?? widget.distributorId!,
          billNumber: _billNoCtrl.text.trim(),
          billDate: _billDate,
          amount: double.parse(_amountCtrl.text.trim()),
          notes: Value<String?>(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        ));
      } else {
        await db.addBill(BillsCompanion(
          distributorId: Value(_selectedDistributorId ?? widget.distributorId!),
          billNumber: Value(_billNoCtrl.text.trim()),
          billDate: Value(_billDate),
          amount: Value(double.parse(_amountCtrl.text.trim())),
          notes: Value<String?>(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
