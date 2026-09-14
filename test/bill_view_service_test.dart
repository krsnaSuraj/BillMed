// Pure-function tests for the supplier bill view helpers — no widgets, no DB.
import 'package:billmed/database/database.dart';
import 'package:billmed/models/bill_status.dart';
import 'package:billmed/services/bill_view_service.dart';
import 'package:flutter_test/flutter_test.dart';

Bill _bill(int id, int amountPaise, DateTime date) => Bill(
      id: id,
      distributorId: 1,
      billNumber: 'INV-$id',
      billDate: date,
      amountPaise: amountPaise,
      notes: null,
      createdAt: date,
    );

void main() {
  // Wall-clock relative so the 30-day overdue rule under test stays
  // deterministic on any run date.
  final DateTime recent = DateTime.now().subtract(const Duration(days: 2));
  final DateTime exactly30 = DateTime.now().subtract(const Duration(days: 30));
  final DateTime old = DateTime.now().subtract(const Duration(days: 45));

  List<BillPaid> ledger() => [
        // unpaid, recent
        BillPaid(bill: _bill(1, 100000, recent), paidPaise: 0),
        // partial, recent
        BillPaid(bill: _bill(2, 50000, recent), paidPaise: 10000),
        // paid, recent
        BillPaid(bill: _bill(3, 20000, recent), paidPaise: 20000),
        // overpaid, recent
        BillPaid(bill: _bill(4, 30000, recent), paidPaise: 40000),
        // unpaid, overdue
        BillPaid(bill: _bill(5, 70000, old), paidPaise: 0),
        // settled long ago: never overdue
        BillPaid(bill: _bill(6, 40000, old), paidPaise: 40000),
        // exactly 30 days old: not overdue yet
        BillPaid(bill: _bill(7, 60000, exactly30), paidPaise: 0),
      ];

  List<int> ids(List<BillPaid> bills) => bills.map((b) => b.bill.id).toList();

  group('SupplierBillFilter', () {
    test('labels use the tile vocabulary', () {
      expect(SupplierBillFilter.all.label, 'All');
      expect(SupplierBillFilter.pending.label, 'Pending');
      expect(SupplierBillFilter.paid.label, 'Paid');
      expect(SupplierBillFilter.overdue.label, 'Overdue');
    });

    test('empty titles name the slice, never "no bills at all"', () {
      for (final f in SupplierBillFilter.values) {
        expect(f.emptyTitle, isNotEmpty);
      }
      // The three narrowed scopes must name themselves, so an empty filtered
      // ledger can never read as "this supplier has no bills".
      expect(SupplierBillFilter.pending.emptyTitle.toLowerCase(),
          contains('pending'));
      expect(
          SupplierBillFilter.paid.emptyTitle.toLowerCase(), contains('paid'));
      expect(SupplierBillFilter.overdue.emptyTitle.toLowerCase(),
          contains('overdue'));
      expect(SupplierBillFilter.pending.emptyTitle,
          isNot(SupplierBillFilter.all.emptyTitle));
    });
  });

  group('supplierBillCounts', () {
    test('splits the ledger row by row (the numbers are spelled out)', () {
      final counts = supplierBillCounts(ledger());
      // all 7. pending = #1 unpaid, #2 partial, #5 old unpaid, #7 30-day
      // unpaid. paid = every bill with money on it (#2 partial, #3 paid,
      // #4 overpaid, #6 old paid) — that is the set whose `Paid` lines add up
      // to the Paid tile.
      expect(counts[SupplierBillFilter.all], 7);
      expect(counts[SupplierBillFilter.pending], 4);
      expect(counts[SupplierBillFilter.paid], 4);
      expect(counts[SupplierBillFilter.overdue], 1);
    });

    test('empty ledger counts zero everywhere (no divide/throw)', () {
      final counts = supplierBillCounts(const []);
      expect(counts.length, SupplierBillFilter.values.length);
      for (final f in SupplierBillFilter.values) {
        expect(counts[f], 0, reason: 'scope ${f.label}');
      }
    });

    test('pending and paid overlap exactly on the partly-paid bills', () {
      final bills = ledger();
      final counts = supplierBillCounts(bills);
      final overlap = bills
          .where((b) =>
              SupplierBillFilter.pending.matches(b) &&
              SupplierBillFilter.paid.matches(b))
          .map((b) => b.bill.id)
          .toList();
      // #2 is partly paid: it holds paid money AND pending money, so it is
      // listed by both scopes.
      expect(overlap, [2]);
      expect(
        counts[SupplierBillFilter.pending]! + counts[SupplierBillFilter.paid]!,
        counts[SupplierBillFilter.all]! + overlap.length,
      );
      // Overdue is a strict slice of pending.
      expect(counts[SupplierBillFilter.overdue], 1);
      final overdueRows =
          bills.where(SupplierBillFilter.overdue.matches).toList();
      expect(overdueRows.single.bill.id, 5);
      expect(
        overdueRows.every(SupplierBillFilter.pending.matches),
        isTrue,
      );
    });

    test('the Paid scope sums to the Paid tile and Due to the Pending tile',
        () {
      // The tiles show Billed / Paid / Pending. Tapping one lists exactly the
      // bills behind that number, so the arithmetic has to line up.
      final bills = ledger();
      final billedTotal =
          bills.fold<int>(0, (sum, b) => sum + b.bill.amountPaise);
      final paidTotal = bills.fold<int>(0, (sum, b) => sum + b.paidPaise);
      final paidScopeTotal =
          applySupplierBillFilter(bills, SupplierBillFilter.paid)
              .fold<int>(0, (sum, b) => sum + b.paidPaise);
      expect(paidScopeTotal, paidTotal);

      final allRemaining = bills.fold<int>(
          0,
          (sum, b) =>
              sum + (b.bill.amountPaise - b.paidPaise).clamp(0, 1 << 62));
      final pendingScopeDue =
          applySupplierBillFilter(bills, SupplierBillFilter.pending)
              .fold<int>(0, (sum, b) => sum + b.remainingPaise);
      // Every bill with money still owed is in the pending scope, so the scope
      // carries the whole clamp-at-zero due total.
      expect(pendingScopeDue, allRemaining);
      expect(
          billedTotal, 100000 + 50000 + 20000 + 30000 + 70000 + 40000 + 60000);
    });
  });

  group('applySupplierBillFilter', () {
    test('all keeps every bill in order', () {
      expect(ids(applySupplierBillFilter(ledger(), SupplierBillFilter.all)),
          [1, 2, 3, 4, 5, 6, 7]);
    });

    test('pending = unpaid + partial only', () {
      expect(ids(applySupplierBillFilter(ledger(), SupplierBillFilter.pending)),
          [1, 2, 5, 7]);
    });

    test('paid = every bill with money on it, partly paid included', () {
      // Settled-only used to contradict the Paid tile: a single ₹1,000 bill
      // holding a ₹400 payment showed "Paid ₹400" beside a "Paid (0)" chip.
      expect(ids(applySupplierBillFilter(ledger(), SupplierBillFilter.paid)),
          [2, 3, 4, 6]);
    });

    test('overdue excludes exactly-30-days-old and settled old bills', () {
      expect(ids(applySupplierBillFilter(ledger(), SupplierBillFilter.overdue)),
          [5]);
    });

    test('all returns a copy, so the screen list stays intact', () {
      final source = ledger();
      final out = applySupplierBillFilter(source, SupplierBillFilter.all);
      expect(identical(out, source), isFalse);
      out.clear();
      expect(source.length, 7);
    });

    test('filtered result never mutates the source list', () {
      final source = ledger();
      applySupplierBillFilter(source, SupplierBillFilter.paid);
      expect(source.length, 7);
    });

    test('empty input yields empty output for every scope', () {
      for (final f in SupplierBillFilter.values) {
        expect(applySupplierBillFilter(const [], f), isEmpty);
      }
    });
  });

  group('sortSupplierBills', () {
    test('date DESC with id DESC tiebreak on same-day bills', () {
      final sameDay = DateTime(2026, 5, 1);
      final bills = [
        BillPaid(bill: _bill(7, 100, sameDay), paidPaise: 0),
        BillPaid(bill: _bill(3, 100, DateTime(2026, 5, 2)), paidPaise: 0),
        BillPaid(bill: _bill(9, 100, sameDay), paidPaise: 0),
        BillPaid(bill: _bill(1, 100, DateTime(2026, 4, 30)), paidPaise: 0),
      ];
      expect(ids(sortSupplierBills(bills)), [3, 9, 7, 1]);
    });

    test('does not mutate the caller list', () {
      final bills = [
        BillPaid(bill: _bill(1, 100, DateTime(2026, 5, 1)), paidPaise: 0),
        BillPaid(bill: _bill(2, 100, DateTime(2026, 5, 9)), paidPaise: 0),
      ];
      sortSupplierBills(bills);
      expect(ids(bills), [1, 2]);
    });

    test('single and empty lists are passthrough', () {
      expect(sortSupplierBills(const []), isEmpty);
      final one = [
        BillPaid(bill: _bill(4, 100, DateTime(2026, 5, 1)), paidPaise: 0),
      ];
      expect(ids(sortSupplierBills(one)), [4]);
    });

    test('filter then sort = sort then filter (order-independent)', () {
      final bills = ledger();
      final a = sortSupplierBills(
          applySupplierBillFilter(bills, SupplierBillFilter.pending));
      final b = applySupplierBillFilter(
          sortSupplierBills(bills), SupplierBillFilter.pending);
      expect(ids(a), ids(b));
      // date DESC (recent 2d → 30d → 45d), id DESC on the same-day pair.
      expect(ids(a), [2, 1, 7, 5]);
    });

    test('overdue scope derives from the same 30-day constant as status', () {
      final boundary = DateTime.now().subtract(
        const Duration(days: overdueDays + 1),
      );
      final bills = [
        BillPaid(bill: _bill(1, 1000, boundary), paidPaise: 0),
      ];
      expect(bills.single.isOverdue, isTrue);
      expect(
          applySupplierBillFilter(bills, SupplierBillFilter.overdue).length, 1);
    });
  });
}
