import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../providers/database_provider.dart';
import '../../services/summary_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../utils/text.dart';
import '../../widgets/widgets.dart';
import '../distributors/add_distributor_screen.dart';
import '../distributors/distributor_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.onSeeOverdue});

  final void Function()? onSeeOverdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distsAsync = ref.watch(distributorListStreamProvider);
    final billsAsync = ref.watch(billsWithPaidProvider);

    final dists = distsAsync.valueOrNull;
    final bills = billsAsync.valueOrNull;

    // Cold start only: keep previous data visible during reloads.
    // Render only when BOTH streams have values — never a half-loaded pair.
    if (dists == null || bills == null) {
      final err = distsAsync.error ?? billsAsync.error;
      if (err != null) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 40, color: AppColors.danger),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load dashboard.',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
            ),
          ),
        );
      }
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
            child: SkeletonList(count: 6),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MeshHeader(height: 300),
          ),
          SafeArea(
            child: _DashboardBody(
              summary: buildDashboardSummary(dists, bills),
              bills: bills,
              onSeeOverdue: onSeeOverdue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Monthly purchase totals (paise) for the last 6 calendar months,
/// oldest first, zeros for empty months. Pure — safe to unit test.
List<double> monthlyPurchasePaise(List<BillPaid> bills, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final totals = <double>[];
  for (var i = 5; i >= 0; i--) {
    final month = DateTime(ref.year, ref.month - i, 1);
    var sum = 0;
    for (final bp in bills) {
      final d = bp.bill.billDate;
      if (d.year == month.year && d.month == month.month) {
        sum += bp.bill.amountPaise;
      }
    }
    totals.add(sum.toDouble());
  }
  return totals;
}

List<DateTime> lastSixMonths({DateTime? now}) {
  final ref = now ?? DateTime.now();
  return [for (var i = 5; i >= 0; i--) DateTime(ref.year, ref.month - i, 1)];
}

class _DashboardBody extends ConsumerStatefulWidget {
  const _DashboardBody({
    required this.summary,
    required this.bills,
    this.onSeeOverdue,
  });

  final DashboardSummary summary;
  final List<BillPaid> bills;
  final void Function()? onSeeOverdue;

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  late final ScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = ScrollController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final bills = widget.bills;
    final onSeeOverdue = widget.onSeeOverdue;
    final settledCount =
        s.balances.fold<int>(0, (acc, b) => acc + b.settledCount);
    final withDues = s.balances.where((b) => !b.fullySettled).length;
    // One clock read for the whole frame: two `DateTime.now()` calls let the
    // bars and the month labels disagree when a month ticks over between them.
    final now = DateTime.now();
    final monthly = monthlyPurchasePaise(bills, now: now);
    final months = lastSixMonths(now: now);
    var sixMonthPaise = 0;
    for (final v in monthly) {
      sixMonthPaise += v.round();
    }
    var overduePaise = 0;
    for (final bp in bills) {
      if (bp.isOverdue) overduePaise += bp.remainingPaise;
    }
    final todayLabel = DateFormat('d MMM yyyy').format(now);

    return ListView(
      controller: _ctrl,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        // Greeting block — left aligned, no AppBar.
        Text(
          'NAMASTE',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppColors.subtitleColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          todayLabel,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.subtitleColor(context),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedMoney(
          paise: s.totalPendingPaise,
          style: TextStyle(
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1.0,
            letterSpacing: -0.5,
            color: AppColors.textColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'pending · ${plural(s.totalBills, 'bill')} · '
          '${plural(s.totalDistributors, 'supplier')}',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.subtitleColor(context),
          ),
        ),
        const SizedBox(height: 16),
        // Single wide hero strip with sparkline merged in.
        TiltOnScroll(
          scrollController: _ctrl,
          child: _HeroStrip(
            sixMonthPaise: sixMonthPaise,
            monthly: monthly,
            months: months,
          ),
        ),
        const SizedBox(height: 12),
        // Overdue alert rail — hidden when zero.
        if (s.overdueCount > 0)
          _OverdueRail(
            count: s.overdueCount,
            paise: overduePaise,
            onTap: onSeeOverdue,
          ),
        if (s.overdueCount > 0) const SizedBox(height: 8),
        // Paid ledger row — no card.
        _PaidLedgerRow(
          paidPaise: s.totalPaidPaise,
          settledCount: settledCount,
        ),
        const SizedBox(height: 12),
        SectionHeader(title: 'Dues', count: withDues),
        const SizedBox(height: 4),
        if (s.balances.isEmpty)
          EmptyState(
            icon: Icons.storefront_outlined,
            title: 'No suppliers yet',
            subtitle: 'Track supplier bills and payments here.',
            actionLabel: 'Add your first supplier',
            onAction: () {
              AppHaptics.select();
              Navigator.push(
                context,
                AppMotion.pageRoute(const AddDistributorScreen()),
              );
            },
          )
        else
          ...List.generate(
            s.balances.length,
            (i) => AppMotion.fadeSlideIn(
              index: i,
              child: _BalanceLedgerRow(
                balance: s.balances[i],
                onTap: () {
                  AppHaptics.select();
                  Navigator.push(
                    context,
                    AppMotion.pageRoute(
                      DistributorDetailScreen(
                          distributor: s.balances[i].distributor),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroStrip extends StatelessWidget {
  const _HeroStrip({
    required this.sixMonthPaise,
    required this.monthly,
    required this.months,
  });

  final int sixMonthPaise;
  final List<double> monthly;
  final List<DateTime> months;

  @override
  Widget build(BuildContext context) {
    final hasData = monthly.any((v) => v > 0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: AppRadius.lgAll,
        boxShadow: AppShadow.hero(context),
        border: AppShadow.cardBorder(context),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: AppGradients.sheen,
                borderRadius: AppRadius.lgAll,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Last 6 months · ${formatPaise(sixMonthPaise)} purchased',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: 12),
              if (hasData)
                DrawSparkline(
                  values: monthly,
                  height: 72,
                  color: Colors.white,
                )
              else
                const Text(
                  'No purchase data yet',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final m in months)
                    Text(
                      DateFormat('MMM').format(m),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverdueRail extends StatelessWidget {
  const _OverdueRail({required this.count, required this.paise, this.onTap});

  final int count;
  final int paise;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap == null
            ? null
            : () {
                AppHaptics.select();
                onTap!.call();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 22, color: cs.onErrorContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count overdue · ${formatPaise(paise)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, size: 22, color: cs.onErrorContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaidLedgerRow extends StatelessWidget {
  const _PaidLedgerRow({required this.paidPaise, required this.settledCount});

  final int paidPaise;
  final int settledCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.success),
          const SizedBox(width: 8),
          Text(
            'Total paid ',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.subtitleColor(context),
            ),
          ),
          AnimatedMoney(
            paise: paidPaise,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor(context),
            ),
          ),
          Expanded(
            child: Text(
              ' · $settledCount settled',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.subtitleColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceLedgerRow extends StatelessWidget {
  const _BalanceLedgerRow({
    required this.balance,
    required this.onTap,
  });

  final DistributorBalance balance;
  final VoidCallback onTap;

  Color get _rail => balance.overdueCount > 0
      ? AppColors.danger
      : balance.fullySettled
          ? AppColors.success
          : AppColors.warning;

  @override
  Widget build(BuildContext context) {
    final b = balance;
    final sub = b.distributor.company ?? b.distributor.phone ?? '';
    return PressScale(
      onTap: onTap,
      label: b.distributor.name,
      dividerIndent: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _rail,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Hero(
                // Dashboard-scoped tag: the Suppliers tab mounts the same
                // distributor avatar simultaneously (IndexedStack) with tag
                // 'avatar-<id>', so sharing that tag would crash the Hero
                // flight with a duplicate-tag assertion.
                tag: 'avatar-dash-${b.distributor.id}',
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: b.fullySettled
                        ? AppGradients.successSoft
                        : AppGradients.brand,
                  ),
                  child: Text(
                    initialLetter(b.distributor.name),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // The name owns the whole column — the dues amount sits
                      // on the meta line below it, so long trade names like
                      // "Shree Ganesh Medical Agency (Wholesale)" wrap at word
                      // boundaries; a name too long even for that scrolls
                      // instead of being cut.
                      WrapOrScrollText(
                        name: b.distributor.name,
                        maxLines: 2,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.subtitleColor(context),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: plural(b.billCount, 'bill')),
                                  if (b.overdueCount > 0)
                                    TextSpan(
                                      text: ' · ${b.overdueCount} overdue',
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
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
                          // "Clear" only when nothing is left to pay. Netting
                          // an advance can zero the amount while an unsettled
                          // bill remains — that row is not clear.
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
            ],
          ),
        ),
      ),
    );
  }
}
