import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/widgets.dart';

class AddPaymentScreen extends ConsumerStatefulWidget {
  final int billId;
  final int outstandingPaise;
  final Payment? editPayment;

  const AddPaymentScreen({
    super.key,
    required this.billId,
    required this.outstandingPaise,
    this.editPayment,
  });

  @override
  ConsumerState<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends ConsumerState<AddPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late DateTime _paymentDate;
  late PaymentMode _mode;
  bool _saving = false;
  bool _confirmedExit = false;

  late final String _initAmount;
  late final String _initReference;
  late final String _initNotes;
  late final DateTime _initDate;
  late final PaymentMode _initMode;

  bool get _isEditing => widget.editPayment != null;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _paymentDate = today;
    _mode = PaymentMode.upi;
    if (_isEditing) {
      final p = widget.editPayment!;
      _amountCtrl.text = paiseToEditableString(p.amountPaise);
      _paymentDate = p.paymentDate;
      _mode = PaymentMode.values
          .firstWhere((m) => m.label == p.mode, orElse: () => PaymentMode.cash);
      _referenceCtrl.text = p.referenceNo ?? '';
      _notesCtrl.text = p.notes ?? '';
    }
    _initAmount = _amountCtrl.text;
    _initReference = _referenceCtrl.text;
    _initNotes = _notesCtrl.text;
    _initDate = _paymentDate;
    _initMode = _mode;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _referenceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    // Trimmed: save trims too, so trailing spaces are not real edits.
    return _amountCtrl.text.trim() != _initAmount.trim() ||
        _referenceCtrl.text.trim() != _initReference.trim() ||
        _notesCtrl.text.trim() != _initNotes.trim() ||
        !sameDay(_paymentDate, _initDate) ||
        _mode != _initMode;
  }

  Future<bool> _confirmDiscard() async {
    final discard = await confirmSheet(
      context,
      title: 'Discard changes?',
      message: 'Your edits have not been saved.',
      confirmLabel: 'Discard',
      danger: false,
    );
    return discard;
  }

  void _payFull() {
    AppHaptics.select();
    setState(() {
      _amountCtrl.text = paiseToEditableString(widget.outstandingPaise);
    });
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate.isAfter(today) ? today : _paymentDate,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  String get _referenceHint => switch (_mode) {
        PaymentMode.upi => 'UPI transaction ID',
        PaymentMode.cheque => 'Cheque number',
        PaymentMode.neft || PaymentMode.rtgs => 'UTR number',
        PaymentMode.cash => 'Receipt number',
      };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final bill = await db.getBill(widget.billId);
      if (!mounted) return;
      if (bill != null &&
          DateUtils.dateOnly(_paymentDate)
              .isBefore(DateUtils.dateOnly(bill.billDate))) {
        if (mounted) {
          showAppSnack(
            context,
            'Payment date cannot be before the bill date',
            success: false,
          );
        }
        return;
      }
      final amountPaise = rupeesInputToPaise(_amountCtrl.text);
      // Create and edit share one guard: raising a payment past the
      // outstanding balance always asks first.
      if (amountPaise > widget.outstandingPaise) {
        final over = amountPaise - widget.outstandingPaise;
        final proceed = await confirmSheet(
          context,
          title: 'More than balance',
          message: 'Amount exceeds outstanding by ${formatPaise(over)}. '
              'Record anyway?',
          confirmLabel: 'Record Anyway',
          danger: true,
        );
        if (!proceed) return;
      }
      if (_isEditing) {
        final p = widget.editPayment!;
        await db.updatePayment(Payment(
          id: p.id,
          billId: widget.billId,
          paymentDate: _paymentDate,
          amountPaise: amountPaise,
          mode: _mode.label,
          referenceNo: _referenceCtrl.text.trim().isEmpty
              ? null
              : _referenceCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          createdAt: p.createdAt,
        ));
      } else {
        await db.addPayment(PaymentsCompanion(
          billId: Value(widget.billId),
          paymentDate: Value(_paymentDate),
          amountPaise: Value(amountPaise),
          mode: Value(_mode.label),
          referenceNo: Value<String?>(_referenceCtrl.text.trim().isEmpty
              ? null
              : _referenceCtrl.text.trim()),
          notes: Value<String?>(
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        ));
      }
      if (!mounted) return;
      AppHaptics.confirm();
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not save. Please try again.',
          success: false,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _confirmedExit,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _confirmedExit) return;
        // A save is in flight: swallow back presses until it lands, instead
        // of stacking a Discard sheet that double-pops the route below.
        if (_saving) return;
        if (!_isDirty) {
          final navigator = Navigator.of(context);
          setState(() => _confirmedExit = true);
          // Let the rebuilt PopScope (canPop: true) take effect first.
          await WidgetsBinding.instance.endOfFrame;
          if (!navigator.mounted) return;
          navigator.pop();
          return;
        }
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (!discard || !mounted) return;
        setState(() => _confirmedExit = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!navigator.mounted) return;
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Payment' : 'Add Payment'),
          centerTitle: false,
        ),
        body: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: MeshHeader(height: 180),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(title: 'Outstanding'),
                    const SizedBox(height: 8),
                    _outstandingStrip(context),
                    if (!_isEditing && widget.outstandingPaise > 0) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: InputChip(
                          avatar: const CircleAvatar(
                            radius: 10,
                            child: Icon(Icons.check, size: 14),
                          ),
                          label: const Text('Pay Full',
                              style: TextStyle(fontSize: 13)),
                          onPressed: _payFull,
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Payment'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Required';
                        }
                        if (!isValidRupeesInput(v)) {
                          return 'Enter a valid amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Payment Date *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child:
                            Text(DateFormat('dd/MM/yyyy').format(_paymentDate)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Mode'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in PaymentMode.values)
                          ChoiceChip(
                            label: Text(m.label),
                            selected: _mode == m,
                            onSelected: (_) {
                              AppHaptics.select();
                              setState(() => _mode = m);
                            },
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            labelStyle: const TextStyle(fontSize: 14),
                            materialTapTargetSize: MaterialTapTargetSize.padded,
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Reference'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _referenceCtrl,
                      decoration: InputDecoration(
                        labelText: 'Reference No',
                        hintText: _referenceHint,
                        prefixIcon: const Icon(Icons.tag),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        prefixIcon: Icon(Icons.notes),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? 'Update Payment' : 'Record Payment'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outstandingStrip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppGradients.successSoft,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadow.hero(context),
        border: AppShadow.cardBorder(context),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet,
              size: 22, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedMoney(
                  paise: widget.outstandingPaise,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _isEditing
                      ? 'Editing this payment'
                      : 'Balance due on this bill',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
