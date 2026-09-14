// Supplier detail ledger: which bills belong to the supplier, what each one
// was billed / paid / still owes, and the All / Pending / Paid / Overdue
// scopes (driven by both the tiles and the chips). Real in-memory drift DB.
import 'package:billmed/database/database.dart';
import 'package:billmed/models/bill_status.dart';
import 'package:billmed/screens/distributors/distributor_detail_screen.dart';
import 'package:billmed/widgets/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_harness.dart';

/// Alpha with one bill of every shape:
///   INV-001  ₹1,000 unpaid       (2 days ago)
///   INV-002  ₹500 with ₹100 paid (3 days ago)  → Partial
///   INV-003  ₹200 fully paid     (4 days ago)  → Paid
///   INV-004  ₹300 with ₹400 paid (5 days ago)  → Overpaid
///   INV-005  ₹700 unpaid         (45 days ago) → Overdue
/// Totals: Billed ₹2,700 · Paid ₹700 · Pending ₹2,000.
/// Scopes: All 5 · Pending 3 · Paid 2 · Overdue 1.
Future<BillMedDatabase> _seedAlpha() async {
  final db = BillMedDatabase(NativeDatabase.memory());
  final alpha =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Alpha'));
  final DateTime now = DateTime.now();
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  Future<int> bill(String number, int amountPaise, int days) =>
      db.addBill(BillsCompanion.insert(
        distributorId: alpha,
        billNumber: number,
        billDate: daysAgo(days),
        amountPaise: amountPaise,
      ));

  await bill('INV-001', 100000, 2);
  final b2 = await bill('INV-002', 50000, 3);
  final b3 = await bill('INV-003', 20000, 4);
  final b4 = await bill('INV-004', 30000, 5);
  await bill('INV-005', 70000, 45);

  Future<void> pay(int billId, int amountPaise) => db.addPayment(
        PaymentsCompanion.insert(
          billId: billId,
          paymentDate: daysAgo(1),
          amountPaise: amountPaise,
          mode: 'Cash',
        ),
      );
  await pay(b2, 10000);
  await pay(b3, 20000);
  await pay(b4, 40000);
  return db;
}

/// Supplier with a single unpaid bill (used for the empty-slice state).
Future<(BillMedDatabase, int)> _seedUnpaidOnly() async {
  final db = BillMedDatabase(NativeDatabase.memory());
  final id =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Beta'));
  await db.addBill(BillsCompanion.insert(
    distributorId: id,
    billNumber: 'B-001',
    billDate: DateTime.now().subtract(const Duration(days: 2)),
    amountPaise: 25000,
  ));
  return (db, id);
}

Future<void> _openDetail(
    WidgetTester tester, BillMedDatabase db, int id) async {
  final supplier = await db.getDistributor(id);
  await tester.pumpWidget(
    wrapWithDb(DistributorDetailScreen(distributor: supplier!), db),
  );
  await pumpUntilVisible(tester, find.textContaining('#'));
}

