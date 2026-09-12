import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../database/database.dart';
import '../../models/bill_status.dart';
import '../../providers/database_provider.dart';
import '../../services/pdf_export_service.dart';
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

  bool _sharing = false;

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
            title: Text(d.name),
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
              title: Text(
                d.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  _statStrip(balance),
                  const SizedBox(height: 14),
                  _shareButton(d, distBills),
                  const SizedBox(height: 16),
                  SectionHeader(
                    title: 'Bills',
                    count: distBills.length,
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          if (distBills.isEmpty)
            SliverToBoxAdapter(child: _emptyBills())
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: _ledgerRows(distBills),
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
      title: Text(
        d.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
                            child: Text(
                              d.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              child: balance.hasPending
                                  ? AnimatedMoney(
                                      paise: balance.pendingPaise,
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.5,
                                      ),
                                    )
                                  : const Row(
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

  Widget _statStrip(DistributorBalance b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _glassTile(
            label: 'Billed',
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
            label: 'Paid',
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
            label: 'Pending',
            child: b.hasPending
                ? AnimatedMoney(
                    paise: b.pendingPaise,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  )
                : const Row(
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
                  ),
          ),
        ),
      ],
    );
  }

  Widget _glassTile({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppGradients.brand,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
            width: 1,
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
    );
  }

  Widget _shareButton(Distributor d, List<BillPaid> distBills) {
    // Empty list => nothing to share (button dead); the loading state never
    // reaches here (skeleton branch above).
    final enabled = distBills.isNotEmpty && !_sharing;
    return FilledButton.tonalIcon(
      onPressed: !enabled ? null : () => _shareStatement(d, distBills),
      icon: _sharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.picture_as_pdf),
      label: Text(_sharing ? 'Preparing...' : 'Share Statement'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
    );
  }

  Future<void> _shareStatement(Distributor d, List<BillPaid> items) async {
    if (_sharing || items.isEmpty) return;
    setState(() => _sharing = true);
    bool ok = false;
    try {
      ok = await PdfExportService.shareSupplierStatement(
        distributor: d,
        items: items,
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _sharing = false);
    if (!ok) {
      showAppSnack(context, 'Could not generate statement', success: false);
    }
  }

  List<Widget> _ledgerRows(List<BillPaid> bills) {
    // Date DESC like the watched query, id DESC tiebreak so same-day
    // bills never flip order across rebuilds (Dart sort is not stable).
    final sorted = [...bills]..sort((a, b) {
        final byDate = b.bill.billDate.compareTo(a.bill.billDate);
        return byDate != 0 ? byDate : b.bill.id.compareTo(a.bill.id);
      });
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
            Text(
              '${_dateFmt.format(bp.bill.billDate)} · ${formatPaise(bp.bill.amountPaise)}',
              style: TextStyle(
                  fontSize: 13, color: AppColors.subtitleColor(context)),
            ),
            if (!status.isSettled) ...[
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text:
                          'Paid ${formatPaise(bp.paidPaise)} of ${formatPaise(bp.bill.amountPaise)}',
                    ),
                    if (bp.isOverdue)
                      const TextSpan(
                        text: ' · Overdue',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
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
          ],
        ),
      ),
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
