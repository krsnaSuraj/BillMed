// Bill operations end to end, against a REAL in-memory drift DB:
//   - the per-supplier duplicate-number guard when EDITING (another bill's
//     number, and the bill's own number),
//   - deleting a payment and restoring the exact row through Undo,
//   - live invalidation of the watched streams (deleteBillCascade,
//     deleteDistributorCascade) and of the screens bound to them.
//
// Harness rules (see widget_harness.dart): no pumpAndSettle() — the loading
// shimmer repeats forever — bounded pumpUntil* pumps only, tallSurface, and an
// explicit disposeTree() at the end of every test to flush drift's
// stream-cancel timer.
import 'package:billmed/database/database.dart';
import 'package:billmed/screens/bills/add_bill_screen.dart';
import 'package:billmed/screens/bills/bill_detail_screen.dart';
import 'package:billmed/screens/distributors/distributor_detail_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_harness.dart';

/// Real-time bounded wait for a stream emission.
///
/// The two stream tests below run as plain `test()`s, outside the widget fake
/// clock: awaiting a drift stream inside `testWidgets` deadlocks, because drift
/// schedules its stream work on timers that the fake clock only fires when the
/// test pumps — and the test is blocked awaiting that work.
Future<void> _waitFor(
  bool Function() done, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!done() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// Bill/payment dates are always relative to "now" so the suite never depends
/// on the wall clock, and nothing is overdue by accident.
DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

Future<int> _supplier(BillMedDatabase db, String name) =>
    db.addDistributor(DistributorsCompanion.insert(name: name));

Future<int> _bill(
  BillMedDatabase db, {
  required int distributorId,
  required String number,
  required int amountPaise,
  required int daysAgo,
}) =>
    db.addBill(BillsCompanion.insert(
      distributorId: distributorId,
      billNumber: number,
      billDate: _daysAgo(daysAgo),
      amountPaise: amountPaise,
    ));

/// The editor pushed on top of a plain base route. A successful save then
/// reads as "the editor popped back to LEDGER" — a pop of the app's only route
/// would not be observable at all. Routes below the opaque top route are
/// offstage, so `find.text('LEDGER')` matches only when nothing covers it.
Widget _editorOverLedger(Widget editor, BillMedDatabase db) => wrapWithDb(
      Navigator(
        onGenerateInitialRoutes: (_, __) => [
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Center(child: Text('LEDGER'))),
          ),
          MaterialPageRoute<void>(builder: (_) => editor),
        ],
      ),
      db,
    );

/// Pumps (bounded) until [finder] matches exactly one widget that sits inside
/// the viewport, then lets the entrance animation finish and taps it. A modal
/// bottom sheet and a SnackBar are both already in the tree — and inside an
/// active IgnorePointer — on the first frames of their entrance, while they
/// are still translated below the screen.
Future<void> _tapSheet(WidgetTester tester, Finder finder) async {
  final Size surface = tester.view.physicalSize / tester.view.devicePixelRatio;
  await pumpUntil(tester, () {
    if (finder.evaluate().length != 1) return false;
    final Rect rect = tester.getRect(finder);
    return rect.top >= 0 && rect.bottom <= surface.height;
  });
  await tester.pump(const Duration(milliseconds: 350));
  await tester.tap(finder);
}

/// Reads a bill's payments while pumping (bounded), until [done] accepts the
/// rows. Undo re-inserts through drift's own queue, so the assertion has to
/// wait for the row itself, not merely for a frame to land.
Future<List<Payment>> _paymentsUntil(
  WidgetTester tester,
  BillMedDatabase db,
  int billId,
  bool Function(List<Payment>) done,
) async {
  var rows = await db.getPaymentsByBill(billId);
  for (var i = 0; i < 60 && !done(rows); i++) {
    await tester.pump(const Duration(milliseconds: 100));
    rows = await db.getPaymentsByBill(billId);
  }
  return rows;
}

int _byAmount(Payment a, Payment b) => a.amountPaise.compareTo(b.amountPaise);

