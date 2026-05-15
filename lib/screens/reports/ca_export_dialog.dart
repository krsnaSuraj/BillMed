import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Options the user selects before generating the CA report PDF.
class CaReportConfig {
  String businessName;
  String ownerName;
  String gstin;
  bool inclPurchaseSummary;
  bool inclBankCashFlow;
  bool inclGstEstimate;
  bool inclMonthlyBreakdown;
  bool inclSupplierTable;
  bool inclTransactionDetails;

  CaReportConfig({
    this.businessName = '',
    this.ownerName = '',
    this.gstin = '',
    this.inclPurchaseSummary = true,
    this.inclBankCashFlow = true,
    this.inclGstEstimate = true,
    this.inclMonthlyBreakdown = true,
    this.inclSupplierTable = true,
    this.inclTransactionDetails = true,
  });
}

class CaExportDialog extends StatefulWidget {
  final int fyYear;
  const CaExportDialog({super.key, required this.fyYear});

  @override
  State<CaExportDialog> createState() => _CaExportDialogState();
}

class _CaExportDialogState extends State<CaExportDialog> {
  final _cfg = CaReportConfig();
  final _bizCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();

  @override
  void dispose() {
    _bizCtrl.dispose();
    _ownerCtrl.dispose();
    _gstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fy = widget.fyYear;
    final fyLabel = 'FY $fy-${(fy + 1).toString().substring(2)}';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Icon(Icons.picture_as_pdf, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Export CA Report PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(fyLabel, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Info
                  const Text('Business Details (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _bizCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Business / Shop Name',
                      hintText: 'e.g. Sharma Medical Store',
                      prefixIcon: Icon(Icons.store, size: 18),
                      isDense: true,
                    ),
                    onChanged: (v) => _cfg.businessName = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ownerCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Owner / Proprietor Name',
                      hintText: 'e.g. Rajesh Sharma',
                      prefixIcon: Icon(Icons.person, size: 18),
                      isDense: true,
                    ),
                    onChanged: (v) => _cfg.ownerName = v.trim(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _gstCtrl,
                    decoration: const InputDecoration(
                      labelText: 'GSTIN (optional)',
                      hintText: 'e.g. 22AAAAA0000A1Z5',
                      prefixIcon: Icon(Icons.receipt, size: 18),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (v) => _cfg.gstin = v.trim().toUpperCase(),
                  ),

                  const SizedBox(height: 18),
                  const Text('Sections to Include', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.accent)),
                  const SizedBox(height: 4),

                  _toggle(
                    icon: Icons.receipt_long,
                    color: AppColors.danger,
                    title: 'Purchase & Payables Summary',
                    subtitle: 'Total purchases, paid, outstanding, payment rate',
                    value: _cfg.inclPurchaseSummary,
                    onChanged: (v) => setState(() => _cfg.inclPurchaseSummary = v),
                  ),
                  _toggle(
                    icon: Icons.account_balance,
                    color: AppColors.info,
                    title: 'Bank Cash Flow Summary',
                    subtitle: 'Credits, debits, net, closing balance',
                    value: _cfg.inclBankCashFlow,
                    onChanged: (v) => setState(() => _cfg.inclBankCashFlow = v),
                  ),
                  _toggle(
                    icon: Icons.calculate,
                    color: AppColors.accent,
                    title: 'GST Input Tax Estimate',
                    subtitle: 'Approx. 5% estimate on purchases',
                    value: _cfg.inclGstEstimate,
                    onChanged: (v) => setState(() => _cfg.inclGstEstimate = v),
                  ),
                  _toggle(
                    icon: Icons.bar_chart,
                    color: AppColors.success,
                    title: 'Monthly Bank Breakdown',
                    subtitle: 'Month-wise credit / debit / net table',
                    value: _cfg.inclMonthlyBreakdown,
                    onChanged: (v) => setState(() => _cfg.inclMonthlyBreakdown = v),
                  ),
                  _toggle(
                    icon: Icons.people,
                    color: AppColors.warning,
                    title: 'Supplier-wise Purchase Table',
                    subtitle: 'Bill-by-bill: supplier, amount, paid, status',
                    value: _cfg.inclSupplierTable,
                    onChanged: (v) => setState(() => _cfg.inclSupplierTable = v),
                  ),
                  _toggle(
                    icon: Icons.list_alt,
                    color: AppColors.textSecondary,
                    title: 'Full Bank Transaction Ledger',
                    subtitle: 'Every bank transaction with date, debit, credit, balance',
                    value: _cfg.inclTransactionDetails,
                    onChanged: (v) => setState(() => _cfg.inclTransactionDetails = v),
                  ),

                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.info),
                      SizedBox(width: 6),
                      Expanded(child: Text('PDF uses clean fonts — all text will be clearly readable.',
                          style: TextStyle(fontSize: 11, color: AppColors.info))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Generate PDF'),
                onPressed: () {
                  _cfg.businessName = _bizCtrl.text.trim();
                  _cfg.ownerName = _ownerCtrl.text.trim();
                  _cfg.gstin = _gstCtrl.text.trim().toUpperCase();
                  Navigator.pop(context, _cfg);
                },
              )),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: SwitchListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        secondary: Icon(icon, color: value ? color : Colors.grey, size: 20),
        title: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
            color: value ? null : Colors.grey)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value,
        activeThumbColor: color,
        onChanged: onChanged,
      ),
    );
  }
}
