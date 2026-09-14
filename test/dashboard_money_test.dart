// Dashboard money honesty: every number the dashboard states must equal the
// money in the rows below it. This class of bug has shipped before — the
// headline netted the GRAND totals, so one supplier's advance cancelled another
// supplier's debt and the dashboard read "₹0 pending" above a red "₹50 due"
// row. Netting is only ever allowed *inside* one supplier.
//
// Harness rules (see widget_harness.dart): never pumpAndSettle (the loading
// shimmer repeats forever), a real in-memory drift DB, a tall surface, and an
// explicit disposeTree at the end so drift's stream-cancel timer is flushed
// inside the test body.
import 'package:billmed/database/database.dart';
import 'package:billmed/screens/dashboard/dashboard_screen.dart';
import 'package:billmed/utils/money.dart';
import 'package:billmed/widgets/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_harness.dart';

/// Money exactly as the app prints it, so the expectations carry no hardcoded
/// glyph and no hardcoded grouping.
String _inr(int paise) => formatPaise(paise);

/// The headline pending figure is the first [AnimatedMoney] in the dashboard's
/// ListView (the big hero number, above the hero strip and the ledger rows).
Finder get _headline => find.byType(AnimatedMoney).first;

/// Asserts the headline — and only the headline — states [paise].
void _expectHeadline(int paise, String why) {
  expect(
    find.descendant(of: _headline, matching: find.text(_inr(paise))),
    findsOneWidget,
    reason: 'the pending headline must state ${_inr(paise)}: $why',
  );
}

/// The Dues section pill: how many supplier rows the dashboard counts as owing.
int _duesRowCount(WidgetTester tester) =>
    tester.widget<SectionHeader>(find.byType(SectionHeader)).count!;

/// Wall-clock relative dates, so the suite reads the same on any run date.
DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

Future<int> _bill(BillMedDatabase db, int distributorId, String number,
        int paise, DateTime date) =>
    db.addBill(BillsCompanion.insert(
      distributorId: distributorId,
      billNumber: number,
      billDate: date,
      amountPaise: paise,
    ));

Future<void> _pay(BillMedDatabase db, int billId, int paise, DateTime date) =>
    db.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: date,
      amountPaise: paise,
      mode: 'Cash',
    ));

Future<void> _pumpDashboard(WidgetTester tester, BillMedDatabase db) async {
  await tester.pumpWidget(wrapWithDb(const DashboardScreen(), db));
  await pumpUntilVisible(tester, find.text('NAMASTE'));
}

/// Alpha: ₹1,000 billed, ₹1,100 paid → an advance, Alpha nets to zero.
/// Beta: ₹50 billed, nothing paid → Beta owes ₹50.
Future<BillMedDatabase> _seedAdvanceBesideDebt() async {
  final db = BillMedDatabase(NativeDatabase.memory());
  final alpha =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Alpha'));
  final beta =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Beta'));
  final recent = _daysAgo(5);

  final a1 = await _bill(db, alpha, 'ADV-001', 100000, recent);
  await _pay(db, a1, 110000, recent);
  await _bill(db, beta, 'OWE-001', 5000, recent);
  return db;
}

/// One supplier whose dues are only *netted* away: a ₹1,000 bill paid ₹1,100
/// (advance) beside a ₹100 bill nobody paid. Per-supplier net is exactly ₹0
/// while a bill is still unsettled.
Future<BillMedDatabase> _seedNettedToZero() async {
  final db = BillMedDatabase(NativeDatabase.memory());
  final id =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Netted'));
  final recent = _daysAgo(5);

  final advance = await _bill(db, id, 'NET-001', 100000, recent);
  await _pay(db, advance, 110000, recent);
  await _bill(db, id, 'NET-002', 10000, recent);
  return db;
}

/// One overdue unpaid bill of ₹200 and one overdue-dated bill that is fully
/// overpaid — settled, so it is not overdue at all.
Future<BillMedDatabase> _seedOverdueRail() async {
  final db = BillMedDatabase(NativeDatabase.memory());
  final id =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Overdue'));
  final old = _daysAgo(60);

  await _bill(db, id, 'OD-001', 20000, old);
  final settled = await _bill(db, id, 'OD-002', 20000, old);
  await _pay(db, settled, 20000, old);
  return db;
}