void main() {
  // ── 1 · the duplicate-number guard on edit ────────────────────────────────

  testWidgets('editing a bill cannot steal another bill\'s number',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final alpha = await _supplier(db, 'Alpha');
    final inv1 = await _bill(db,
        distributorId: alpha,
        number: 'INV-001',
        amountPaise: 100000,
        daysAgo: 3);
    final inv2 = await _bill(db,
        distributorId: alpha,
        number: 'INV-002',
        amountPaise: 50000,
        daysAgo: 2);
    final bill2 = (await db.getBill(inv2))!;

    await tester.pumpWidget(
      _editorOverLedger(AddBillScreen(editBill: bill2), db),
    );
    await pumpUntilVisible(tester, find.text('Update Bill'));
    expect(find.text('LEDGER'), findsNothing);

    // Lower case on purpose: the guard must be case-insensitive, so 'inv-001'
    // still collides with the other bill's 'INV-001'.
    await tester.enterText(find.byType(TextFormField).first, 'inv-001');
    await tester.pump();
    await tester.tap(find.text('Update Bill'));
    await pumpUntilVisible(
        tester, find.text('This bill number already exists for this supplier'));

    // The user is told…
    expect(find.text('This bill number already exists for this supplier'),
        findsOneWidget);
    // …and the other bill's number is not silently rewritten onto this row.
    expect((await db.getBill(inv2))!.billNumber, 'INV-002');
    // The row that owns INV-001 is untouched too.
    expect((await db.getBill(inv1))!.billNumber, 'INV-001');
    expect((await db.getBill(inv2))!.amountPaise, 50000);
    // Still on the editor: a rejected save never pops.
    expect(find.text('Update Bill'), findsOneWidget);
    expect(find.text('LEDGER'), findsNothing);
    await disposeTree(tester);
  });

  // ── 2 · the same guard must exclude the bill being edited ─────────────────

  testWidgets('saving an edit does not trip the guard on its own number',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final alpha = await _supplier(db, 'Alpha');
    final inv2 = await _bill(db,
        distributorId: alpha,
        number: 'INV-002',
        amountPaise: 50000,
        daysAgo: 2);
    final bill2 = (await db.getBill(inv2))!;

    await tester.pumpWidget(
      _editorOverLedger(AddBillScreen(editBill: bill2), db),
    );
    await pumpUntilVisible(tester, find.text('Update Bill'));

    // Field order on AddBillScreen: 0 = Bill Number, 1 = Amount, 2 = Notes.
    // The number is deliberately left alone — it is the row's own number.
    final numberField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(numberField.controller!.text, 'INV-002');
    await tester.enterText(find.byType(TextFormField).at(1), '750');
    await tester.pump();

    await tester.tap(find.text('Update Bill'));
    // A successful save pops the editor back to the ledger under it.
    await pumpUntilVisible(tester, find.text('LEDGER'));

    expect(find.text('This bill number already exists for this supplier'),
        findsNothing);
    final saved = (await db.getBill(inv2))!;
    expect(saved.billNumber, 'INV-002', reason: 'the row keeps its number');
    expect(saved.amountPaise, 75000, reason: 'the edit really was saved');
    await disposeTree(tester);
  });

  // ── 3 · delete a payment, then Undo ───────────────────────────────────────

  testWidgets('deleting a payment and tapping Undo restores the exact row',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final alpha = await _supplier(db, 'Alpha');
    final billId = await _bill(db,
        distributorId: alpha,
        number: 'INV-900',
        amountPaise: 100000,
        daysAgo: 4);
    // Older payment first: the ledger sorts by payment date, so the ₹400 Cash
    // row is the first 'Payment options' menu on screen.
    await db.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: _daysAgo(3),
      amountPaise: 40000,
      mode: 'Cash',
      referenceNo: const Value('R1'),
      notes: const Value('Part settlement'),
    ));
    final upiId = await db.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: _daysAgo(1),
      amountPaise: 10000,
      mode: 'UPI',
      referenceNo: const Value('R2'),
      notes: const Value('Balance carried'),
    ));
    final seeded = await db.getPaymentsByBill(billId);
    expect(seeded, hasLength(2));

    await tester.pumpWidget(wrapWithDb(BillDetailScreen(billId: billId), db));
    await pumpUntilVisible(tester, find.text('Paid ₹500 · Due ₹500'));
    expect(find.byTooltip('Payment options'), findsNWidgets(2));

    // Delete the ₹400 Cash payment through its own row menu.
    await tester.tap(find.byTooltip('Payment options').first);
    await _tapSheet(tester, find.text('Delete'));
    await _tapSheet(tester, find.widgetWithText(FilledButton, 'Delete'));

    // The money visibly moved out of "paid".
    await pumpUntilVisible(tester, find.text('Paid ₹100 · Due ₹900'));
    final afterDelete =
        await _paymentsUntil(tester, db, billId, (rows) => rows.length == 1);
    expect(afterDelete.single.id, upiId,
        reason: 'the Cash ₹400 row is the one that was deleted');
    expect(find.byTooltip('Payment options'), findsOneWidget);

    // Undo puts it back.
    await _tapSheet(tester, find.text('Undo'));
    await pumpUntilVisible(tester, find.text('Paid ₹500 · Due ₹500'));
    final restored =
        await _paymentsUntil(tester, db, billId, (rows) => rows.length == 2);

    expect(restored, hasLength(2), reason: 'Undo restores one row, not zero');
    expect(restored.map((p) => p.amountPaise).reduce((a, b) => a + b), 50000);

    // Field-for-field, not just the total: the restored rows must be the rows
    // that were deleted.
    final expected = [...seeded]..sort(_byAmount);
    final actual = [...restored]..sort(_byAmount);
    for (var i = 0; i < 2; i++) {
      final String row = 'payment $i (₹${expected[i].amountPaise ~/ 100})';
      expect(actual[i].billId, expected[i].billId, reason: row);
      expect(actual[i].amountPaise, expected[i].amountPaise, reason: row);
      expect(actual[i].mode, expected[i].mode, reason: row);
      expect(actual[i].referenceNo, expected[i].referenceNo, reason: row);
      expect(actual[i].notes, expected[i].notes, reason: row);
      expect(actual[i].paymentDate, expected[i].paymentDate, reason: row);
    }
    // Both original amounts are present, in the original modes (ascending by
    // amount, the order [actual] was just sorted into).
    expect(actual.map((p) => '${p.mode}:${p.amountPaise}:${p.referenceNo}'),
        ['UPI:10000:R2', 'Cash:40000:R1']);
    await disposeTree(tester);
  });

  // ── 4 · the watched bills stream is live ──────────────────────────────────

  test('watchAllBillsWithPaid re-emits on the SAME subscription', () async {
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final alpha = await _supplier(db, 'Alpha');
    final inv1 = await _bill(db,
        distributorId: alpha,
        number: 'INV-001',
        amountPaise: 100000,
        daysAgo: 3);
    final inv2 = await _bill(db,
        distributorId: alpha,
        number: 'INV-002',
        amountPaise: 50000,
        daysAgo: 2);
    await db.addPayment(PaymentsCompanion.insert(
      billId: inv2,
      paymentDate: _daysAgo(1),
      amountPaise: 10000,
      mode: 'Cash',
    ));

    final emissions = <List<BillPaid>>[];
    final sub = db.watchAllBillsWithPaid().listen(emissions.add);
    addTearDown(sub.cancel);
    await _waitFor(() => emissions.isNotEmpty);
    expect(emissions, isNotEmpty,
        reason: 'the watched query must emit its first list');
    expect(emissions.last, hasLength(2));
    expect(emissions.last.first.paidPaise, 10000,
        reason: 'the join reports the paid total of INV-002');
    final first = emissions.last;

    await db.deleteBillCascade(inv2);
    // Bounded wait for the SAME subscription to see the smaller list.
    await _waitFor(() => emissions.isNotEmpty && emissions.last.length == 1);

    expect(await db.getAllBills(), hasLength(1), reason: 'ground truth');
    expect(emissions.length, greaterThanOrEqualTo(2),
        reason: 'the delete must invalidate the watched query, not just the '
            'next fresh read');
    expect(emissions.last, isNot(same(first)));
    expect(emissions.last, hasLength(1));
    expect(emissions.last.single.bill.id, inv1);
    expect(emissions.last.single.bill.billNumber, 'INV-001');
  });

  // ── 5 · the supplier cascade is reflected live ────────────────────────────

  test('deleteDistributorCascade empties the watched streams live', () async {
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final alpha = await _supplier(db, 'Alpha');
    final beta = await _supplier(db, 'Beta');
    await _bill(db,
        distributorId: alpha, number: 'A-001', amountPaise: 100000, daysAgo: 3);
    final alphaBill2 = await _bill(db,
        distributorId: alpha, number: 'A-002', amountPaise: 50000, daysAgo: 2);
    await db.addPayment(PaymentsCompanion.insert(
      billId: alphaBill2,
      paymentDate: _daysAgo(1),
      amountPaise: 10000,
      mode: 'Cash',
    ));
    await _bill(db,
        distributorId: beta, number: 'B-001', amountPaise: 20000, daysAgo: 2);

    final bills = <List<BillPaid>>[];
    final dists = <List<Distributor>>[];
    final billSub = db.watchAllBillsWithPaid().listen(bills.add);
    final distSub = db.watchAllDistributors().listen(dists.add);
    addTearDown(billSub.cancel);
    addTearDown(distSub.cancel);
    await _waitFor(() => bills.isNotEmpty && dists.isNotEmpty);
    expect(bills, isNotEmpty, reason: 'the bills stream must emit');
    expect(dists, isNotEmpty, reason: 'the distributors stream must emit');
    expect(bills.last, hasLength(3));
    expect(dists.last, hasLength(2));

    await db.deleteDistributorCascade(alpha);
    await _waitFor(
      () => dists.last.length == 1 && bills.last.length == 1,
    );

    // The distributors subscription loses the supplier…
    expect(dists.last.where((d) => d.id == alpha), isEmpty,
        reason: 'the watched distributor list must drop the deleted supplier');
    expect(dists.last.single.id, beta);
    // …and the bills subscription must lose their bills (and payments) with
    // it: the cascade really deleted them, so the SAME subscription has to
    // re-emit a shorter list.
    expect(bills.last, hasLength(1),
        reason: 'deleteDistributorCascade deletes bills/payments with raw '
            'customStatement(), which drift does not treat as a table update — '
            'so watchAllBillsWithPaid() never re-emits and the UI keeps showing '
            'bills of a supplier that no longer exists');
    expect(bills.last.single.bill.billNumber, 'B-001');
    expect(await db.getBillsByDistributor(alpha), isEmpty,
        reason: 'ground truth: the rows really are gone');
  });

  // ── 6 · supplier deleted while its detail page is open ────────────────────

  testWidgets('a supplier deleted elsewhere leaves the detail page ghosted',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final alpha = await _supplier(db, 'Alpha');
    final beta = await _supplier(db, 'Beta');
    await _bill(db,
        distributorId: alpha, number: 'A-001', amountPaise: 100000, daysAgo: 3);
    await _bill(db,
        distributorId: alpha, number: 'A-002', amountPaise: 50000, daysAgo: 2);
    await _bill(db,
        distributorId: beta, number: 'B-001', amountPaise: 20000, daysAgo: 2);

    final alphaRow = (await db.getDistributor(alpha))!;
    await tester.pumpWidget(
      wrapWithDb(DistributorDetailScreen(distributor: alphaRow), db),
    );
    await pumpUntilVisible(tester, find.text('#A-001'));
    expect(find.text('#A-002'), findsOneWidget);

    await db.deleteDistributorCascade(alpha);
    await pumpUntilVisible(
        tester, find.text('This supplier no longer exists.'));

    // The page says so instead of showing a live-looking empty ledger…
    expect(find.text('This supplier no longer exists.'), findsOneWidget);
    // …and none of the deleted supplier's bills are still on screen.
    expect(find.text('#A-001'), findsNothing);
    expect(find.text('#A-002'), findsNothing);
    expect(find.text('Alpha'), findsNothing);
    await disposeTree(tester);
  });

  // ── 7 · a supplier renamed elsewhere, on an already open page ─────────────

  testWidgets('a supplier renamed in the DB updates the open detail page',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final alpha = await _supplier(db, 'Old Name Traders');
    await _bill(db,
        distributorId: alpha, number: 'A-001', amountPaise: 100000, daysAgo: 3);

    // The stale snapshot the route was pushed with — the screen must not keep
    // showing it after the row changes underneath.
    final snapshot = (await db.getDistributor(alpha))!;
    await tester.pumpWidget(
      wrapWithDb(DistributorDetailScreen(distributor: snapshot), db),
    );
    await pumpUntilVisible(tester, find.text('#A-001'));
    expect(find.text('Old Name Traders'), findsWidgets);

    await db.updateDistributor(snapshot.copyWith(name: 'Renamed Traders'));
    await pumpUntilVisible(tester, find.text('Renamed Traders'));

    expect(find.text('Renamed Traders'), findsWidgets,
        reason: 'the page reads the live distributor list, not the ctor '
            'snapshot');
    expect(find.text('Old Name Traders'), findsNothing);
    // Renamed, not deleted: no ghost card, no popped route.
    expect(find.text('This supplier no longer exists.'), findsNothing);
    expect(find.text('#A-001'), findsOneWidget);
    await disposeTree(tester);
  });
}