void main() {
  testWidgets('lists every bill of the supplier with billed / paid / due',
      (tester) async {
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('#INV-005'));

    // All five bills are present.
    for (final n in ['INV-001', 'INV-002', 'INV-003', 'INV-004', 'INV-005']) {
      expect(find.text('#$n'), findsOneWidget, reason: n);
    }

    // Per-bill arithmetic, spelled out: billed line + paid/due line.
    expect(find.textContaining('Billed ₹1,000'), findsOneWidget);
    expect(find.textContaining('Paid ₹0 · Due ₹1,000'), findsOneWidget);

    expect(find.textContaining('Billed ₹500'), findsOneWidget);
    expect(find.textContaining('Paid ₹100 · Due ₹400'), findsOneWidget);

    expect(find.textContaining('Billed ₹200'), findsOneWidget);
    expect(find.textContaining('Paid ₹200'), findsOneWidget);

    // Overpaid bill: advance instead of a due.
    expect(find.textContaining('Paid ₹400 · Advance ₹100'), findsOneWidget);
    expect(find.textContaining('Advance ₹100 · Due'), findsNothing);

    // Old unpaid bill carries the overdue suffix on the same line.
    expect(find.textContaining('Paid ₹0 · Due ₹700 · Overdue'), findsOneWidget);

    // Status chips stay per-bill and honest.
    expect(find.text('Unpaid'), findsNWidgets(2));
    expect(find.text('Partial'), findsOneWidget);
    expect(find.text('Overpaid'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets(
      'stat strip keeps a finite height so the ledger below still lays out',
      (tester) async {
    // Regression: the Billed / Paid / Pending row used to be a stretched Row
    // inside a sliver box, which offers an unbounded height. The stretched
    // spacers then demanded an infinite height, and everything below the
    // tiles — the whole bill ledger — never got laid out.
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('#INV-001'));

    expect(tester.takeException(), isNull);
    final all = tester.getSize(find.byKey(const ValueKey('supplier-tile-all')));
    final paid =
        tester.getSize(find.byKey(const ValueKey('supplier-tile-paid')));
    final pending =
        tester.getSize(find.byKey(const ValueKey('supplier-tile-pending')));
    expect(all.height.isFinite, isTrue);
    expect(all.height, greaterThan(0));
    // Stretched, not ragged: all three tiles share one height.
    expect(paid.height, all.height);
    expect(pending.height, all.height);
    // And the ledger below them is really on screen.
    expect(tester.getSize(find.text('#INV-001')).height, greaterThan(0));
    await disposeTree(tester);
  });

  testWidgets('status chips carry live counts for every slice', (tester) async {
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('All (5)'));

    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('Pending (3)'), findsOneWidget);
    // Every bill with money on it: INV-002 (partial), INV-003 (paid),
    // INV-004 (overpaid).
    expect(find.text('Paid (3)'), findsOneWidget);
    expect(find.text('Overdue (1)'), findsOneWidget);
    expect(find.textContaining(RegExp(r'of \d+')), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('Pending tile narrows the ledger to unpaid + partial bills',
      (tester) async {
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('#INV-004'));

    await tester.tap(find.byKey(const ValueKey('supplier-tile-pending')));
    await tester.pump();
    await pumpUntilGone(tester, find.text('#INV-003'));

    expect(find.text('#INV-001'), findsOneWidget);
    expect(find.text('#INV-002'), findsOneWidget);
    expect(find.text('#INV-005'), findsOneWidget);
    expect(find.text('#INV-004'), findsNothing);
    // Header count follows the filter, and says what it is a slice of.
    expect(tester.widget<SectionHeader>(find.byType(SectionHeader)).count, 3);
    expect(find.text('of 5'), findsOneWidget);
    // Chip counts stay global while a filter is active.
    expect(find.text('All (5)'), findsOneWidget);
    expect(find.text('Pending (3)'), findsOneWidget);

    // Billed tile is the way back to everything.
    await tester.tap(find.byKey(const ValueKey('supplier-tile-all')));
    await tester.pump();
    await pumpUntilVisible(tester, find.text('#INV-003'));
    expect(find.text('of 5'), findsNothing);
    expect(tester.widget<SectionHeader>(find.byType(SectionHeader)).count, 5);
    await disposeTree(tester);
  });

  testWidgets('Paid tile lists exactly the bills behind its number',
      (tester) async {
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('#INV-005'));

    await tester.tap(find.byKey(const ValueKey('supplier-tile-paid')));
    await tester.pump();
    await pumpUntilGone(tester, find.text('#INV-001'));

    // INV-002 holds a ₹100 payment, so it belongs to the Paid scope even
    // though it is only partly paid — the tile sum has to be traceable.
    expect(find.text('#INV-002'), findsOneWidget);
    expect(find.text('#INV-003'), findsOneWidget);
    expect(find.text('#INV-004'), findsOneWidget);
    expect(find.text('#INV-001'), findsNothing);
    expect(find.text('#INV-005'), findsNothing);
    expect(tester.widget<SectionHeader>(find.byType(SectionHeader)).count, 3);
    // The listed rows state ₹100 + ₹200 + ₹400 paid = the tile's ₹700.
    expect(find.textContaining('Paid ₹100 · Due ₹400'), findsOneWidget);
    expect(find.textContaining('Paid ₹200'), findsOneWidget);
    expect(find.textContaining('Paid ₹400 · Advance ₹100'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('Overdue chip shows only the bills past the 30 day rule',
      (tester) async {
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('Overdue (1)'));

    await tester.tap(find.text('Overdue (1)'));
    await tester.pump();
    await pumpUntilGone(tester, find.text('#INV-001'));

    expect(find.text('#INV-005'), findsOneWidget);
    // Only the overdue row carries the suffix, so the chip is not just a count.
    expect(find.textContaining('· Due ₹700 · Overdue'), findsOneWidget);
    expect(find.textContaining('· Overdue'), findsOneWidget);
    expect(tester.widget<SectionHeader>(find.byType(SectionHeader)).count, 1);
    await disposeTree(tester);
  });

  testWidgets('empty slice explains itself and offers the way back',
      (tester) async {
    tallSurface(tester);
    final (db, id) = await _seedUnpaidOnly();
    addTearDown(db.close);

    await _openDetail(tester, db, id);
    await pumpUntilVisible(tester, find.text('#B-001'));

    await tester.tap(find.byKey(const ValueKey('supplier-tile-paid')));
    await tester.pump();
    await pumpUntilVisible(
        tester, find.text('No paid bills for this supplier yet'));

    // Never the "this supplier has no bills" lie, and never a dead end.
    expect(find.text('This supplier has 1 bill in total.'), findsOneWidget);
    expect(find.text('No bills for this supplier yet'), findsNothing);
    expect(find.textContaining('in total'), findsOneWidget);
    expect(find.text('#B-001'), findsNothing);

    await tester.tap(find.text('Show all bills'));
    await tester.pump();
    await pumpUntilVisible(tester, find.text('#B-001'));
    expect(find.textContaining(RegExp(r'of \d+')), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('supplier with no bills keeps the add-bill state, no chips',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id =
        await db.addDistributor(DistributorsCompanion.insert(name: 'Empty'));

    await _openDetail(tester, db, id);
    await pumpUntilVisible(tester, find.text('No bills for this supplier yet'));

    expect(find.text('Add Bill'), findsOneWidget);
    // No scope chips for an empty ledger.
    expect(find.text('All (0)'), findsNothing);
    expect(find.text('Pending (0)'), findsNothing);
    // Pending tile stays honest: nothing owed reads as Clear.
    expect(find.text('Clear'), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('supplier deleted elsewhere renders the ghost card',
      (tester) async {
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('#INV-001'));

    await db.deleteDistributorCascade(1);
    await pumpUntilVisible(
        tester, find.text('This supplier no longer exists.'));
    expect(find.text('#INV-001'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('tapping a bill row opens that bill detail', (tester) async {
    tallSurface(tester);
    final db = await _seedAlpha();
    addTearDown(db.close);

    await _openDetail(tester, db, 1);
    await pumpUntilVisible(tester, find.text('#INV-001'));

    await tester.tap(find.text('#INV-001'));
    // The bill number in the detail hero only exists once the bill actually
    // loaded — 'Bill Details' alone is also the loading/error/ghost title, so
    // asserting on it would pass without any data.
    await pumpUntilVisible(tester, find.textContaining('INV-001'));
    expect(find.textContaining('INV-001'), findsWidgets);
    await disposeTree(tester);
  });

  testWidgets('long ledger renders every bill without layout errors',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id =
        await db.addDistributor(DistributorsCompanion.insert(name: 'Big'));
    for (var i = 1; i <= 25; i++) {
      await db.addBill(BillsCompanion.insert(
        distributorId: id,
        billNumber: 'INV-${i.toString().padLeft(3, '0')}',
        billDate: DateTime.now().subtract(Duration(days: i)),
        amountPaise: i * 100000,
      ));
    }

    await _openDetail(tester, db, id);
    await pumpUntilVisible(tester, find.text('All (25)'));

    expect(find.text('#INV-001'), findsOneWidget);
    expect(find.text('#INV-025'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Scroll a long list: nothing should throw mid-scroll either.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await disposeTree(tester);
  });

  testWidgets('overdue boundary: exactly 30 days old is not overdue',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id =
        await db.addDistributor(DistributorsCompanion.insert(name: 'Edge'));
    await db.addBill(BillsCompanion.insert(
      distributorId: id,
      billNumber: 'EDGE-30',
      billDate: DateTime.now().subtract(const Duration(days: overdueDays)),
      amountPaise: 100000,
    ));
    await db.addBill(BillsCompanion.insert(
      distributorId: id,
      billNumber: 'EDGE-31',
      billDate: DateTime.now().subtract(const Duration(days: overdueDays + 1)),
      amountPaise: 100000,
    ));

    await _openDetail(tester, db, id);
    await pumpUntilVisible(tester, find.text('Overdue (1)'));

    expect(find.text('#EDGE-31'), findsOneWidget);
    expect(find.text('#EDGE-30'), findsOneWidget);
    // Exactly one row carries the overdue suffix, and it is the 31-day one —
    // rendering both rows would prove nothing about the boundary.
    expect(find.textContaining('· Overdue'), findsOneWidget);
    expect(
      find.textContaining('Overdue'),
      findsWidgets,
      reason: 'chip + the single overdue row',
    );
    await tester.tap(find.text('Overdue (1)'));
    await tester.pump();
    await pumpUntilGone(tester, find.text('#EDGE-30'));
    expect(find.text('#EDGE-31'), findsOneWidget);
    await disposeTree(tester);
  });
}
