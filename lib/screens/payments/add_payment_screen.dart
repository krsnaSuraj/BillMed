import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../models/enums.dart';
import '../../theme/app_theme.dart';

class AddPaymentScreen extends ConsumerStatefulWidget {
  final int billId;
  const AddPaymentScreen({super.key, required this.billId});

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  PaymentMode _selectedMode = PaymentMode.cash;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final amt = double.tryParse(v);
                  if (amt == null || amt <= 0) return 'Enter valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Payment Date *', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text('${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}'),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PaymentMode>(
                value: _selectedMode,
                decoration: const InputDecoration(labelText: 'Payment Mode *', prefixIcon: Icon(Icons.payment)),
                items: PaymentMode.values.map((m) {
                  IconData icon;
                  switch (m) {
                    case PaymentMode.cash:
                      icon = Icons.money;
                      break;
                    case PaymentMode.upi:
                      icon = Icons.phone_android;
                      break;
                    case PaymentMode.cheque:
                      icon = Icons.receipt;
                      break;
                    case PaymentMode.neft:
                    case PaymentMode.rtgs:
                      icon = Icons.account_balance;
                      break;
                  }
                  return DropdownMenuItem(
                    value: m,
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Text(m.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedMode = v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceCtrl,
                decoration: InputDecoration(
                  labelText: '${_selectedMode.label} Reference',
                  hintText: _selectedMode == PaymentMode.upi
                      ? 'UPI transaction ID'
                      : _selectedMode == PaymentMode.cheque
                          ? 'Cheque number'
                          : 'Transaction reference',
                  prefixIcon: const Icon(Icons.tag),
                ),
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
                    : const Text('Record Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _paymentDate, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(databaseProvider).addPayment(PaymentsCompanion(
        billId: Value(widget.billId),
        paymentDate: Value(_paymentDate),
        amount: Value(double.parse(_amountCtrl.text.trim())),
        mode: Value(_selectedMode.label),
        referenceNo: Value(_referenceCtrl.text.trim().isEmpty ? null : _referenceCtrl.text.trim()),
        notes: Value(_notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
      ));
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
