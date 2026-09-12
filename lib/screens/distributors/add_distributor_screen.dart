import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/widgets.dart';

class AddDistributorScreen extends ConsumerStatefulWidget {
  const AddDistributorScreen({super.key, this.edit});

  final Distributor? edit;

  @override
  ConsumerState<AddDistributorScreen> createState() =>
      _AddDistributorScreenState();
}

class _AddDistributorScreenState extends ConsumerState<AddDistributorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _phoneCtrl;
  bool _saving = false;
  bool _saved = false;
  bool _confirmedExit = false;

  bool get _isEditing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final d = widget.edit;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _companyCtrl = TextEditingController(text: d?.company ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _nameCtrl.addListener(_onChanged);
    _companyCtrl.addListener(_onChanged);
    _phoneCtrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _dirty {
    final d = widget.edit;
    return _nameCtrl.text.trim() != (d?.name ?? '') ||
        _companyCtrl.text.trim() != (d?.company ?? '') ||
        _phoneCtrl.text.trim() != (d?.phone ?? '');
  }

  String? _emptyToNull(String value) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      final name = _nameCtrl.text.trim();
      final company = _emptyToNull(_companyCtrl.text);
      final phone = _emptyToNull(_phoneCtrl.text);
      if (_isEditing) {
        await db.updateDistributor(
          widget.edit!.copyWith(
            name: name,
            company: Value(company),
            phone: Value(phone),
          ),
        );
      } else {
        await db.addDistributor(
          DistributorsCompanion.insert(
            name: name,
            company: Value(company),
            phone: Value(phone),
          ),
        );
      }
      _saved = true;
      AppHaptics.confirm();
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, 'Could not save supplier. Please try again.',
            success: false);
      }
    }
  }

  Future<void> _confirmDiscard(bool didPop) async {
    if (didPop || _confirmedExit || _saving || _saved || !_dirty) return;
    final discard = await confirmSheet(
      context,
      title: 'Discard changes?',
      message: 'You have unsaved changes. Leave without saving?',
      confirmLabel: 'Discard',
      danger: false,
    );
    if (!discard || !mounted) return;
    setState(() => _confirmedExit = true);
    // Let the rebuilt PopScope (canPop: true) take effect first.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _confirmedExit || (!_saving && !_dirty),
      onPopInvokedWithResult: (didPop, _) => _confirmDiscard(didPop),
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: Text(
            _isEditing ? 'Edit Supplier' : 'Add Supplier',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        body: Stack(
          children: [
            const MeshHeader(height: 170),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isEditing ? 'Edit supplier' : 'New supplier',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textColor(context),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Name, company and contact stay on this device.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.subtitleColor(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(title: 'Supplier Details'),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Supplier Name *',
                                hintText: 'e.g. Sterling Pharma',
                                prefixIcon: Icon(Icons.business),
                              ),
                              style: const TextStyle(fontSize: 16),
                              textCapitalization: TextCapitalization.words,
                              validator: (v) => v == null || v.trim().isEmpty
                                  ? 'Enter supplier name'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _companyCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Company',
                                hintText: 'e.g. Alkem Labs',
                                prefixIcon: Icon(Icons.corporate_fare),
                              ),
                              style: const TextStyle(fontSize: 16),
                              textCapitalization: TextCapitalization.words,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(title: 'Contact'),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            hintText: '9876543210',
                            prefixIcon: Icon(Icons.phone),
                          ),
                          style: const TextStyle(fontSize: 16),
                          keyboardType: TextInputType.phone,
                          autocorrect: false,
                          enableSuggestions: false,
                          validator: (v) {
                            final digits =
                                (v ?? '').replaceAll(RegExp(r'\D'), '');
                            if (digits.isEmpty) return null;
                            return digits.length >= 10 && digits.length <= 15
                                ? null
                                : 'Enter valid phone';
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? 'Update Supplier' : 'Save Supplier'),
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
}
