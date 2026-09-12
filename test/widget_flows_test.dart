// Widget flows with a REAL in-memory drift DB via ProviderScope overrides.
// Seed per test: 2 suppliers (Alpha, Beta) + 3 bills:
//   INV-001 Alpha 100000 unpaid, INV-002 Alpha 50000 + 10000 paid (partial),
//   INV-003 Beta 20000 + 20000 paid (paid).
// Bill dates are 5 days ago (wall-clock relative) so nothing is overdue and
// the suite stays deterministic regardless of run date.
//
// Test-harness notes (all discovered by iterating until green):
// - No pumpAndSettle: Dashboard/BillList show a SkeletonList shimmer
//   (AnimationController.repeat → infinite) while streams load, so
//   pumpAndSettle never settles. Bounded pumps are used instead.
// - Tall surface: the loading skeleton (plain Column of 8 rows) overflows the
//   default 600px viewport; flutter_test fails on the transient overflow.
// - pump-until-visible: stream emission timing varies under load, so tests
//   pump until the expected content appears (bounded) instead of a fixed
//   pump count.
// - Explicit unmount at test end: drift schedules a zero-duration timer when
//   its watched-query streams are cancelled on ProviderScope dispose, which
//   flutter_test reports as "A Timer is still pending". Unmounting + pumping
//   inside the test body flushes it.
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billmed/database/database.dart';
import 'package:billmed/providers/database_provider.dart';
import 'package:billmed/screens/bills/add_bill_screen.dart';
import 'package:billmed/screens/bills/bill_list_screen.dart';
import 'package:billmed/screens/dashboard/dashboard_screen.dart';
import 'package:billmed/screens/payments/add_payment_screen.dart';
import 'package:billmed/utils/money.dart';

/// Builds + seeds a fresh in-memory DB. Caller owns it (closed via tearDown).
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
  // INV-001 intentionally left unpaid.
  return db;
}

Widget _wrap(Widget home, BillMedDatabase db) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: home),
    );

/// Tall test surface: the loading SkeletonList (a plain Column of 8 rows, not
/// scrollable) overflows the default 600px-tall viewport by ~88px, which
/// flutter_test records as a failure even though the frame is transient.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps until [done] or a bound (60 × 100ms fake time), so slow stream
/// emission under load can't flake the suite — and an unmet condition fails
/// on the subsequent expect, never by hanging.
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches at least one widget (bounded, see _pumpUntil).
Future<void> _pumpUntilVisible(WidgetTester tester, Finder finder) =>
    _pumpUntil(tester, () => finder.evaluate().isNotEmpty);

/// Pumps until [finder] matches nothing (bounded, see _pumpUntil).
Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) =>
    _pumpUntil(tester, () => finder.evaluate().isEmpty);

/// Unmounts the tree and flushes drift's stream-cancel timer inside the test
/// body, keeping flutter_test's post-test timer check clean.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(Container());
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('dashboard shows pending total + supplier names', (tester) async {
    _tallSurface(tester);
    final db = await _seededDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(const DashboardScreen(), db));
    await _pumpUntilVisible(tester, find.text('NAMASTE'));

    // Pending = 170000 billed − 30000 paid = 140000. The pending string
    // appears twice by design: the hero AnimatedMoney + Alpha's ledger row
    // (Alpha alone owes the full 140000; Beta is settled → 'Clear').
    expect(find.text('NAMASTE'), findsOneWidget);
    expect(find.text('pending · 3 bills · 2 suppliers'), findsOneWidget);
    expect(find.text(formatPaise(140000)), findsWidgets);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.textContaining('Total paid'), findsOneWidget);
    expect(find.text(formatPaise(30000)), findsOneWidget);
    expect(find.text('Dues'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('bill list shows bills; Unpaid chip filters to unpaid only',
      (tester) async {
    _tallSurface(tester);
    final db = await _seededDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(const BillListScreen(), db));
    await _pumpUntilVisible(tester, find.text('INV-001'));

    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('INV-002'), findsOneWidget);
    expect(find.text('INV-003'), findsOneWidget);

    // Exact chip labels are "$label ($count)" (see _filterChip).
    // The tap only flips local _chip state; one pump rebuilds, then the
    // non-matching tiles are gone.
    await tester.tap(find.text('Unpaid (1)'));
    await tester.pump();
    await _pumpUntilGone(tester, find.text('INV-002'));

    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('INV-002'), findsNothing);
    expect(find.text('INV-003'), findsNothing);
    await _disposeTree(tester);
  });

  testWidgets('add bill: empty save shows validation errors', (tester) async {
    _tallSurface(tester);
    final db = await _seededDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(const AddBillScreen(), db));
    await _pumpUntilVisible(tester, find.text('Save Bill'));

    await tester.tap(find.text('Save Bill'));
    await tester.pump();

    // Exact validator strings: 'Required' (bill number + amount),
    // 'Select supplier' (dropdown validator in _supplierField).
    expect(find.text('Required'), findsWidgets);
    expect(find.text('Select supplier'), findsAtLeastNWidgets(1));
    await _disposeTree(tester);
  });

  testWidgets('add payment: Pay Full fills amount field', (tester) async {
    _tallSurface(tester);
    final db = await _seededDb();
    addTearDown(db.close);

    const outstanding = 50025; // paise → editable '500.25'
    await tester.pumpWidget(_wrap(
        const AddPaymentScreen(billId: 1, outstandingPaise: outstanding), db));
    await _pumpUntilVisible(tester, find.text('Pay Full'));

    // Exact chip label (see _AddPaymentScreenState.build InputChip).
    await tester.tap(find.text('Pay Full'));
    await tester.pump();

    final amountField =
        tester.widget<TextFormField>(find.byType(TextFormField).first);
    expect(amountField.controller!.text, paiseToEditableString(outstanding));
    await _disposeTree(tester);
  });
}
