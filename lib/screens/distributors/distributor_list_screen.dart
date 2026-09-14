import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../services/summary_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../utils/text.dart';
import '../../widgets/widgets.dart';
import 'add_distributor_screen.dart';
import 'distributor_detail_screen.dart';

class DistributorListScreen extends ConsumerWidget {
  const DistributorListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          AppHaptics.select();
          Navigator.push(
            context,
            AppMotion.pageRoute(const AddDistributorScreen()),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Supplier'),
      ),
      body: const SafeArea(child: _SupplierListBody()),
    );
  }
}

class _SupplierListBody extends ConsumerStatefulWidget {
  const _SupplierListBody();

  @override
  ConsumerState<_SupplierListBody> createState() => _SupplierListBodyState();
}

class _SupplierListBodyState extends ConsumerState<_SupplierListBody> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      // Clear path (AppSearchBar clear button calls onChanged('') AND
      // onClear): apply immediately so no redundant delayed setState fires.
      if (_query.isNotEmpty && mounted) setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = value);
    });
  }

  void _onClearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() => _query = '');
  }

  /// Dues shown are for the *filtered* set: pairing a filtered count with
  /// the global total would imply the match owes everything.
  int _filteredDues(List<DistributorBalance> balances) =>
      balances.fold<int>(0, (s, b) => s + b.pendingPaise);

  @override
  Widget build(BuildContext context) {
    final distsAsync = ref.watch(distributorListStreamProvider);
    final billsAsync = ref.watch(billsWithPaidProvider);

    final dists = distsAsync.valueOrNull;
    final bills = billsAsync.valueOrNull;
    // Render only when BOTH streams have values: summary + empty-state must
    // never be derived from a half-loaded pair.
    if (dists == null || bills == null) {
      final err = distsAsync.error ?? billsAsync.error;
      if (err != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 40, color: AppColors.danger),
                const SizedBox(height: 12),
                const Text(
                  'Could not load suppliers.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(distributorListStreamProvider);
                    ref.invalidate(billsWithPaidProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return Stack(
        children: [
          const MeshHeader(height: 230),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Honest loading header: never flash '0 suppliers · ₹0 dues'.
              _headerBlock(0, 0, loading: true),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: AppSearchBar(
                  controller: _searchCtrl,
                  hint: 'Search suppliers...',
                  onChanged: _onSearchChanged,
                  onClear: _onClearSearch,
                ),
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SkeletonList(count: 6),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final summary = buildDashboardSummary(dists, bills);
    final q = _query.trim().toLowerCase();
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    final balances = q.isEmpty
        ? summary.balances
        : summary.balances
            .where(
              (b) =>
                  b.distributor.name.toLowerCase().contains(q) ||
                  (b.distributor.company?.toLowerCase().contains(q) ?? false) ||
                  (qDigits.isNotEmpty &&
                      (b.distributor.phone ?? '')
                          .replaceAll(RegExp(r'\D'), '')
                          .contains(qDigits)),
            )
            .toList();

    return Stack(
      children: [
        const MeshHeader(height: 230),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _headerBlock(
              summary.balances.length,
              q.isEmpty ? summary.totalPendingPaise : _filteredDues(balances),
              filteredCount: q.isEmpty ? null : balances.length,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: AppSearchBar(
                controller: _searchCtrl,
                hint: 'Search suppliers...',
                onChanged: _onSearchChanged,
                onClear: _onClearSearch,
              ),
            ),
            Expanded(
              child: summary.balances.isEmpty && q.isEmpty
                  ? _emptySuppliers()
                  : balances.isEmpty
                      ? _noSearchResults()
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                          itemCount: balances.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 0.8,
                            indent: 68,
                            endIndent: 4,
                            color: Theme.of(context).dividerColor,
                          ),
                          itemBuilder: (ctx, i) => AppMotion.fadeSlideIn(
                            index: i,
                            child: _supplierRow(context, balances[i]),
                          ),
                        ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _headerBlock(int count, int duesPaise,
      {int? filteredCount, bool loading = false}) {
    final sub = loading
        ? 'Loading suppliers…'
        : filteredCount != null
            ? '$filteredCount of ${plural(count, 'supplier')} · ${formatPaise(duesPaise)} dues'
            : '${plural(count, 'supplier')} · ${formatPaise(duesPaise)} dues';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suppliers',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textColor(context),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subtitleColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _supplierRow(BuildContext context, DistributorBalance b) {
    final d = b.distributor;
    final railColor = b.overdueCount > 0
        ? AppColors.danger
        : b.fullySettled
            ? AppColors.success
            : AppColors.warning;
    return PressScale(
        onTap: () {
          AppHaptics.select();
          Navigator.push(
            context,
            AppMotion.pageRoute(DistributorDetailScreen(distributor: d)),
          );
        },
        curve: Curves.easeOut,
        label: d.name,
        child: Container(
          // Settled tint and green rail only when nothing is left to pay:
          // netting an advance can zero the dues while an unsettled bill
          // remains, and that row must not read as done.
          decoration: b.fullySettled
              ? BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                )
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: railColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Center(
                    child: Hero(
                      tag: 'avatar-${d.id}',
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: AppGradients.brand,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initialLetter(d.name),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The name owns the whole column (the dues amount
                          // moved to the meta line below it): trade names like
                          // "Shree Ganesh Medical Agency (Wholesale)" need ~180 dp
                          // to wrap at word boundaries, and the amount column
                          // used to leave the name only ~138 dp. Longer names
                          // scroll rather than being cut.
                          WrapOrScrollText(
                            name: d.name,
                            maxLines: 2,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textColor(context),
                            ),
                          ),
                          if ((d.company ?? d.phone ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                d.company ?? d.phone!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.subtitleColor(context),
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                          text: plural(b.billCount, 'bill')),
                                      if (b.overdueCount > 0)
                                        const TextSpan(text: '  '),
                                      if (b.overdueCount > 0)
                                        TextSpan(
                                          text: '${b.overdueCount} overdue'
                                              .toUpperCase(),
                                          style: const TextStyle(
                                            color: AppColors.danger,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.subtitleColor(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!b.fullySettled)
                                AnimatedMoney(
                                  paise: b.pendingPaise,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.danger,
                                  ),
                                )
                              else
                                const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 16, color: AppColors.success),
                                    SizedBox(width: 4),
                                    Text(
                                      'Clear',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  _tileMenu(b),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _tileMenu(DistributorBalance b) {
    final d = b.distributor;
    return IconButton(
      icon: Icon(
        Icons.more_vert,
        color: AppColors.subtitleColor(context),
      ),
      tooltip: 'More options',
      onPressed: () async {
        AppHaptics.select();
        final choice = await showActionSheet<String>(
          context,
          title: d.name,
          options: const [
            SheetAction(
              icon: Icons.visibility_outlined,
              label: 'View',
              subtitle: 'Bills and payments',
              value: 'view',
            ),
            SheetAction(
              icon: Icons.edit_outlined,
              label: 'Edit',
              subtitle: 'Name, company, phone',
              value: 'edit',
            ),
            SheetAction(
              icon: Icons.delete_outline,
              label: 'Delete',
              subtitle: 'Bills and payments go too',
              value: 'delete',
              danger: true,
            ),
          ],
        );
        if (!mounted) return;
        switch (choice) {
          case 'view':
            Navigator.push(
              context,
              AppMotion.pageRoute(DistributorDetailScreen(distributor: d)),
            );
          case 'edit':
            Navigator.push(
              context,
              AppMotion.pageRoute(AddDistributorScreen(edit: d)),
            );
          case 'delete':
            _confirmDelete(d, b);
          case null:
            break;
        }
      },
    );
  }

  Future<void> _confirmDelete(Distributor d, DistributorBalance b) async {
    final billCount = b.billCount;
    final confirmed = await confirmSheet(
      context,
      title: 'Delete ${d.name}?',
      message:
          'This permanently deletes ${d.name}, their ${plural(billCount, 'bill')} '
          'and all payments on those bills. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    AppHaptics.destroy();
    try {
      await ref.read(databaseProvider).deleteDistributorCascade(d.id);
      if (!mounted) return;
      showAppSnack(context, 'Supplier deleted');
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not delete supplier', success: false);
    }
  }

  Widget _emptySuppliers() {
    return EmptyState(
      icon: Icons.storefront_outlined,
      title: 'No suppliers yet',
      subtitle: 'Add a supplier to start tracking their bills.',
      actionLabel: 'Add your first supplier',
      onAction: () {
        AppHaptics.select();
        Navigator.push(
          context,
          AppMotion.pageRoute(const AddDistributorScreen()),
        );
      },
    );
  }

  Widget _noSearchResults() {
    return EmptyState(
      icon: Icons.search_off,
      title: 'No suppliers match "$_query"',
      subtitle: 'Try a different name or company.',
      actionLabel: 'Clear search',
      onAction: _onClearSearch,
    );
  }
}