void main() {
  testWidgets('pending headline equals the sum of the per-supplier dues',
      (tester) async {
    // The bug this pins: the headline used to net the grand billed/paid totals,
    // so Alpha's ₹100 advance cancelled ₹100 of Beta's ₹50 debt (or clamped the
    // whole thing to ₹0). The user saw a headline that disagreed with the rows.
    tallSurface(tester);
    final db = await _seedAdvanceBesideDebt();
    addTearDown(db.close);

    await _pumpDashboard(tester, db);

    // ₹50 owed by Beta, and nothing else: Alpha's advance cancels only Alpha.
    _expectHeadline(5000, 'Beta owes ₹50 and Alpha owes nothing');
    expect(find.text(_inr(0)), findsNothing,
        reason: 'no part of the dashboard is ₹0 for this seed');
    // The money the headline states is also the row that owes it — headline and
    // Beta's dues row are the only two places ₹50 may appear.
    expect(find.text(_inr(5000)), findsNWidgets(2),
        reason: 'the headline plus Beta\'s dues row');
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    // Alpha's single bill is fully paid, so Alpha really is clear.
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('pending · 2 bills · 2 suppliers'), findsOneWidget);
    expect(_duesRowCount(tester), 1, reason: 'only Beta owes anything');
    await disposeTree(tester);
  });

  testWidgets('a supplier netted to zero is not shown as Clear',
      (tester) async {
    // Netting an advance away can zero the amount while an unsettled bill
    // remains. "Clear" claims nothing is left to pay, which would be a lie the
    // user acts on.
    tallSurface(tester);
    final db = await _seedNettedToZero();
    addTearDown(db.close);

    await _pumpDashboard(tester, db);

    expect(find.text('Netted'), findsOneWidget);
    expect(find.text('Clear'), findsNothing,
        reason: 'NET-002 is still unpaid — this supplier is not clear');
    // The Dues section still counts the row that has an unsettled bill …
    expect(_duesRowCount(tester), 1,
        reason: 'a netted row with an unsettled bill is still a dues row');
    // … and there is exactly one ledger row on screen.
    expect(find.byType(SectionHeader), findsOneWidget);
    // Its dues net to ₹0 (the advance), stated next to "2 bills", not "Clear".
    expect(find.text(_inr(0)), findsNWidgets(2),
        reason: 'headline ₹0 and the netted row ₹0');
    await disposeTree(tester);
  });

  testWidgets('overdue rail names the overdue bills and the overdue money',
      (tester) async {
    // The settled-but-overdue-dated bill must be excluded twice over: not
    // counted ("1 overdue", never "2") and not summed (₹200, never ₹400).
    tallSurface(tester);
    final db = await _seedOverdueRail();
    addTearDown(db.close);

    await _pumpDashboard(tester, db);

    expect(find.text('1 overdue · ${_inr(20000)}'), findsOneWidget,
        reason: 'the rail must state 1 overdue bill and ₹200');
    expect(find.text('2 overdue · ${_inr(40000)}'), findsNothing,
        reason: 'the fully paid bill is settled, so it is not overdue');
    expect(find.text(_inr(40000)), findsNothing,
        reason: 'never the billed amount of both overdue-dated bills');
    await disposeTree(tester);
  });

  testWidgets('overdue rail sums CLAMPED remaining, never the billed amount',
      (tester) async {
    // ₹500 billed with ₹300 paid is ₹200 overdue, not ₹500. The ₹200 overpaid
    // bill beside it contributes nothing at all.
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id =
        await db.addDistributor(DistributorsCompanion.insert(name: 'Partial'));
    final old = _daysAgo(60);

    final partial = await _bill(db, id, 'P-001', 50000, old);
    await _pay(db, partial, 30000, old);
    final overpaid = await _bill(db, id, 'P-002', 20000, old);
    await _pay(db, overpaid, 25000, old);

    await _pumpDashboard(tester, db);

    expect(find.text('1 overdue · ${_inr(20000)}'), findsOneWidget,
        reason: '₹500 billed − ₹300 paid = ₹200 overdue');
    expect(find.text('1 overdue · ${_inr(50000)}'), findsNothing,
        reason: 'the rail never states the billed amount');
    await disposeTree(tester);
  });

  testWidgets('a supplier with no bills shows 0 dues and does not crash',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addDistributor(DistributorsCompanion.insert(name: 'NoBills'));

    await _pumpDashboard(tester, db);

    expect(tester.takeException(), isNull);
    expect(find.text('NoBills'), findsOneWidget);
    expect(find.text('pending · 0 bills · 1 supplier'), findsOneWidget);
    _expectHeadline(0, 'a supplier with no bills owes nothing');
    expect(_duesRowCount(tester), 0, reason: 'nothing is owed');
    expect(find.text('Clear'), findsOneWidget,
        reason: 'an empty ledger reads Clear, not a phantom due');
    await disposeTree(tester);
  });
}
