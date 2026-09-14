import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database.dart';
import '../../models/bill_status.dart';
import '../../providers/database_provider.dart';
import '../../services/bill_view_service.dart';
import '../../services/summary_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../utils/text.dart';
import '../../widgets/widgets.dart';
import '../bills/add_bill_screen.dart';
import '../bills/bill_detail_screen.dart';

class DistributorDetailScreen extends ConsumerStatefulWidget {
  const DistributorDetailScreen({super.key, required this.distributor});

  final Distributor distributor;

  @override
  ConsumerState<DistributorDetailScreen> createState() =>
      _DistributorDetailScreenState();
}

class _DistributorDetailScreenState
    extends ConsumerState<DistributorDetailScreen> {
  static final DateFormat _dateFmt = DateFormat('dd/MM/yyyy');

  /// Which slice of this supplier's bills the ledger below shows. The
  /// Billed / Paid / Pending tiles drive it, the chips mirror it.
  SupplierBillFilter _filter = SupplierBillFilter.all;

  void _selectFilter(SupplierBillFilter filter) {
    AppHaptics.select();
    if (_filter == filter) return;
    setState(() => _filter = filter);
  }

  @override
  Widget build(BuildContext context) {
    // Live distributor row: an edit made elsewhere must reflect here
    // without pop/repush (the ctor snapshot goes stale).
    final dists = ref.watch(distributorListStreamProvider).valueOrNull;
    var d = widget.distributor;
    if (dists != null) {
      for (final cand in dists) {
        if (cand.id == d.id) {
          d = cand;
          break;
        }
      }
    }
    final billsAsync = ref.watch(billsWithPaidProvider);
    // Supplier deleted elsewhere while this screen is open: say so instead
    // of showing a live-looking page with an empty bill list.
    if (dists != null && !dists.any((e) => e.id == d.id)) {
      return Scaffold(
        appBar: AppBar(
          centerTitle: false,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Supplier'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined,
                    size: 40, color: AppColors.danger),
                SizedBox(height: 12),
                Text(
                  'This supplier no longer exists.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final distBills = billsAsync.valueOrNull
        ?.where((bp) => bp.bill.distributorId == d.id)
        .toList();
    if (distBills == null) {
      if (billsAsync.error != null) {
        return Scaffold(
          appBar: AppBar(
            centerTitle: false,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: WrapOrScrollText(
              name: d.name,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          body: Center(
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(billsWithPaidProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      // Cold load: skeleton everything. Rendering the header from an empty
      // list would flash ₹0 / 'Clear' for a frame — a lie, not a loader.
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              centerTitle: false,
              backgroundColor: AppColors.primary,
              leading: const BackButton(color: Colors.white),
              title: WrapOrScrollText(
                name: d.name,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: SkeletonList(count: 4),
              ),
            ),
          ],
        ),
      );
    }
    final balance = buildDashboardSummary([d], distBills).balances.first;
    // Counts come off the full list, so the chips keep telling the truth
    // while a filter is active.
    final counts = supplierBillCounts(distBills);
    final visible = applySupplierBillFilter(distBills, _filter);
    final filtered = _filter != SupplierBillFilter.all;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _sliverHeader(d, balance),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _statStrip(balance, counts),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SectionHeader(
                          title: 'Bills',
                          count: visible.length,
                        ),
                      ),
                      // Filtered view: name what the count is a slice of.
                      if (filtered)
                        Text(
                          'of ${distBills.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.subtitleColor(context),
                          ),
                        ),
                    ],
                  ),
                  if (distBills.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _filterChips(counts),
                  ],
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          if (distBills.isEmpty)
            SliverToBoxAdapter(child: _emptyBills())
          else if (visible.isEmpty)
            SliverToBoxAdapter(
              child: _emptyFilteredBills(distBills.length),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: _ledgerRows(visible),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sliverHeader(Distributor d, DistributorBalance balance) {
    final phone = d.phone?.trim();
    final hasPhone = phone != null && phone.isNotEmpty;
    final company = (d.company ?? '').trim();
    return SliverAppBar(
      expandedHeight: 230,
      pinned: true,
      centerTitle: false,
      backgroundColor: AppColors.primary,
      leading: const BackButton(color: Colors.white),
      title: WrapOrScrollText(
        name: d.name,
        maxLines: 1,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppGradients.brand),
          child: Stack(
            children: [
              const Positioned.fill(
                child: MeshHeader(height: 230),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(gradient: AppGradients.sheen),
                ),
              ),
              // Frost strip under the status bar so the collapsing bar
              // keeps legible contrast. Height 90 covers status + toolbar.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 90,
                child: GlassBar(child: SizedBox.expand()),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Hero(
                            tag: 'avatar-${d.id}',
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.18),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initialLetter(d.name),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: WrapOrScrollText(
                              name: d.name,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: hasPhone ? () => _call(phone) : null,
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 16,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                company.isNotEmpty
                                    ? (hasPhone
                                        ? '$company · $phone · tap to call'
                                        : company)
                                    : (hasPhone
                                        ? '$phone · tap to call'
                                        : 'No phone number'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                            if (hasPhone)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.call,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Pending  ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          // Scale down instead of overflowing on huge dues /
                          // large-text settings (mirrors _glassTile).
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: balance.fullySettled
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.check_circle,
                                            size: 22, color: Colors.white),
                                        SizedBox(width: 6),
                                        Text(
                                          'Clear',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : AnimatedMoney(
                                      paise: balance.pendingPaise,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _call(String rawPhone) async {
    var num = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (num.length == 10) {
      num = '+91$num';
    } else if (num.length == 11 && num.startsWith('0')) {
      // Indian trunk prefix: 0 + 10 digits dials as +91.
      num = '+91${num.substring(1)}';
    } else if (num.isNotEmpty) {
      // 11–15 digit international number: keep it dialable with '+'.
      num = '+$num';
    }
    try {
      await launchUrl(Uri.parse('tel:$num'), mode: LaunchMode.platformDefault);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not open dialer', success: false);
    }
  }

  Widget _statStrip(
    DistributorBalance b,
    Map<SupplierBillFilter, int> counts,
  ) {
    // Each tile is also the filter for the bills behind its own number:
    // Billed → all bills, Paid → bills with money on them, Pending → still owed.
    //
    // IntrinsicHeight is load-bearing: this Row sits in a sliver box, which
    // offers an unbounded height, and a stretched Row handed an infinite
    // height collapses the whole sliver (tiles painted, everything below them
    // — the bill ledger — never laid out). IntrinsicHeight gives the Row a
    // finite height first, so the tile tops/bottoms still line up.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _glassTile(
              key: const ValueKey('supplier-tile-all'),
              label: 'Billed',
              selected: _filter == SupplierBillFilter.all,
              semanticsLabel:
                  'Show all ${plural(counts[SupplierBillFilter.all] ?? 0, 'bill')}',
              onTap: () => _selectFilter(SupplierBillFilter.all),
              child: AnimatedMoney(
                paise: b.billedPaise,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _glassTile(
              key: const ValueKey('supplier-tile-paid'),
              label: 'Paid',
              selected: _filter == SupplierBillFilter.paid,
              semanticsLabel:
                  'Show ${plural(counts[SupplierBillFilter.paid] ?? 0, 'paid bill')}',
              onTap: () => _selectFilter(SupplierBillFilter.paid),
              child: AnimatedMoney(
                paise: b.paidPaise,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _glassTile(
              key: const ValueKey('supplier-tile-pending'),
              label: 'Pending',
              selected: _filter == SupplierBillFilter.pending,
              semanticsLabel: 'Show '
                  '${plural(counts[SupplierBillFilter.pending] ?? 0, 'pending bill')}',
              onTap: () => _selectFilter(SupplierBillFilter.pending),
              // Only "Clear" when nothing is actually left to pay: netting an
              // advance can push the pending amount to zero while an unsettled
              // bill still exists, and that case must not claim to be clear.
              child: b.fullySettled
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : AnimatedMoney(
                      paise: b.pendingPaise,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassTile({
    required String label,
    required Widget child,
    required VoidCallback onTap,
    required String semanticsLabel,
    bool selected = false,
    Key? key,
  }) {
    return Semantics(
      key: key,
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppGradients.brand,
            borderRadius: BorderRadius.circular(14),
          ),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              // The active tile stays visibly pressed-down so the ledger
              // below can never look unfiltered by accident.
              color: Colors.white.withValues(alpha: selected ? 0.3 : 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.9 : 0.22),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Scope chips: same vocabulary as the tiles, with live counts so a hidden
  /// slice is never a mystery.
  Widget _filterChips(Map<SupplierBillFilter, int> counts) {
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final f in SupplierBillFilter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _filterChip(f, counts[f] ?? 0),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(SupplierBillFilter f, int count) {
    final cs = Theme.of(context).colorScheme;
    final bool selected = _filter == f;
    final Color color = switch (f) {
      SupplierBillFilter.all => cs.primary,
      SupplierBillFilter.pending => AppColors.warning,
      SupplierBillFilter.paid => AppColors.success,
      SupplierBillFilter.overdue => cs.error,
    };
    return Material(
      color: selected ? color.withValues(alpha: 0.18) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? color : Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _selectFilter(f),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: Text(
                '${f.label} ($count)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _ledgerRows(List<BillPaid> bills) {
    final sorted = sortSupplierBills(bills);
    final rows = <Widget>[];
    for (int i = 0; i < sorted.length; i++) {
      rows.add(AppMotion.fadeSlideIn(index: i, child: _billRow(sorted[i])));
      if (i != sorted.length - 1) {
        rows.add(
          Divider(
            height: 1,
            thickness: 0.8,
            indent: 8,
            endIndent: 8,
            color: Theme.of(context).dividerColor,
          ),
        );
      }
    }
    return rows;
  }

  Widget _billRow(BillPaid bp) {
    final status = bp.status;
    final advance = bp.paidPaise - bp.bill.amountPaise;
    return GestureDetector(
      onTap: () {
        AppHaptics.select();
        Navigator.push(
          context,
          AppMotion.pageRoute(BillDetailScreen(billId: bp.bill.id)),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '#${bp.bill.billNumber}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textColor(context),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status: status, compact: true),
              ],
            ),
            const SizedBox(height: 4),
            // Billed / Paid / Due spelled out per bill, so the Billed, Paid
            // and Pending tiles above can always be traced to real rows.
            Text(
              '${_dateFmt.format(bp.bill.billDate)} · '
              'Billed ${formatPaise(bp.bill.amountPaise)}',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtitleColor(context),
              ),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Paid ${formatPaise(bp.paidPaise)}'),
                  if (!status.isSettled)
                    TextSpan(
                      text: ' · Due ${formatPaise(bp.remainingPaise)}',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (status == BillStatus.overpaid)
                    TextSpan(
                      text: ' · Advance ${formatPaise(advance)}',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (bp.isOverdue)
                    const TextSpan(
                      text: ' · Overdue',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Filtered to nothing: say which slice is empty and offer the way back —
  /// never the "no bills at all" empty state, which would be a lie here.
  Widget _emptyFilteredBills(int total) {
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: _filter.emptyTitle,
      subtitle: 'This supplier has ${plural(total, 'bill')} in total.',
      actionLabel: 'Show all bills',
      onAction: () => _selectFilter(SupplierBillFilter.all),
    );
  }

  Widget _emptyBills() {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No bills for this supplier yet',
      subtitle: 'Add the first bill to start tracking payments.',
      actionLabel: 'Add Bill',
      onAction: () {
        AppHaptics.select();
        Navigator.push(
          context,
          AppMotion.pageRoute(
            AddBillScreen(presetDistributorId: widget.distributor.id),
          ),
        );
      },
    );
  }
}
