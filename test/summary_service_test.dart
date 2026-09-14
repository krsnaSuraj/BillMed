import 'package:flutter_test/flutter_test.dart';
import 'package:billmed/database/database.dart';
import 'package:billmed/services/summary_service.dart';

Bill _bill(int id, int distId, int amountPaise, DateTime date) => Bill(
      id: id,
      distributorId: distId,
      billNumber: 'B$id',
      billDate: date,
      amountPaise: amountPaise,
      notes: null,
      createdAt: date,
    );

Distributor _dist(int id, String name) => Distributor(
      id: id,
      name: name,
      company: null,
      phone: null,
      createdAt: DateTime(2025),
    );

void main() {
  group('buildDashboardSummary', () {
    test('empty inputs give clean zero summary', () {
      final s = buildDashboardSummary(const [], const []);
      expect(s.totalBills, 0);
      expect(s.totalPendingPaise, 0);
      expect(s.overdueCount, 0);
      expect(s.balances, isEmpty);
    });

    test('aggregates per supplier with exact paise math', () {
      final d1 = _dist(1, 'Alpha');
      final d2 = _dist(2, 'Beta');
      final bills = [
        BillPaid(
            bill: _bill(10, 1, 500000, DateTime(2026, 5, 1)),
            paidPaise: 200000),
        BillPaid(
            bill: _bill(11, 1, 250075, DateTime(2026, 5, 2)),
            paidPaise: 250075),
        BillPaid(bill: _bill(12, 2, 99999, DateTime(2026, 5, 3)), paidPaise: 0),
      ];
      final s = buildDashboardSummary([d1, d2], bills);

      expect(s.totalBills, 3);
      expect(s.totalBilledPaise, 850074);
      expect(s.totalPaidPaise, 450075);

      final alpha = s.balances.firstWhere((b) => b.distributor.name == 'Alpha');
      expect(alpha.billedPaise, 750075);
      expect(alpha.pendingPaise, 300000);
      expect(alpha.settledCount, 1);

      final beta = s.balances.firstWhere((b) => b.distributor.name == 'Beta');
      expect(beta.pendingPaise, 99999);
    });

    test('sorts suppliers by pending descending, settled last', () {
      final clear = _dist(1, 'ClearGuy');
      final owesBig = _dist(2, 'OwesBig');
      final owesSmall = _dist(3, 'OwesSmall');
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 1000, DateTime(2026, 5, 1)), paidPaise: 1000),
        BillPaid(bill: _bill(2, 2, 900000, DateTime(2026, 5, 1)), paidPaise: 0),
        BillPaid(
            bill: _bill(3, 3, 50000, DateTime(2026, 5, 1)), paidPaise: 10000),
      ];
      final s = buildDashboardSummary([clear, owesBig, owesSmall], bills);
      expect(s.balances.map((b) => b.distributor.name).toList(),
          ['OwesBig', 'OwesSmall', 'ClearGuy']);
      // The numbers themselves, not just the order (an order assertion alone
      // passes for any sort that happens to keep this arrangement).
      expect(
          s.balances.map((b) => b.pendingPaise).toList(), [900000, 40000, 0]);
    });

    test('overdue counts only unsettled bills past 30 days', () {
      final d = _dist(1, 'OldDebtor');
      final now = DateTime(2026, 8, 26);
      final oldUnpaid =
          BillPaid(bill: _bill(1, 1, 1000, DateTime(2026, 7, 1)), paidPaise: 0);
      final recentUnpaid = BillPaid(
          bill: _bill(2, 1, 2000, DateTime(2026, 8, 20)), paidPaise: 0);
      final oldPaid = BillPaid(
          bill: _bill(3, 1, 3000, DateTime(2026, 1, 1)), paidPaise: 3000);
      final s = buildDashboardSummary([d], [oldUnpaid, recentUnpaid, oldPaid],
          now: now);
      expect(s.overdueCount, 1);
      expect(s.balances.first.overdueCount, 1);
      // Which one, not just how many: the settled old bill must be the
      // excluded row.
      expect(oldUnpaid.isOverdue, isTrue);
      expect(oldPaid.isOverdue, isFalse);
      expect(recentUnpaid.isOverdue, isFalse);
    });

    test('pending clamps to zero per supplier when that supplier overpaid', () {
      final d = _dist(1, 'CreditGuy');
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 10000, DateTime(2026, 5, 1)), paidPaise: 15000),
      ];
      final s = buildDashboardSummary([d], bills);
      expect(s.balances.first.pendingPaise, 0);
      expect(s.totalPendingPaise, 0);
      // Netting away the dues does not make the supplier settled: it still has
      // an unsettled bill (and, here, is owed an advance).
      expect(s.balances.first.hasPending, isFalse);
      expect(s.balances.first.unsettledCount, 0,
          reason: 'the only bill is paid');
      expect(s.balances.first.fullySettled, isTrue);
    });

    test('the headline pending is the sum of the per-supplier dues', () {
      // One supplier holds an advance, the other is owed money. Netting the
      // two grand totals used to report ₹0 pending above a red ₹50 row.
      final advanceGuy = _dist(1, 'AdvanceGuy');
      final owesGuy = _dist(2, 'OwesGuy');
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 100000, DateTime(2026, 5, 1)), paidPaise: 110000),
        BillPaid(bill: _bill(2, 2, 5000, DateTime(2026, 5, 1)), paidPaise: 0),
      ];
      final s = buildDashboardSummary([advanceGuy, owesGuy], bills);
      expect(s.balances.map((b) => b.pendingPaise).toList(), [5000, 0]);
      expect(s.totalPendingPaise, 5000,
          reason:
              'an advance to one supplier cannot cancel another supplier debt');
      expect(s.totalPendingPaise,
          s.balances.fold<int>(0, (sum, b) => sum + b.pendingPaise),
          reason: 'the headline must equal the rows beneath it');
    });

    test('a supplier whose dues are netted away is not reported as settled',
        () {
      final d = _dist(1, 'MixedGuy');
      final bills = [
        // Advance on one bill…
        BillPaid(
            bill: _bill(1, 1, 10000, DateTime(2026, 5, 1)), paidPaise: 15000),
        // …and an unpaid bill on the other: net dues are zero, but ₹500 is
        // still owed on this bill and it must not read as clear.
        BillPaid(bill: _bill(2, 1, 500, DateTime(2026, 5, 2)), paidPaise: 0),
      ];
      final s = buildDashboardSummary([d], bills);
      final row = s.balances.first;
      expect(row.pendingPaise, 0, reason: 'the net is zero');
      expect(row.hasPending, isFalse);
      expect(row.unsettledCount, 1);
      expect(row.fullySettled, isFalse,
          reason: 'one bill is still unpaid, so the row is not clear');
    });
  });
}
