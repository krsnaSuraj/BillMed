import 'package:flutter_test/flutter_test.dart';
import 'package:billmed/database/database.dart';
import 'package:billmed/models/bill_status.dart';
import 'package:drift/native.dart';

void main() {
  late BillMedDatabase db;

  setUp(() {
    db = BillMedDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedDistributor(String name) =>
      db.addDistributor(DistributorsCompanion.insert(name: name));

  Future<(int, int)> seedBillWithPayment({
    required int distId,
    required String billNo,
    required int amountPaise,
    List<int> payments = const [],
    DateTime? date,
  }) async {
    final billId = await db.addBill(BillsCompanion.insert(
      distributorId: distId,
      billNumber: billNo,
      billDate: date ?? DateTime(2026, 1, 10),
      amountPaise: amountPaise,
    ));
    for (final p in payments) {
      await db.addPayment(PaymentsCompanion.insert(
        billId: billId,
        paymentDate: DateTime(2026, 1, 20),
        amountPaise: p,
        mode: 'Cash',
      ));
    }
    return (billId, payments.fold(0, (a, b) => a + b));
  }

  group('money math', () {
    test('total paid sums exactly in integer paise', () async {
      final distId = await seedDistributor('Supplier A');
      final (billId, _) = await seedBillWithPayment(
        distId: distId,
        billNo: 'INV-001',
        amountPaise: 100075,
        payments: [50000, 25000, 25075],
      );
      expect(await db.getTotalPaidForBill(billId), 100075);
    });

    test('partial payment leaves remainder', () async {
      final distId = await seedDistributor('Supplier B');
      final (billId, _) = await seedBillWithPayment(
        distId: distId,
        billNo: 'INV-002',
        amountPaise: 50000,
        payments: [12345],
      );
      final bp = await db.getBillWithPaid(billId);
      expect(bp!.paidPaise, 12345);
      expect(bp.remainingPaise, 37655);
      expect(bp.status.label, 'Partial');
    });

    test('overpayment reports overpaid and clamps remaining to zero', () async {
      final distId = await seedDistributor('Supplier C');
      final (billId, _) = await seedBillWithPayment(
        distId: distId,
        billNo: 'INV-003',
        amountPaise: 10000,
        payments: [12500],
      );
      final bp = await db.getBillWithPaid(billId);
      expect(bp!.status.label, 'Overpaid');
      expect(bp.remainingPaise, 0);
    });
  });

  group('cascade deletes', () {
    test('deleteBillCascade removes payments too', () async {
      final distId = await seedDistributor('Supplier D');
      final (billId, _) = await seedBillWithPayment(
        distId: distId,
        billNo: 'INV-004',
        amountPaise: 100000,
        payments: [40000],
      );
      await db.deleteBillCascade(billId);
      expect(await db.getBill(billId), isNull);
      expect(await db.getPaymentsByBill(billId), isEmpty);
    });

    test('deleteDistributorCascade removes everything atomically', () async {
      final distId = await seedDistributor('Supplier E');
      await seedBillWithPayment(
          distId: distId, billNo: 'A', amountPaise: 1000, payments: [500]);
      await seedBillWithPayment(
          distId: distId, billNo: 'B', amountPaise: 2000, payments: [600]);

      await db.deleteDistributorCascade(distId);

      expect(await db.getDistributor(distId), isNull);
      final billsLeft = await db.getBillsByDistributor(distId);
      expect(billsLeft, isEmpty);
      final allPayments = await db.getAllPayments();
      expect(allPayments, isEmpty);
    });
  });

  group('duplicate bill number guard', () {
    test('detects duplicate case-insensitively within same supplier', () async {
      final distId = await seedDistributor('Supplier F');
      await seedBillWithPayment(
          distId: distId, billNo: 'inv/2026/01', amountPaise: 100);
      expect(
        await db.billNumberExistsForDistributor(distId, 'INV/2026/01'),
        isTrue,
      );
      expect(
        await db.billNumberExistsForDistributor(distId, 'INV/2026/02'),
        isFalse,
      );
    });

    test('same number allowed across different suppliers', () async {
      final d1 = await seedDistributor('S1');
      final d2 = await seedDistributor('S2');
      await seedBillWithPayment(distId: d1, billNo: 'X-1', amountPaise: 100);
      expect(await db.billNumberExistsForDistributor(d2, 'X-1'), isFalse);
    });

    test('excludeBillId lets editing keep own number', () async {
      final d1 = await seedDistributor('S3');
      final (billId, _) = await seedBillWithPayment(
          distId: d1, billNo: 'KEEP-1', amountPaise: 100);
      expect(
        await db.billNumberExistsForDistributor(d1, 'KEEP-1',
            excludeBillId: billId),
        isFalse,
      );
    });
  });

  group('watchAllBillsWithPaid', () {
    test('returns live updates ordered newest first', () async {
      final distId = await seedDistributor('Watcher');
      await seedBillWithPayment(
          distId: distId,
          billNo: 'OLD',
          amountPaise: 100,
          date: DateTime(2026, 1, 1));
      await seedBillWithPayment(
          distId: distId,
          billNo: 'NEW',
          amountPaise: 200,
          date: DateTime(2026, 2, 1));

      final first = await db.watchAllBillsWithPaid().first;
      expect(first.length, 2);
      expect(first.first.bill.billNumber, 'NEW');

      await db.addPayment(PaymentsCompanion.insert(
        billId: first.last.bill.id,
        paymentDate: DateTime(2026, 2, 5),
        amountPaise: 100,
        mode: 'UPI',
      ));

      final second = await db.watchAllBillsWithPaid().first;
      final updated = second.firstWhere((b) => b.bill.billNumber == 'OLD');
      expect(updated.paidPaise, 100);
      expect(updated.status.isSettled, isTrue);
    });

    test('raw-query date reconstruction matches drift typed path (regression)',
        () async {
      final distId = await seedDistributor('DateCheck');
      final billDay = DateTime(2026, 3, 15);
      final (billId, _) = await seedBillWithPayment(
        distId: distId,
        billNo: 'DATE-1',
        amountPaise: 500,
        date: billDay,
      );

      final viaRawQuery = await db.watchAllBillsWithPaid().first;
      final viaTypedPath = await db.getBill(billId);

      expect(viaTypedPath!.billDate.day, billDay.day,
          reason: 'typed drift path must preserve wall-clock day');
      expect(viaRawQuery.first.bill.billDate.day, billDay.day,
          reason: 'custom SELECT must reconstruct local date identically');
      expect(viaRawQuery.first.bill.billDate.month, billDay.month);
      expect(viaRawQuery.first.bill.billDate.year, billDay.year);
    });
  });

  group('overdue boundary via live query (wall-clock)', () {
    test('40-day-old unpaid bill is overdue; 5-day-old is not', () async {
      final distId = await seedDistributor('OverdueBounds');
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await seedBillWithPayment(
        distId: distId,
        billNo: 'OLD-40',
        amountPaise: 1000,
        date: day.subtract(const Duration(days: 40)),
      );
      await seedBillWithPayment(
        distId: distId,
        billNo: 'NEW-5',
        amountPaise: 2000,
        date: day.subtract(const Duration(days: 5)),
      );

      // NOTE: BillPaid.isOverdue closes over DateTime.now() internally
      // (isBillOverdue's default `now`), so these bounds are relative to the
      // run date by design — no fixed dates, no flakiness.
      final all = await db.watchAllBillsWithPaid().first;
      final old = all.firstWhere((b) => b.bill.billNumber == 'OLD-40');
      final fresh = all.firstWhere((b) => b.bill.billNumber == 'NEW-5');
      expect(old.isOverdue, isTrue);
      expect(fresh.isOverdue, isFalse);
    });

    test('settled old bill is never overdue', () async {
      final distId = await seedDistributor('OverdueSettled');
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      await seedBillWithPayment(
        distId: distId,
        billNo: 'OLD-PAID',
        amountPaise: 1000,
        payments: [1000],
        date: day.subtract(const Duration(days: 60)),
      );
      final all = await db.watchAllBillsWithPaid().first;
      expect(all.single.isOverdue, isFalse);
    });
  });

  group('deleteDistributorCascade edge', () {
    test('supplier with zero bills deletes cleanly', () async {
      final distId = await seedDistributor('Empty Supplier');
      await db.deleteDistributorCascade(distId);
      expect(await db.getDistributor(distId), isNull);
      expect(await db.getBillsByDistributor(distId), isEmpty);
    });
  });

  group('billNumberExistsForDistributor exact-match semantics', () {
    test('documents actual behavior: case-insensitive, space-sensitive',
        () async {
      final distId = await seedDistributor('Unicode Guard');
      await seedBillWithPayment(
          distId: distId, billNo: 'INV-1', amountPaise: 100);

      // Case is folded on both sides (SQLite UPPER + Dart toUpperCase).
      expect(await db.billNumberExistsForDistributor(distId, 'inv-1'), isTrue);
      expect(await db.billNumberExistsForDistributor(distId, 'Inv-1'), isTrue);

      // ACTUAL behavior: no trimming anywhere — padded input does NOT match.
      // Documented (not wished): callers must trim before insert/lookup.
      expect(await db.billNumberExistsForDistributor(distId, '  INV-1  '),
          isFalse);
      expect(
          await db.billNumberExistsForDistributor(distId, 'INV-1 '), isFalse);
    });

    test('unicode numbers match themselves; stored value is verbatim',
        () async {
      final distId = await seedDistributor('Unicode Verbatim');
      await seedBillWithPayment(
          distId: distId, billNo: 'बिल-१२३', amountPaise: 100);
      final bills = await db.getBillsByDistributor(distId);
      expect(bills.single.billNumber, 'बिल-१२३');
      expect(
          await db.billNumberExistsForDistributor(distId, 'बिल-१२३'), isTrue);
      // A different unicode string is not a false positive.
      expect(
          await db.billNumberExistsForDistributor(distId, 'बिल-१२४'), isFalse);
    });
  });
}
