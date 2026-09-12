import '../database/database.dart';
import '../models/bill_status.dart';

class DashboardSummary {
  final int totalDistributors;
  final int totalBills;
  final int totalBilledPaise;
  final int totalPaidPaise;
  final int totalPendingPaise;
  final int overdueCount;
  final List<DistributorBalance> balances;

  const DashboardSummary({
    required this.totalDistributors,
    required this.totalBills,
    required this.totalBilledPaise,
    required this.totalPaidPaise,
    required this.totalPendingPaise,
    required this.overdueCount,
    required this.balances,
  });
}

class DistributorBalance {
  final Distributor distributor;
  final int billedPaise;
  final int paidPaise;

  /// Clamped at zero — overpay credit on one bill offsets dues on other
  /// bills of the same supplier before clamping (netted per supplier).
  final int pendingPaise;
  final int billCount;
  final int settledCount;
  final int overdueCount;

  const DistributorBalance({
    required this.distributor,
    required this.billedPaise,
    required this.paidPaise,
    required this.pendingPaise,
    required this.billCount,
    required this.settledCount,
    required this.overdueCount,
  });

  bool get hasPending => pendingPaise > 0;
}

/// Pure function — unit tested. Derives the whole dashboard from the
/// watched sources of truth.
DashboardSummary buildDashboardSummary(
  List<Distributor> distributors,
  List<BillPaid> bills, {
  DateTime? now,
}) {
  if (distributors.isEmpty && bills.isEmpty) {
    return DashboardSummary(
      totalDistributors: 0,
      totalBills: 0,
      totalBilledPaise: 0,
      totalPaidPaise: 0,
      totalPendingPaise: 0,
      overdueCount: 0,
      balances: const [],
    );
  }

  final byDist = <int, List<BillPaid>>{};
  var totalBilled = 0;
  var totalPaid = 0;
  var overdueTotal = 0;

  for (final bp in bills) {
    byDist.putIfAbsent(bp.bill.distributorId, () => []).add(bp);
    totalBilled += bp.bill.amountPaise;
    totalPaid += bp.paidPaise;
    if (isBillOverdue(bp.bill.billDate, bp.bill.amountPaise, bp.paidPaise,
        now: now)) {
      overdueTotal++;
    }
  }

  final balances = distributors.map((d) {
    final list = byDist[d.id] ?? const <BillPaid>[];
    var billed = 0;
    var paid = 0;
    var settled = 0;
    var overdue = 0;
    var rawPending = 0;
    for (final bp in list) {
      billed += bp.bill.amountPaise;
      paid += bp.paidPaise;
      rawPending += bp.bill.amountPaise - bp.paidPaise;
      if (bp.status.isSettled) settled++;
      if (isBillOverdue(bp.bill.billDate, bp.bill.amountPaise, bp.paidPaise,
          now: now)) {
        overdue++;
      }
    }
    return DistributorBalance(
      distributor: d,
      billedPaise: billed,
      paidPaise: paid,
      pendingPaise: rawPending > 0 ? rawPending : 0,
      billCount: list.length,
      settledCount: settled,
      overdueCount: overdue,
    );
  }).toList()
    ..sort((a, b) {
      final cmp = b.pendingPaise.compareTo(a.pendingPaise);
      if (cmp != 0) return cmp;
      return a.distributor.name
          .toLowerCase()
          .compareTo(b.distributor.name.toLowerCase());
    });

  return DashboardSummary(
    totalDistributors: distributors.length,
    totalBills: bills.length,
    totalBilledPaise: totalBilled,
    totalPaidPaise: totalPaid,
    totalPendingPaise:
        totalBilled - totalPaid > 0 ? totalBilled - totalPaid : 0,
    overdueCount: overdueTotal,
    balances: balances,
  );
}
