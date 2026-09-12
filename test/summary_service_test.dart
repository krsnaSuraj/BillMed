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
      expect(s.balances.last.hasPending, isFalse);
    });

    test('overdue counts only unsettled bills past 30 days', () {
      final d = _dist(1, 'OldDebtor');
      final now = DateTime(2026, 8, 26);
      final bills = [
        BillPaid(bill: _bill(1, 1, 1000, DateTime(2026, 7, 1)), paidPaise: 0),
        BillPaid(bill: _bill(2, 1, 2000, DateTime(2026, 8, 20)), paidPaise: 0),
        BillPaid(
            bill: _bill(3, 1, 3000, DateTime(2026, 1, 1)), paidPaise: 3000),
      ];
      final s = buildDashboardSummary([d], bills, now: now);
      expect(s.overdueCount, 1);
      expect(s.balances.first.overdueCount, 1);
    });

    test('pending clamps to zero when supplier overpaid overall', () {
      final d = _dist(1, 'CreditGuy');
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 10000, DateTime(2026, 5, 1)), paidPaise: 15000),
      ];
      final s = buildDashboardSummary([d], bills);
      expect(s.balances.first.pendingPaise, 0);
      expect(s.totalPendingPaise, 0);
    });
  });
}
