import 'dart:async';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../models/bill_status.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../utils/text.dart';
import '../../widgets/widgets.dart';
import 'add_bill_screen.dart';
import 'bill_detail_screen.dart';

enum _ChipFilter { all, unpaid, partial, paid, overdue }

/// Bill ordering. Date orders keep month-group headers; amount order shows a
/// flat list (month headers would mislead once rows leave date order).
enum _SortOrder { newest, oldest, amountDesc }

class BillListScreen extends ConsumerStatefulWidget {
  final bool initialOverdueOnly;

  const BillListScreen({
    super.key,
    this.initialOverdueOnly = false,
  });

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> {
  static final DateFormat _monthFmt = DateFormat('MMMM yyyy');
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  late _ChipFilter _chip;
  int? _supplierId;
  var _sort = _SortOrder.newest;

  @override
  void initState() {
    super.initState();
    _chip = widget.initialOverdueOnly ? _ChipFilter.overdue : _ChipFilter.all;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    final q = v.trim().toLowerCase();
    if (q.isEmpty) {
      // Clear path (AppSearchBar clear button calls onChanged('') AND
      // onClear): apply immediately so no redundant delayed setState fires.
      if (_query.isNotEmpty && mounted) setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = q);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  void _clearFilters() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _chip = _ChipFilter.all;
      _supplierId = null;
      _sort = _SortOrder.newest;
    });
  }

  bool get _hasExtraFilters =>
      _supplierId != null || _sort != _SortOrder.newest;

  List<BillPaid> _applyQuery(List<BillPaid> bills, Map<int, String> names) {
    if (_query.isEmpty) return bills;
    return bills.where((b) {
      final name = (names[b.bill.distributorId] ?? '').toLowerCase();
      return b.bill.billNumber.toLowerCase().contains(_query) ||
          name.contains(_query);
    }).toList();
  }

  Map<_ChipFilter, int> _counts(List<BillPaid> searched) => {
        _ChipFilter.all: searched.length,
        _ChipFilter.unpaid:
            searched.where((b) => b.status == BillStatus.unpaid).length,
        _ChipFilter.partial:
            searched.where((b) => b.status == BillStatus.partial).length,
        _ChipFilter.paid: searched.where((b) => b.status.isSettled).length,
        _ChipFilter.overdue: searched.where((b) => b.isOverdue).length,
      };

  List<BillPaid> _applyChips(List<BillPaid> searched) {
    return switch (_chip) {
      _ChipFilter.all => searched,
      _ChipFilter.unpaid =>
        searched.where((b) => b.status == BillStatus.unpaid).toList(),
      _ChipFilter.partial =>
        searched.where((b) => b.status == BillStatus.partial).toList(),
      _ChipFilter.paid => searched.where((b) => b.status.isSettled).toList(),
      _ChipFilter.overdue => searched.where((b) => b.isOverdue).toList(),
    };
  }

  List<BillPaid> _applySupplier(List<BillPaid> bills) {
    final id = _supplierId;
    if (id == null) return bills;
    return bills.where((b) => b.bill.distributorId == id).toList();
  }

  List<BillPaid> _applySort(List<BillPaid> bills) {
    switch (_sort) {
      case _SortOrder.newest:
        return bills;
      case _SortOrder.oldest:
        return bills.reversed.toList();
      case _SortOrder.amountDesc:
        return [...bills]..sort((a, b) {
            final byAmount = b.bill.amountPaise.compareTo(a.bill.amountPaise);
            // Newest id first on ties: deterministic across rebuilds.
            return byAmount != 0 ? byAmount : b.bill.id.compareTo(a.bill.id);
          });
    }
  }

  Future<void> _openAdd() async {
    await Navigator.push(
      context,
      AppMotion.pageRoute(const AddBillScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsWithPaidProvider);
    final namesAsync = ref.watch(distributorListStreamProvider);
    final names = {
      for (final d in namesAsync.valueOrNull ?? const <Distributor>[])
        d.id: d.name
    };

    final allBills = billsAsync.valueOrNull ?? const <BillPaid>[];
    final searched = _applyQuery(allBills, names);
    final scoped = _applySupplier(searched);
    final counts = _counts(scoped);
    final filtered = _applySort(_applyChips(scoped));
    final headerPending = allBills.fold<int>(0, (s, b) => s + b.remainingPaise);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'bills-add',
        onPressed: _openAdd,
        backgroundColor: Colors.transparent,
        elevation: 4,
        tooltip: 'Add bill',
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.brand,
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MeshHeader(height: 260),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bills',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textColor(context),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        billsAsync.valueOrNull == null && !billsAsync.hasError
                            // Cold load: never flash '0 bills · ₹0 pending'.
                            ? 'Loading bills…'
                            : '${plural(allBills.length, 'bill')} · '
                                '${formatPaise(headerPending)} pending',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.subtitleColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: AppSearchBar(
                    controller: _searchCtrl,
                    hint: 'Search bill no. or supplier',
                    onChanged: _onSearchChanged,
                    onClear: _clearSearch,
                  ),
                ),
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      for (final f in _ChipFilter.values)
                        _filterChip(f, counts[f] ?? 0),
                      _supplierPill(names),
                      _sortPill(),
                      if (_hasExtraFilters) _resetPill(),
                    ],
                  ),
                ),
                Expanded(
                  child: billsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: SkeletonList(count: 8),
                    ),
                    error: (_, __) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 40, color: AppColors.danger),
                            const SizedBox(height: 12),
                            const Text(
                              'Could not load bills.',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () {
                                ref.invalidate(billsWithPaidProvider);
                                ref.invalidate(distributorListStreamProvider);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (_) {
                      if (filtered.isEmpty) return _emptyState(allBills);
                      final items = _groupedItems(filtered);
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 88),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final item = items[i];
                          if (item is _MonthLabel) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                              child: Text(
                                _monthFmt.format(item.month),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                  color: AppColors.subtitleColor(context),
                                ),
                              ),
                            );
                          }
                          final entry = item as _BillEntry;
                          return _BillTile(
                            bp: entry.bp,
                            index: entry.index,
                            supplierName: names[entry.bp.bill.distributorId],
                            onTap: () => Navigator.push(
                              context,
                              AppMotion.pageRoute(
                                BillDetailScreen(billId: entry.bp.bill.id),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Flat list: month header rows interleaved with bill entries.
  /// Input is already date-DESC from the watched query; keep that order.
  List<Object> _groupedItems(List<BillPaid> filtered) {
    // Amount order is global, not per-month — flat rows, no headers.
    if (_sort == _SortOrder.amountDesc) {
      return [
        for (var i = 0; i < filtered.length; i++) _BillEntry(filtered[i], i)
      ];
    }
    final out = <Object>[];
    var lastKey = '';
    for (var i = 0; i < filtered.length; i++) {
      final bp = filtered[i];
      final key =
          '${bp.bill.billDate.year}-${bp.bill.billDate.month.toString().padLeft(2, '0')}';
      if (key != lastKey) {
        lastKey = key;
        out.add(_MonthLabel(
            DateTime(bp.bill.billDate.year, bp.bill.billDate.month, 1)));
      }
      out.add(_BillEntry(bp, i));
    }
    return out;
  }

  Widget _filterChip(_ChipFilter f, int count) {
    final cs = Theme.of(context).colorScheme;
    final selected = _chip == f;
    final Color color = switch (f) {
      _ChipFilter.all => cs.primary,
      _ChipFilter.unpaid => cs.error,
      _ChipFilter.partial => AppColors.warning,
      _ChipFilter.paid => AppColors.success,
      _ChipFilter.overdue => cs.error,
    };
    final label = switch (f) {
      _ChipFilter.all => 'All',
      _ChipFilter.unpaid => 'Unpaid',
      _ChipFilter.partial => 'Partial',
      _ChipFilter.paid => 'Paid',
      _ChipFilter.overdue => 'Overdue',
    };
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
              color: selected ? color : Theme.of(context).dividerColor),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            AppHaptics.select();
            setState(() => _chip = f);
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$label ($count)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? color : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Compact pill button shared by the supplier / sort / reset controls.
  Widget _toolbarPill({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? cs.primary.withValues(alpha: 0.18) : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(
              color: active ? cs.primary : Theme.of(context).dividerColor),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            AppHaptics.select();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 18,
                      color: active ? cs.primary : cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _supplierPill(Map<int, String> names) {
    final id = _supplierId;
    return _toolbarPill(
      icon: Icons.business_outlined,
      label: id == null ? 'Supplier' : (names[id] ?? 'Supplier'),
      active: id != null,
      onTap: _pickSupplier,
    );
  }

  Widget _sortPill() {
    final label = switch (_sort) {
      _SortOrder.newest => 'Newest',
      _SortOrder.oldest => 'Oldest',
      _SortOrder.amountDesc => 'Amount',
    };
    return _toolbarPill(
      icon: Icons.sort,
      label: 'Sort: $label',
      active: _sort != _SortOrder.newest,
      onTap: _pickSort,
    );
  }

  Widget _resetPill() {
    // Full reset: one control that always returns to the unfiltered list.
    return _toolbarPill(
      icon: Icons.close,
      label: 'Reset',
      active: false,
      onTap: _clearFilters,
    );
  }

  Future<void> _pickSupplier() async {
    final suppliers = ref.read(distributorListStreamProvider).valueOrNull ??
        const <Distributor>[];
    final sorted = [...suppliers]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final choice = await showActionSheet<int>(
      context,
      title: 'Filter by supplier',
      options: [
        const SheetAction(
          icon: Icons.all_inclusive,
          label: 'All suppliers',
          value: -1,
        ),
        for (final d in sorted)
          SheetAction(
            icon: Icons.business_outlined,
            label: d.name,
            subtitle: d.company ?? d.phone,
            value: d.id,
          ),
      ],
    );
    if (!mounted || choice == null) return;
    setState(() => _supplierId = choice == -1 ? null : choice);
  }

  Future<void> _pickSort() async {
    final choice = await showActionSheet<_SortOrder>(
      context,
      title: 'Sort bills',
      options: const [
        SheetAction(
          icon: Icons.arrow_downward,
          label: 'Newest first',
          subtitle: 'Bill date, latest on top',
          value: _SortOrder.newest,
        ),
        SheetAction(
          icon: Icons.arrow_upward,
          label: 'Oldest first',
          subtitle: 'Bill date, earliest on top',
          value: _SortOrder.oldest,
        ),
        SheetAction(
          icon: Icons.payments_outlined,
          label: 'Amount: high to low',
          subtitle: 'Biggest bills on top',
          value: _SortOrder.amountDesc,
        ),
      ],
    );
    if (!mounted || choice == null) return;
    setState(() => _sort = choice);
  }

  Widget _emptyState(List<BillPaid> allBills) {
    final bool noBillsAtAll = allBills.isEmpty &&
        _query.isEmpty &&
        _chip == _ChipFilter.all &&
        !_hasExtraFilters;
    if (noBillsAtAll) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No bills yet',
        subtitle: 'Record supplier bills to track dues.',
        actionLabel: 'Add your first bill',
        onAction: _openAdd,
      );
    }
    // Name the active constraint honestly: with search/supplier/sort set,
    // a chip-only title would blame the wrong filter.
    final bool scoped = _query.isNotEmpty || _hasExtraFilters;
    final String line = scoped
        ? 'No bills match these filters'
        : switch (_chip) {
            _ChipFilter.all => 'No bills match your search',
            _ChipFilter.unpaid => 'No unpaid bills',
            _ChipFilter.partial => 'No partial bills',
            _ChipFilter.paid => 'No paid bills yet',
            _ChipFilter.overdue => 'No overdue bills',
          };
    return EmptyState(
      icon: Icons.search_off,
      title: line,
      subtitle: 'Try a different search or filter.',
      actionLabel: 'Clear filters',
      onAction: _clearFilters,
    );
  }
}

class _MonthLabel {
  _MonthLabel(this.month);
  final DateTime month;
}

class _BillEntry {
  _BillEntry(this.bp, this.index);
  final BillPaid bp;
  final int index;
}

class _BillTile extends ConsumerWidget {
  final BillPaid bp;
  final String? supplierName;
  final VoidCallback onTap;
  final int index;

  const _BillTile({
    required this.bp,
    required this.onTap,
    required this.index,
    this.supplierName,
  });

  /// Captures the bill + its payments, confirms, deletes the cascade, and
  /// offers an Undo snack that re-inserts the exact same rows.
  Future<void> _deleteFlow(BuildContext context, WidgetRef ref) async {
    final bill = bp.bill;
    final db = ref.read(databaseProvider);
    List<Payment> captured;
    try {
      captured = await db.getPaymentsByBill(bill.id);
    } catch (_) {
      // Never confirm a delete with a guessed payment count: abort and say so.
      if (context.mounted) {
        showAppSnack(
          context,
          'Could not read payments. Delete cancelled.',
          success: false,
        );
      }
      return;
    }
    if (!context.mounted) return;
    final confirmed = await confirmSheet(
      context,
      title: 'Delete bill ${bill.billNumber}?',
      message: 'This permanently deletes the bill and ${captured.length} '
          'payment${captured.length == 1 ? '' : 's'}.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (confirmed != true || !context.mounted) return;
    // Re-capture AFTER confirm: a payment recorded while the sheet was
    // open is deleted by the cascade too, so Undo must know about it.
    try {
      captured = await db.getPaymentsByBill(bill.id);
    } catch (_) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Could not verify payments. Delete cancelled.',
          success: false,
        );
      }
      return;
    }
    try {
      await db.deleteBillCascade(bill.id);
      AppHaptics.destroy();
      if (!context.mounted) return;
      final snapshot = List<Payment>.of(captured);
      showAppSnack(
        context,
        'Bill ${bill.billNumber} deleted',
        actionLabel: 'Undo',
        onAction: () async {
          try {
            // If a bill with the same number appeared meanwhile (e.g. the
            // user re-created it), restore under a suffixed number instead
            // of violating the per-supplier uniqueness constraint.
            var number = bill.billNumber;
            var renamed = false;
            final dupe = await db.billNumberExistsForDistributor(
              bill.distributorId,
              number,
            );
            if (dupe) {
              number = '${bill.billNumber} (restored)';
              renamed = true;
            }
            // Atomic: bill + all its payments re-insert together or not
            // at all — never a half-restored bill.
            await db.transaction(() async {
              await db.addBill(BillsCompanion(
                id: Value(bill.id),
                distributorId: Value(bill.distributorId),
                billNumber: Value(number),
                billDate: Value(bill.billDate),
                amountPaise: Value(bill.amountPaise),
                notes: Value(bill.notes),
                createdAt: Value(bill.createdAt),
              ));
              for (final p in snapshot) {
                await db.addPayment(PaymentsCompanion(
                  // Preserve original ids: AUTOINCREMENT never reuses them,
                  // so a faithful restore cannot collide by itself.
                  id: Value(p.id),
                  billId: Value(p.billId),
                  paymentDate: Value(p.paymentDate),
                  amountPaise: Value(p.amountPaise),
                  mode: Value(p.mode),
                  referenceNo: Value(p.referenceNo),
                  notes: Value(p.notes),
                  createdAt: Value(p.createdAt),
                ));
              }
            });
            if (renamed && context.mounted) {
              showAppSnack(context, 'Bill restored as "$number"');
            }
          } catch (_) {
            // Undo failed (e.g. parent supplier gone): say so instead of
            // leaving the user believing the bill is back.
            if (context.mounted) {
              showAppSnack(
                context,
                'Could not restore bill. It may already exist.',
                success: false,
              );
            }
          }
        },
      );
    } catch (_) {
      if (context.mounted) {
        showAppSnack(
          context,
          'Could not delete. Please try again.',
          success: false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final name =
        (supplierName == null || supplierName!.isEmpty) ? '?' : supplierName!;
    return Dismissible(
      key: ValueKey('bill-${bp.bill.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      // Always return false: the watched list removes the tile on delete.
      confirmDismiss: (_) async {
        await _deleteFlow(context, ref);
        return false;
      },
      child: PressScale(
        onTap: () {
          AppHaptics.select();
          onTap();
        },
        index: index,
        dividerIndent: 16,
        label: 'Bill ${bp.bill.billNumber}',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradients.brand,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        bp.bill.billNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$name · ${_BillListScreenState._dateFmt.format(bp.bill.billDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.subtitleColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bp.isOverdue) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: cs.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Hero(
                          tag: 'billamt-${bp.bill.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              formatPaise(bp.bill.amountPaise),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                // Owed money reads as owed; settled reads calm.
                                color: bp.status.isSettled
                                    ? AppColors.textColor(context)
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    StatusChip(status: bp.status, compact: true),
                    // Partial: the total above is NOT what is owed — spell
                    // out the remaining due so a recorded payment is visibly
                    // honoured on the row itself.
                    if (bp.status == BillStatus.partial) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Due ${formatPaise(bp.remainingPaise)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                    // Overpaid: the total above hides the supplier credit —
                    // surface it like the detail screen does.
                    if (bp.status == BillStatus.overpaid) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Advance ${formatPaise(bp.paidPaise - bp.bill.amountPaise)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
