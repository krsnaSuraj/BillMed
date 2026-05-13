import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';

class AddBillScreen extends ConsumerStatefulWidget {
  final int? distributorId;
  const AddBillScreen({super.key, this.distributorId});

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _billNoCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _billDate = DateTime.now();
  int? _selectedDistributorId;
  bool _saving = false;

  List<Distributor> _distributors = [];

  @override
  void initState() {
    super.initState();
    _selectedDistributorId = widget.distributorId;
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
      appBar: AppBar(title: const Text('Add Bill')),
      body: distributorsAsync.when(
        data: (dists) {
          _distributors = dists;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  if (widget.distributorId == null) ...[
                    DropdownButtonFormField<int>(
                      value: _selectedDistributorId,
                      decoration: const InputDecoration(
                        labelText: 'Distributor *',
                        prefixIcon: Icon(Icons.business),
                      ),
                      style: const TextStyle(fontSize: 18),
                      items: dists.map((d) {
                        return DropdownMenuItem(
                          value: d.id,
                          child: Text(d.name, style: const TextStyle(fontSize: 18)),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setState(() => _selectedDistributorId = v),
                      validator: (v) => v == null ? 'Select distributor' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _billNoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bill Number *',
                      hintText: 'e.g. ST-2026-1245',
                      prefixIcon: Icon(Icons.receipt),
                    ),
                    style: const TextStyle(fontSize: 18),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Bill Date *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        '${_billDate.day}/${_billDate.month}/${_billDate.year}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹) *',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    style: const TextStyle(fontSize: 18),
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
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    style: const TextStyle(fontSize: 18),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Bill'),
                  ),
                ],
              ),
            ),
          );
        },
        error: (e, _) => Center(child: Text('Error: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      await db.addBill(BillsCompanion(
        distributorId: Value(_selectedDistributorId ?? widget.distributorId!),
        billNumber: Value(_billNoCtrl.text.trim()),
        billDate: Value(_billDate),
        amount: Value(double.parse(_amountCtrl.text.trim())),
        notes: Value(_notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim()),
      ));
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

