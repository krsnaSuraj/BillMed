import 'package:billmed/database/database.dart';
import 'package:billmed/models/bill_status.dart';
import 'package:billmed/screens/dashboard/dashboard_screen.dart';
import 'package:billmed/services/summary_service.dart';
import 'package:billmed/utils/money.dart';
import 'package:billmed/utils/text.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

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

const _boundaries = [
  0,
  1,
  5,
  9,
  10,
  99,
  100,
  101,
  999,
  1000,
  9999,
  10000,
  99999,
  100000,
  9999999,
  123456789,
  99999999999,
];

void main() {
  group('money adversarial inputs (as-code-does)', () {
    test('each adversarial string maps to its documented value', () {
      final cases = <String, int>{
        '1e3': 0,
        '+5': 0,
        '--5': 0,
        '5..5': 0,
        ',,,': 0,
        '1,2,3': 12300,
        '0.001': 0,
        // 3 decimals never reach rounding: regex allows max 2 decimals.
        '0.005': 0,
        '999999999999': 0,
        '₹100': 0,
        '.5': 0,
        // Commas are stripped blindly, so odd groupings still parse.
        '1,,000': 100000,
      };
      cases.forEach((input, expected) {
        expect(rupeesInputToPaise(input), expected, reason: 'input "$input"');
      });
    });

    test('100-char numeric string is rejected', () {
      final long = List.filled(100, '9').join();
      expect(long.length, 100);
      expect(rupeesInputToPaise(long), 0);
    });

    test('paise round-trip over boundaries is exact', () {
      for (final paise in _boundaries) {
        final editable = paiseToEditableString(paise);
        expect(rupeesInputToPaise(editable), paise,
            reason: 'paise=$paise ("$editable")');
      }
    });
  });

  group('plural', () {
    test('0/1/2 default English plural', () {
      expect(plural(0, 'bill'), '0 bills');
      expect(plural(1, 'bill'), '1 bill');
      expect(plural(2, 'bill'), '2 bills');
    });

    test('custom plural form', () {
      expect(plural(1, 'child', 'children'), '1 child');
      expect(plural(0, 'child', 'children'), '0 children');
      expect(plural(2, 'child', 'children'), '2 children');
    });
  });

  group('summary edge cases', () {
    test('empty distributors and bills give zero summary', () {
      final s = buildDashboardSummary(const [], const []);
      expect(s.totalDistributors, 0);
      expect(s.totalBills, 0);
      expect(s.totalBilledPaise, 0);
      expect(s.totalPaidPaise, 0);
      expect(s.totalPendingPaise, 0);
      expect(s.overdueCount, 0);
      expect(s.balances, isEmpty);
    });

    test('fully settled bills: pending 0 with settled counts', () {
      final d = _dist(1, 'Settled');
      final bills = [
        BillPaid(bill: _bill(1, 1, 50000, DateTime(2026, 5, 1)), paidPaise: 50000),
        BillPaid(bill: _bill(2, 1, 25000, DateTime(2026, 5, 2)), paidPaise: 25000),
      ];
      final s = buildDashboardSummary([d], bills, now: DateTime(2026, 5, 10));
      expect(s.totalBills, 2);
      expect(s.totalBilledPaise, 75000);
      expect(s.totalPaidPaise, 75000);
      expect(s.totalPendingPaise, 0);
      expect(s.overdueCount, 0);
      expect(s.balances.single.settledCount, 2);
      expect(s.balances.single.billCount, 2);
      expect(s.balances.single.pendingPaise, 0);
      expect(s.balances.single.hasPending, isFalse);
    });

    test('overpay bill: remaining 0, overpaid, pending 0, totals preserved', () {
      final d = _dist(1, 'Credit');
      final bp = BillPaid(
        bill: _bill(1, 1, 10000, DateTime(2026, 5, 1)),
        paidPaise: 15000,
      );
      expect(bp.status, BillStatus.overpaid);
      expect(bp.remainingPaise, 0);
      final s = buildDashboardSummary([d], [bp], now: DateTime(2026, 5, 10));
      expect(s.balances.single.pendingPaise, 0);
      expect(s.totalPendingPaise, 0);
      expect(s.totalBilledPaise, 10000);
      expect(s.totalPaidPaise, 15000);
    });

    test('deterministic now-param for 2026-05-01 unpaid bill', () {
      final d = _dist(1, 'Timey');
      final bills = [
        BillPaid(bill: _bill(1, 1, 1000, DateTime(2026, 5, 1)), paidPaise: 0),
      ];
      final past = buildDashboardSummary([d], bills, now: DateTime(2026, 5, 2));
      expect(past.overdueCount, 0);
      expect(past.balances.single.overdueCount, 0);
      final future = buildDashboardSummary([d], bills, now: DateTime(2026, 7, 1));
      expect(future.overdueCount, 1);
      expect(future.balances.single.overdueCount, 1);
    });

    test('Dec to Jan month wrap in monthlyPurchasePaise', () {
      final now = DateTime(2026, 1, 15);
      final bills = [
        BillPaid(
            bill: _bill(1, 1, 10000, DateTime(2025, 12, 20)), paidPaise: 0),
        BillPaid(bill: _bill(2, 1, 20000, DateTime(2026, 1, 5)), paidPaise: 0),
      ];
      final totals = monthlyPurchasePaise(bills, now: now);
      // Last 6 months from Jan 2026: Aug, Sep, Oct, Nov, Dec, Jan.
      expect(totals, hasLength(6));
      expect(totals, [0.0, 0.0, 0.0, 0.0, 10000.0, 20000.0]);
    });
  });

  group('bill_status boundaries', () {
    final now = DateTime(2026, 6, 15);

    test('exactly 30 days is not overdue, 31 days is', () {
      final day30 = DateTime(2026, 5, 16);
      final day31 = DateTime(2026, 5, 15);
      expect(isBillOverdue(day30, 10000, 0, now: now), isFalse);
      expect(isBillOverdue(day31, 10000, 0, now: now), isTrue);
    });

    test('settled bills exempt even when old', () {
      final old = DateTime(2026, 1, 1);
      expect(isBillOverdue(old, 10000, 10000, now: now), isFalse);
      expect(isBillOverdue(old, 10000, 12000, now: now), isFalse);
    });

    test('future bill never overdue', () {
      expect(isBillOverdue(DateTime(2026, 6, 20), 10000, 0, now: now), isFalse);
      expect(isBillOverdue(DateTime(2026, 7, 1), 10000, 0, now: now), isFalse);
    });
  });

  group('database edge cases', () {
    late BillMedDatabase db;

    setUp(() {
      db = BillMedDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Future<int> seedDistributor(String name) =>
        db.addDistributor(DistributorsCompanion.insert(name: name));

    Future<int> seedBill({
      required int distId,
      required String billNo,
      required int amountPaise,
      DateTime? date,
    }) {
      return db.addBill(BillsCompanion.insert(
        distributorId: distId,
        billNumber: billNo,
        billDate: date ?? DateTime(2026, 1, 10),
        amountPaise: amountPaise,
      ));
    }

    test('overdue boundary via watchAllBillsWithPaid', () async {
      final distId = await seedDistributor('Bounds');
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await seedBill(
        distId: distId,
        billNo: 'OLD-40',
        amountPaise: 1000,
        date: day.subtract(const Duration(days: 40)),
      );
      await seedBill(
        distId: distId,
        billNo: 'NEW-5',
        amountPaise: 2000,
        date: day.subtract(const Duration(days: 5)),
      );
      final all = await db.watchAllBillsWithPaid().first;
      final old = all.firstWhere((b) => b.bill.billNumber == 'OLD-40');
      final fresh = all.firstWhere((b) => b.bill.billNumber == 'NEW-5');
      expect(old.isOverdue, isTrue);
      expect(fresh.isOverdue, isFalse);
    });

    test('settled old bill never overdue', () async {
      final distId = await seedDistributor('Settled');
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final billId = await seedBill(
        distId: distId,
        billNo: 'OLD-PAID',
        amountPaise: 1000,
        date: day.subtract(const Duration(days: 60)),
      );
      await db.addPayment(PaymentsCompanion.insert(
        billId: billId,
        paymentDate: day,
        amountPaise: 1000,
        mode: 'Cash',
      ));
      final all = await db.watchAllBillsWithPaid().first;
      expect(all.single.isOverdue, isFalse);
    });

    test('deleteDistributorCascade on empty supplier', () async {
      final distId = await seedDistributor('Empty');
      await db.deleteDistributorCascade(distId);
      expect(await db.getDistributor(distId), isNull);
      expect(await db.getBillsByDistributor(distId), isEmpty);
    });

    test('billNumber guard case-insensitive, space-sensitive as-code-does',
        () async {
      final distId = await seedDistributor('Guard');
      await seedBill(distId: distId, billNo: 'INV-1', amountPaise: 100);
      expect(await db.billNumberExistsForDistributor(distId, 'INV-1'), isTrue);
      expect(await db.billNumberExistsForDistributor(distId, 'inv-1'), isTrue);
      expect(await db.billNumberExistsForDistributor(distId, 'Inv-1'), isTrue);
      // As-code-does: no trimming, so padded input does not match.
      expect(await db.billNumberExistsForDistributor(distId, '  INV-1  '),
          isFalse);
      expect(
          await db.billNumberExistsForDistributor(distId, 'INV-1 '), isFalse);
    });

    test('deleteBillCascade removes payments', () async {
      final distId = await seedDistributor('Cascade');
      final billId = await seedBill(
        distId: distId,
        billNo: 'INV-004',
        amountPaise: 100000,
      );
      await db.addPayment(PaymentsCompanion.insert(
        billId: billId,
        paymentDate: DateTime(2026, 1, 20),
        amountPaise: 40000,
        mode: 'Cash',
      ));
      await db.deleteBillCascade(billId);
      expect(await db.getBill(billId), isNull);
      expect(await db.getPaymentsByBill(billId), isEmpty);
    });

    test('undo-style re-insert does not trip duplicate guard', () async {
      final distId = await seedDistributor('Undo');
      final billId = await seedBill(
        distId: distId,
        billNo: 'UNDO-1',
        amountPaise: 5000,
      );
      expect(await db.billNumberExistsForDistributor(distId, 'UNDO-1'), isTrue);
      await db.deleteBillCascade(billId);
      expect(
          await db.billNumberExistsForDistributor(distId, 'UNDO-1'), isFalse);
      final reId = await seedBill(
        distId: distId,
        billNo: 'UNDO-1',
        amountPaise: 5000,
      );
      expect(await db.billNumberExistsForDistributor(distId, 'UNDO-1'), isTrue);
      final bills = await db.getBillsByDistributor(distId);
      expect(bills, hasLength(1));
      expect(bills.single.id, reId);
    });
  });

  group('overdue rail vs netted pending (documents design)', () {
    test('rail sums per-bill clamped dues, header nets overpay credit', () {
      final d = _dist(1, 'Rail');
      final old = DateTime.now().subtract(const Duration(days: 60));
      final bills = [
        // Overpaid + settled: never overdue, absorbs 5000 of dues.
        BillPaid(bill: _bill(1, 1, 10000, old), paidPaise: 15000),
        // Unpaid + ancient: overdue with 20000 remaining.
        BillPaid(bill: _bill(2, 1, 20000, old), paidPaise: 0),
      ];
      final s = buildDashboardSummary([d], bills);

      // Header nets across the supplier then clamps:
      // (10000 + 20000) - (15000 + 0) = 15000 pending.
      expect(s.totalPendingPaise, 15000);
      expect(s.balances.first.pendingPaise, 15000);
      expect(s.overdueCount, 1);

      // Dashboard overdue rail sums per-bill clamped dues of overdue
      // bills only (mirrors _OverdueRail): 0 + 20000 = 20000. It can
      // legitimately exceed the netted header — pin both so a future
      // refactor changes them consciously, not by accident.
      var railPaise = 0;
      for (final bp in bills) {
        if (bp.isOverdue) railPaise += bp.remainingPaise;
      }
      expect(railPaise, 20000);
    });
  });
}
