import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../utils/text.dart';
import '../../widgets/widgets.dart';

class AddBillScreen extends ConsumerStatefulWidget {
  final Bill? editBill;
  final int? presetDistributorId;

  const AddBillScreen({super.key, this.editBill, this.presetDistributorId});

  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  static final DateFormat _fmt = DateFormat('dd/MM/yyyy');

  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  late DateTime _billDate;
  int? _selectedDistributorId;
  bool _saving = false;
  bool _confirmedExit = false;

  late final String _initNumber;
  late final String _initAmount;
  late final String _initNotes;
  late final DateTime _initDate;
  late final int? _initDistributorId;

  bool get _isEditing => widget.editBill != null;

  @override
  void initState() {
    super.initState();
    _billDate = DateUtils.dateOnly(DateTime.now());
    _selectedDistributorId =
        widget.presetDistributorId ?? widget.editBill?.distributorId;
    if (_isEditing) {
      final b = widget.editBill!;
      _numberCtrl.text = b.billNumber;
      _amountCtrl.text = paiseToEditableString(b.amountPaise);
      _billDate = b.billDate;
      _notesCtrl.text = b.notes ?? '';
    }
    _initNumber = _numberCtrl.text;
    _initAmount = _amountCtrl.text;
    _initNotes = _notesCtrl.text;
    _initDate = _billDate;
    _initDistributorId = _selectedDistributorId;
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty {
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    // Trimmed: save trims too, so trailing spaces are not real edits.
    return _numberCtrl.text.trim() != _initNumber.trim() ||
        _amountCtrl.text.trim() != _initAmount.trim() ||
        _notesCtrl.text.trim() != _initNotes.trim() ||
        !sameDay(_billDate, _initDate) ||
        _selectedDistributorId != _initDistributorId;
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

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _billDate.isAfter(today) ? today : _billDate,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) setState(() => _billDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final distributorId = _selectedDistributorId;
    final number = _numberCtrl.text.trim();
    if (distributorId == null) {
      showAppSnack(context, 'Please select a supplier', success: false);
      return;
    }
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final exists = await db.billNumberExistsForDistributor(
        distributorId,
        number,
        excludeBillId: widget.editBill?.id,
      );
      if (exists) {
        if (!mounted) return;
        showAppSnack(
          context,
          'This bill number already exists for this supplier',
          success: false,
        );
        return;
      }
      final amountPaise = rupeesInputToPaise(_amountCtrl.text);
      if (_isEditing) {
        await db.updateBill(widget.editBill!.copyWith(
          distributorId: distributorId,
          billNumber: number,
          billDate: _billDate,
          amountPaise: amountPaise,
          notes: Value<String?>(
              _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
        ));
      } else {
        await db.addBill(BillsCompanion(
          distributorId: Value(distributorId),
          billNumber: Value(number),
          billDate: Value(_billDate),
          amountPaise: Value(amountPaise),
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
    final distributorsAsync = ref.watch(distributorListStreamProvider);

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
          title: Text(_isEditing ? 'Edit Bill' : 'Add Bill'),
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
                    const SectionHeader(title: 'Supplier'),
                    const SizedBox(height: 8),
                    _supplierField(distributorsAsync),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Details'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _numberCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bill Number *',
                        hintText: 'e.g. INV/2026-27/001',
                        prefixIcon: Icon(Icons.receipt_long),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Bill Date *',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(_fmt.format(_billDate)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(title: 'Amount'),
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
                          : Text(_isEditing ? 'Update Bill' : 'Save Bill'),
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

  Widget _supplierField(AsyncValue<List<Distributor>> async) {
    final loading = async.isLoading;
    final suppliers = async.valueOrNull ?? const <Distributor>[];
    Distributor? selected;
    for (final d in suppliers) {
      if (d.id == _selectedDistributorId) selected = d;
    }
    final current = selected;
    return FormField<int>(
      initialValue: _selectedDistributorId,
      validator: (v) => v == null ? 'Select supplier' : null,
      builder: (state) {
        // Keep the FormField value in sync when the sheet picks a supplier
        // (or a preset/edit id arrives after the field first built).
        if (state.value != _selectedDistributorId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (state.mounted) state.didChange(_selectedDistributorId);
          });
        }
        final cs = Theme.of(context).colorScheme;
        final label = loading
            ? 'Loading suppliers...'
            : (current?.name ?? 'Select supplier');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap:
                    loading ? null : () => _openSupplierSheet(suppliers, state),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.business),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              color: current == null
                                  ? cs.onSurfaceVariant
                                  : cs.onSurface,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  state.errorText!,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openSupplierSheet(
    List<Distributor> suppliers,
    FormFieldState<int> state,
  ) async {
    AppHaptics.select();
    final picked = await showModalBottomSheet<Distributor>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _SupplierSheet(suppliers: suppliers),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDistributorId = picked.id);
      state.didChange(picked.id);
    }
  }
}

class _SupplierSheet extends StatefulWidget {
  const _SupplierSheet({required this.suppliers});

  final List<Distributor> suppliers;

  @override
  State<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends State<_SupplierSheet> {
  final _searchCtrl = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? widget.suppliers
        : widget.suppliers
            .where((d) => d.name.toLowerCase().contains(q))
            .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select supplier',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textColor(context),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search suppliers',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          // Dead-end guidance: with no suppliers at all the
                          // bill cannot be saved from here.
                          widget.suppliers.isEmpty
                              ? 'No suppliers yet — add one from the Suppliers tab first'
                              : 'No suppliers match your search',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (_, i) {
                        final d = matches[i];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => Navigator.of(context).pop(d),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  minHeight: 48, minWidth: 48),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppGradients.brand,
                                      ),
                                      child: Text(
                                        initialLetter(d.name),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        d.name,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
