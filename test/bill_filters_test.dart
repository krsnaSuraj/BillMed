// Widget tests for BillListScreen supplier filter + sort controls.
// Same seeded DB + harness lessons as widget_flows_test.dart:
// tall surface, bounded pumps (no pumpAndSettle), explicit unmount.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:billmed/database/database.dart';
import 'package:billmed/providers/database_provider.dart';
import 'package:billmed/screens/bills/bill_list_screen.dart';

Future<BillMedDatabase> _seededDb() async {
  final db = BillMedDatabase(NativeDatabase.memory());
  final alpha =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Alpha'));
  final beta =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Beta'));
  final recent = DateTime.now().subtract(const Duration(days: 5));

  await db.addBill(BillsCompanion.insert(
    distributorId: alpha,
    billNumber: 'INV-001',
    billDate: recent,
    amountPaise: 100000,
  ));
  final b2 = await db.addBill(BillsCompanion.insert(
    distributorId: alpha,
    billNumber: 'INV-002',
    billDate: recent,
    amountPaise: 50000,
  ));
  await db.addPayment(PaymentsCompanion.insert(
    billId: b2,
    paymentDate: recent,
    amountPaise: 10000,
    mode: 'Cash',
  ));
  final b3 = await db.addBill(BillsCompanion.insert(
    distributorId: beta,
    billNumber: 'INV-003',
    billDate: recent,
    amountPaise: 20000,
  ));
  await db.addPayment(PaymentsCompanion.insert(
    billId: b3,
    paymentDate: recent,
    amountPaise: 20000,
    mode: 'UPI',
  ));
  return db;
}

Widget _wrap(Widget home, BillMedDatabase db) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: home),
    );

void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntilVisible(WidgetTester tester, Finder finder) =>
    _pumpUntil(tester, () => finder.evaluate().isNotEmpty);

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) =>
    _pumpUntil(tester, () => finder.evaluate().isEmpty);

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(Container());
  await tester.pump(const Duration(milliseconds: 50));
}

/// Sheet entrance animation needs a bounded settle before tapping options
/// (see sheets_test.dart), otherwise tap() misses and the awaited future hangs.
Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
}

double _dy(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text).first).dy;

/// The filter chips live in a lazily-built horizontal ListView: trailing
/// pills (Supplier/Sort/Reset) are only built once scrolled into view —
/// same as on a real phone. Scroll the row until the pill exists.
Future<void> _revealPill(WidgetTester tester, String label) async {
  // Anchor: any chip text currently built; at least the leftmost chip is.
  const anchors = ['All (', 'Unpaid (', 'Supplier', 'Sort:'];
  Finder row = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axis == Axis.horizontal,
  );
  for (final a in anchors) {
    final t = find.textContaining(a);
    if (t.evaluate().isNotEmpty) {
      row = find.ancestor(
        of: t.first,
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axis == Axis.horizontal,
        ),
      );
      break;
    }
  }
  await tester.scrollUntilVisible(find.text(label), 500, scrollable: row);
  await tester.pump();
}

/// Reveals a row pill, nudges the row if the pill center is still outside
/// the 800px surface, then taps. Retries instead of flaking.
Future<void> _tapPill(WidgetTester tester, String label) async {
  for (var i = 0; i < 6; i++) {
    await _revealPill(tester, label);
    final f = find.text(label);
    if (f.evaluate().isEmpty) continue;
    final dx = tester.getCenter(f).dx;
    if (dx < 0 || dx > 800) {
      await tester.drag(f, const Offset(-300, 0));
      await tester.pump();
      continue;
    }
    await tester.tap(f);
    return;
  }
  fail('could not tap pill "$label"');
}

void main() {
  testWidgets('supplier pill filters bills to that supplier + reset restores',
      (tester) async {
    _tallSurface(tester);
    final db = await _seededDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(const BillListScreen(), db));
    await _pumpUntilVisible(tester, find.text('INV-001'));

    // Supplier pill starts unfiltered.
    await _tapPill(tester, 'Supplier');
    expect(find.text('Supplier'), findsWidgets);
    await tester.pump();
    await _settleSheet(tester);

    // Sheet option 'Alpha' is the LAST 'Alpha' text: bill rows render above,
    // the modal sheet renders on top of them.
    await tester.tap(find.text('Alpha').last);
    await tester.pump();
    await _pumpUntilGone(tester, find.text('INV-003'));

    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('INV-002'), findsOneWidget);
    expect(find.text('INV-003'), findsNothing);
    // Pill now shows the active supplier + Reset appears.
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Reset'), findsOneWidget);

    await _tapPill(tester, 'Reset');
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('INV-003'));
    await _disposeTree(tester);
  });

  testWidgets('sort oldest flips order, amount sorts high-to-low flat',
      (tester) async {
    _tallSurface(tester);
    final db = await _seededDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(const BillListScreen(), db));
    await _pumpUntilVisible(tester, find.text('INV-001'));

    final monthLabel = DateFormat('MMMM yyyy')
        .format(DateTime.now().subtract(const Duration(days: 5)));

    // Default newest: INV-003 (highest id) above INV-001, month header shown.
    expect(_dy(tester, 'INV-003') < _dy(tester, 'INV-001'), isTrue);
    expect(find.text(monthLabel), findsOneWidget);

    await _revealPill(tester, 'Sort: Newest');
    await _tapPill(tester, 'Sort: Newest');
    await tester.pump();
    await _settleSheet(tester);
    await tester.tap(find.text('Oldest first'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Sort: Oldest'));

    expect(_dy(tester, 'INV-001') < _dy(tester, 'INV-003'), isTrue);
    expect(find.text(monthLabel), findsOneWidget);

    await _tapPill(tester, 'Sort: Oldest');
    await tester.pump();
    await _settleSheet(tester);
    await tester.tap(find.text('Amount: high to low'));
    await tester.pump();
    await _pumpUntilVisible(tester, find.text('Sort: Amount'));

    // 100000 > 50000 > 20000 and month headers are dropped in amount order.
    expect(_dy(tester, 'INV-001') < _dy(tester, 'INV-002'), isTrue);
    expect(_dy(tester, 'INV-002') < _dy(tester, 'INV-003'), isTrue);
    expect(find.text(monthLabel), findsNothing);
    await _disposeTree(tester);
  });
}
