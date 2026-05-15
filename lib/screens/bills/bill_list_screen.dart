import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import 'add_bill_screen.dart';
import 'bill_detail_screen.dart';
import '../scanner/bill_scanner.dart';
import 'package:image_picker/image_picker.dart';



final distributorsMapProvider = FutureProvider<Map<int, Distributor>>((ref) async {
  final db = ref.watch(databaseProvider);
  final list = await db.getAllDistributors();
  return {for (final d in list) d.id: d};
});

class BillListScreen extends ConsumerStatefulWidget {
  const BillListScreen({super.key});

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';
  String _sortBy = 'Date';
  DateTime? _dateFrom;
  DateTime? _dateTo;
  Map<int, double> _paidMap = {};

  @override
  void initState() {
    super.initState();
    _loadPaidMap();
  }

  Future<void> _loadPaidMap() async {
    final db = ref.read(databaseProvider);
    final allBills = await db.getAllBills();
    if (allBills.isEmpty) return;
    final map = await db.getTotalPaidForBills(allBills.map((b) => b.id).toList());
    if (mounted) setState(() => _paidMap = map);
  }

  Future<void> _scanBill(BuildContext context) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Bill'),
        content: const Text('Choose image source:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.camera), child: const Text('Camera')),
          TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.gallery), child: const Text('Gallery')),
        ],
      ),
    );
    if (source == null || !context.mounted) return;

    BillScanResult? result;
    if (source == ImageSource.camera) {
      result = await BillScanner.scanFromCamera(context);
    } else {
      result = await BillScanner.scanFromGallery(context);
    }

    if (result == null || !context.mounted) return;

    final confirmed = await Navigator.push<BillScanResult>(
      context,
      MaterialPageRoute(builder: (_) => ScanPreviewScreen(result: result!)),
    );

    if (confirmed != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddBillScreen(
            prefillNumber: confirmed.billNumber,
            prefillAmount: confirmed.amount,
            prefillDate: confirmed.billDate,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(allBillsProvider);
    final distMapAsync = ref.watch(distributorsMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Bill',
            onPressed: () => _scanBill(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBillScreen()));
          if (result == true) {
            ref.invalidate(allBillsProvider);
            await _loadPaidMap();
          }
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildDateFilter(),
          _buildFilterChips(),
          _buildSortBar(),
          Expanded(
            child: billsAsync.when(
              data: (bills) {
                final distMap = distMapAsync.valueOrNull ?? {};
                final filtered = _filterBills(bills, distMap);
                if (filtered.isEmpty) return _emptyState(context);
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(allBillsProvider);
                    await _loadPaidMap();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 80),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _billCard(context, filtered[i], distMap),
                  ),
                );
              },
              error: (e, _) => Center(child: Text('$e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Search bills by number or distributor...',
          prefixIcon: const Icon(Icons.search, size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDateFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateFrom ?? DateTime.now().subtract(const Duration(days: 30)),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateFrom = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  labelText: _dateFrom != null ? '${_dateFrom!.day}/${_dateFrom!.month}/${_dateFrom!.year}' : 'From',
                  prefixIcon: const Icon(Icons.date_range, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('—', style: TextStyle(fontSize: 18)),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dateTo ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _dateTo = picked);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  labelText: _dateTo != null ? '${_dateTo!.day}/${_dateTo!.month}/${_dateTo!.year}' : 'To',
                  prefixIcon: const Icon(Icons.date_range, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          if (_dateFrom != null || _dateTo != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => setState(() { _dateFrom = null; _dateTo = null; }),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Unpaid', 'Partial', 'Paid'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final selected = _statusFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(f, style: TextStyle(fontSize: 13, color: selected ? Colors.white : null)),
              selected: selected,
              selectedColor: f == 'Unpaid' ? AppColors.danger : f == 'Partial' ? AppColors.warning : f == 'Paid' ? AppColors.success : AppColors.primary,
              checkmarkColor: Colors.white,
              backgroundColor: Colors.transparent,
              side: BorderSide(color: AppColors.divider),
              onSelected: (_) => setState(() => _statusFilter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Bill> _filterBills(List<Bill> bills, Map<int, Distributor> distMap) {
    var filtered = bills;
    if (_statusFilter != 'All') {
      filtered = filtered.where((b) {
        final paid = _paidMap[b.id] ?? 0.0;
        if (_statusFilter == 'Unpaid') return paid <= 0;
        if (_statusFilter == 'Partial') return paid > 0 && paid < b.amount;
        if (_statusFilter == 'Paid') return paid >= b.amount;
        return true;
      }).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((b) {
        final name = distMap[b.distributorId]?.name.toLowerCase() ?? '';
        return b.billNumber.toLowerCase().contains(_searchQuery) || name.contains(_searchQuery);
      }).toList();
    }

    if (_dateFrom != null) {
      filtered = filtered.where((b) => b.billDate.isAfter(_dateFrom!.subtract(const Duration(days: 1)))).toList();
    }
    if (_dateTo != null) {
      filtered = filtered.where((b) => b.billDate.isBefore(_dateTo!.add(const Duration(days: 1)))).toList();
    }

    switch (_sortBy) {
      case 'Amount':
        filtered.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case 'Status':
        filtered.sort((a, b) {
          final pa = _paidMap[a.id] ?? 0.0;
          final pb = _paidMap[b.id] ?? 0.0;
          final sa = pa <= 0 ? 0 : pa < a.amount ? 1 : 2;
          final sb = pb <= 0 ? 0 : pb < b.amount ? 1 : 2;
          return sa.compareTo(sb);
        });
        break;
      default:
        filtered.sort((a, b) => b.billDate.compareTo(a.billDate));
    }
    return filtered;
  }

  Widget _buildSortBar() {
    final sorts = ['Date', 'Amount', 'Status'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          ...sorts.map((s) {
            final selected = _sortBy == s;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(s, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
                selected: selected,
                selectedColor: AppColors.info,
                onSelected: (_) => setState(() => _sortBy = s),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _billCard(BuildContext context, Bill bill, Map<int, Distributor> distMap) {
    final paid = _paidMap[bill.id] ?? 0.0;
    final isOverdue = paid <= 0 && DateTime.now().difference(bill.billDate).inDays > 30;
    final statusColor = isOverdue ? AppColors.danger : _getStatusColor(bill);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => BillDetailScreen(billId: bill.id)));
          ref.invalidate(allBillsProvider);
          _loadPaidMap();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOverdue ? AppColors.danger.withValues(alpha: 0.1) : AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isOverdue ? Icons.warning_amber_rounded : Icons.receipt,
                    color: isOverdue ? AppColors.danger : AppColors.info, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('#${bill.billNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        if (isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                            child: const Text('OVERDUE', style: TextStyle(fontSize: 9, color: AppColors.danger, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    if (distMap[bill.distributorId] != null)
                      Text(distMap[bill.distributorId]!.name, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('${bill.billDate.day}/${bill.billDate.month}/${bill.billDate.year}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${bill.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(_statusText(bill), style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(Bill bill) {
    final paid = _paidMap[bill.id] ?? 0.0;
    if (paid <= 0) return AppColors.danger;
    if (paid < bill.amount) return AppColors.warning;
    return AppColors.success;
  }

  String _statusText(Bill bill) {
    final paid = _paidMap[bill.id] ?? 0.0;
    if (paid <= 0) return 'Unpaid';
    if (paid < bill.amount) return 'Partial';
    return 'Paid';
  }

  Widget _emptyState(BuildContext context) {
    final hasFilter = _statusFilter != 'All' || _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(hasFilter ? Icons.search_off : Icons.receipt_long_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(hasFilter ? 'No bills match your search' : 'No bills yet', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          if (!hasFilter) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBillScreen()));
                if (result == true) { ref.invalidate(allBillsProvider); _loadPaidMap(); }
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Bill'),
            ),
          ],
        ],
      ),
    );
  }
}
