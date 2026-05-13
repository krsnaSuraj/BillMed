import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import '../../database/database.dart';
import '../../providers/database_provider.dart';

class AddDistributorScreen extends ConsumerStatefulWidget {
  final Distributor? distributor;
  const AddDistributorScreen({super.key, this.distributor});

  @override
  ConsumerState<AddDistributorScreen> createState() => _AddDistributorScreenState();
}

class _AddDistributorScreenState extends ConsumerState<AddDistributorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  bool get _isEditing => widget.distributor != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.distributor!.name;
      _companyCtrl.text = widget.distributor!.company ?? '';
      _phoneCtrl.text = widget.distributor!.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _companyCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final db = ref.read(databaseProvider);
      if (_isEditing) {
        await db.updateDistributor(widget.distributor!.copyWith(
          name: _nameCtrl.text.trim(),
          company: Value<String?>(_companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim()),
          phone: Value<String?>(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
        ));
      } else {
        await db.addDistributor(DistributorsCompanion(
          name: Value(_nameCtrl.text.trim()),
          company: Value<String?>(_companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim()),
          phone: Value<String?>(_phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim()),
        ));
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Supplier' : 'Add Supplier')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Supplier Name *', hintText: 'e.g. Sterling Pharma', prefixIcon: Icon(Icons.business)),
                style: const TextStyle(fontSize: 16),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _companyCtrl,
                decoration: const InputDecoration(labelText: 'Company', hintText: 'e.g. Alkem Labs', prefixIcon: Icon(Icons.corporate_fare)),
                style: const TextStyle(fontSize: 16),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone', hintText: '9876543210', prefixIcon: Icon(Icons.phone)),
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.phone,
                maxLength: 10,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEditing ? 'Update Supplier' : 'Save Supplier'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
