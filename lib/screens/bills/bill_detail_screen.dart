import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/database.dart';
import '../../models/bill_status.dart';
import '../../providers/database_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/money.dart';
import '../../widgets/widgets.dart';
import '../payments/add_payment_screen.dart';
import 'add_bill_screen.dart';

class BillDetailScreen extends ConsumerStatefulWidget {
  final int billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  static final DateFormat _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final bpAsync = ref.watch(billByIdProvider(widget.billId));
    final paymentsAsync = ref.watch(paymentsStreamProvider(widget.billId));

    // Keep previous data visible during reloads: only skeleton/error when
    // there is no cached value at all.
    final bp = bpAsync.valueOrNull;
    if (bp == null) {
      if (bpAsync.isLoading) {
        return Scaffold(
          appBar: AppBar(title: const Text('Bill Details'), centerTitle: false),
          body: const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SkeletonList(count: 4),
          ),
        );
      }
      if (bpAsync.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Bill Details'), centerTitle: false),
          body: _errorCard(context, 'Something went wrong. ${bpAsync.error}'),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Bill Details'), centerTitle: false),
        body: _errorCard(context, 'This bill no longer exists.'),
      );
    }

    final payments = paymentsAsync.valueOrNull ?? const <Payment>[];
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _detailAppBar(context, bp, payments.length),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bp.isOverdue) ...[
                      _overdueStrip(context),
                      const SizedBox(height: 12),
                    ],
                    _metaSection(context, bp),
                    const SizedBox(height: 8),
                    _paymentsSection(context, ref, bp, paymentsAsync),
                    if (bp.status.isSettled) ...[
                      const SizedBox(height: 16),
                      _settledPill(context),
                    ],
                    const SizedBox(height: 88),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      floatingActionButton: _buildFab(bp),
    );
  }

  Widget _detailAppBar(BuildContext context, BillPaid bp, int paymentCount) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      centerTitle: false,
      title: Text(
        bp.bill.billNumber,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.more_vert,
            color: AppColors.subtitleColor(context),
          ),
          tooltip: 'More options',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          onPressed: () async {
            AppHaptics.select();
            final choice = await showActionSheet<String>(
              context,
              options: const [
                SheetAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit Bill',
                  subtitle: 'Update bill details',
                  value: 'edit',
                ),
                SheetAction(
                  icon: Icons.delete_outline,
                  label: 'Delete Bill',
                  subtitle: 'Remove bill and payments',
                  value: 'delete',
                  danger: true,
                ),
              ],
            );
            if (!context.mounted) return;
            switch (choice) {
              case 'edit':
                _editBill(bp);
              case 'delete':
                _confirmDeleteBill(bp, paymentCount);
              case null:
                break;
            }
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(gradient: _heroGradient(bp.status)),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(gradient: AppGradients.sheen),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: GlassBar(
                  child: SizedBox(height: 90),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Bill ${bp.bill.billNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Hero(
                        tag: 'billamt-${bp.bill.id}',
                        child: Material(
                          type: MaterialType.transparency,
                          child: Text(
                            formatPaise(bp.bill.amountPaise),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              height: 1.0,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          StatusChip(status: bp.status, onGradient: true),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Paid ${formatPaise(bp.paidPaise)} · '
                              'Due ${formatPaise(bp.remainingPaise)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (bp.status == BillStatus.overpaid) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Advance with supplier: '
                          '${formatPaise(bp.paidPaise - bp.bill.amountPaise)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
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

  /// Record Payment is only offered while the bill is unsettled. Non-null by
  /// contract: the only caller is past the `bp == null` early return.
  Widget? _buildFab(BillPaid bp) {
    if (bp.status.isSettled) return null;
    return FloatingActionButton.extended(
      heroTag: 'record-payment-${widget.billId}',
      onPressed: () => _recordPayment(bp.remainingPaise),
      icon: const Icon(Icons.account_balance_wallet),
      label: const Text('Record Payment'),
    );
  }

  void _recordPayment(int outstandingPaise) {
    Navigator.push(
      context,
      AppMotion.pageRoute(
        AddPaymentScreen(
          billId: widget.billId,
          outstandingPaise: outstandingPaise,
        ),
      ),
    );
  }

  void _editBill(BillPaid bp) {
    Navigator.push(
      context,
      AppMotion.pageRoute(AddBillScreen(editBill: bp.bill)),
    );
  }

  Future<void> _confirmDeleteBill(BillPaid bp, int paymentCount) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Delete Bill?',
      message: 'Delete bill ${bp.bill.billNumber} and all $paymentCount '
          'payment${paymentCount == 1 ? '' : 's'} permanently? '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(databaseProvider).deleteBillCascade(widget.billId);
      if (!mounted) return;
      AppHaptics.destroy();
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not delete. Please try again.',
          success: false,
        );
      }
    }
  }

  Future<void> _confirmDeletePayment(Payment p) async {
    final confirmed = await confirmSheet(
      context,
      title: 'Delete Payment?',
      message: 'Delete this payment record of ${formatPaise(p.amountPaise)} '
          'from ${_fmt.format(p.paymentDate)}?',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      final db = ref.read(databaseProvider);
      await db.deletePayment(p.id);
      if (!mounted) return;
      AppHaptics.destroy();
      showAppSnack(
        context,
        'Payment deleted',
        actionLabel: 'Undo',
        onAction: () async {
          try {
            // `db` captured before the snack: the snackbar outlives this route,
            // and reading `ref` from a disposed ConsumerState throws — which
            // the catch below then swallowed as a silent no-op Undo.
            await db.addPayment(PaymentsCompanion(
              billId: Value(p.billId),
              paymentDate: Value(p.paymentDate),
              amountPaise: Value(p.amountPaise),
              mode: Value(p.mode),
              referenceNo: Value(p.referenceNo),
              notes: Value(p.notes),
              createdAt: Value(p.createdAt),
            ));
          } catch (_) {
            // Undo failed (e.g. parent bill gone): say so instead of
            // leaving the user believing the payment is back.
            if (mounted) {
              showAppSnack(
                context,
                'Could not restore payment.',
                success: false,
              );
            }
          }
        },
      );
    } catch (_) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not delete. Please try again.',
          success: false,
        );
      }
    }
  }

  LinearGradient _heroGradient(BillStatus status) => switch (status) {
        BillStatus.unpaid => AppGradients.dangerSoft,
        BillStatus.partial => AppGradients.warningSoft,
        BillStatus.paid || BillStatus.overpaid => AppGradients.successSoft,
      };

  Widget _overdueStrip(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: cs.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Overdue — pending more than $overdueDays days',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaSection(BuildContext context, BillPaid bp) {
    Distributor? supplier;
    final dists =
        ref.watch(distributorListStreamProvider).valueOrNull ?? const [];
    for (final d in dists) {
      if (d.id == bp.bill.distributorId) supplier = d;
    }
    final notes = (bp.bill.notes ?? '').trim();
    return Column(
      children: [
        _metaRow(context, 'Bill No', bp.bill.billNumber),
        const Divider(height: 20),
        _metaRow(context, 'Bill Date', _fmt.format(bp.bill.billDate)),
        if (supplier != null) ...[
          const Divider(height: 20),
          _metaRow(context, 'Supplier', supplier.name),
        ],
        if (notes.isNotEmpty) ...[
          const Divider(height: 20),
          _metaRow(context, 'Notes', notes),
        ],
      ],
    );
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.subtitleColor(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentsSection(BuildContext context, WidgetRef ref, BillPaid bp,
      AsyncValue<List<Payment>> paymentsAsync) {
    final payments = paymentsAsync.valueOrNull;
    if (payments == null) {
      // No cached rows: loading skeleton, or a real error card — never a
      // fake "no payments" state that invites a duplicate record flow.
      if (paymentsAsync.hasError) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Payments'),
            const SizedBox(height: 4),
            _errorCard(context, 'Could not load payments.'),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(paymentsStreamProvider(bp.bill.id)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
        );
      }
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: 'Payments'),
          SizedBox(height: 4),
          SkeletonList(count: 2),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: 'Payments', count: payments.length),
        const SizedBox(height: 4),
        if (payments.isEmpty)
          EmptyState(
            icon: Icons.payments_outlined,
            title: 'No payments recorded yet',
            subtitle: 'Record the first payment for this bill.',
            actionLabel: 'Record Payment',
            onAction: () => _recordPayment(bp.remainingPaise),
          )
        else
          ...List.generate(
            payments.length,
            (i) => _paymentTile(
              context,
              bp,
              payments[i],
              i,
              isLast: i == payments.length - 1,
            ),
          ),
      ],
    );
  }

  Widget _paymentTile(
    BuildContext context,
    BillPaid bp,
    Payment p,
    int index, {
    required bool isLast,
  }) {
    final cs = Theme.of(context).colorScheme;
    return AppMotion.fadeSlideIn(
      index: index,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.brand,
                ),
                child: Icon(_modeIcon(p.mode), size: 18, color: Colors.white),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 28,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedMoney(
                          paise: p.amountPaise,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_fmt.format(p.paymentDate)}'
                          '${(p.referenceNo == null || p.referenceNo!.isEmpty) ? '' : ' · ${p.referenceNo}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.subtitleColor(context),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            p.mode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: cs.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppColors.subtitleColor(context),
                    ),
                    tooltip: 'Payment options',
                    constraints:
                        const BoxConstraints(minWidth: 48, minHeight: 48),
                    onPressed: () async {
                      AppHaptics.select();
                      final choice = await showActionSheet<String>(
                        context,
                        options: const [
                          SheetAction(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            subtitle: 'Update payment details',
                            value: 'edit',
                          ),
                          SheetAction(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            subtitle: 'Remove this payment',
                            value: 'delete',
                            danger: true,
                          ),
                        ],
                      );
                      if (!context.mounted) return;
                      switch (choice) {
                        case 'edit':
                          Navigator.push(
                            context,
                            AppMotion.pageRoute(
                              AddPaymentScreen(
                                billId: widget.billId,
                                outstandingPaise:
                                    bp.remainingPaise + p.amountPaise,
                                editPayment: p,
                              ),
                            ),
                          );
                        case 'delete':
                          _confirmDeletePayment(p);
                        case null:
                          break;
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _modeIcon(String mode) => switch (mode) {
        'Cash' => Icons.payments,
        'UPI' => Icons.smartphone,
        'Cheque' => Icons.receipt_long,
        'NEFT' || 'RTGS' => Icons.account_balance,
        _ => Icons.payments,
      };

  Widget _settledPill(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 18, color: AppColors.success),
            SizedBox(width: 6),
            Text(
              'Settled',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
