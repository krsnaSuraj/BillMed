// Guards around recording a payment:
//   • the payment-date guard (CREATE only, so a payment stranded by a
//     bill-date edit is never locked),
//   • the overpay confirmation (asks first, then records on confirmation),
//   • exact-outstanding silence (never asks),
//   • mode/reference/notes surviving an amount-only edit,
//   • amount-input validation (malformed digit grouping is refused).
//
// Harness rules (same as widget_flows_test.dart / pay_full_chip_test.dart):
//   • Never pumpAndSettle: the loading skeleton shimmers on repeat forever.
//   • Tall surface so transient skeleton overflow can't fail a test.
//   • Bounded pumpUntil* helpers; every test ends with disposeTree(tester) to
//     flush drift's stream-cancel timer, and closes its DB via addTearDown.
//   • Seeded dates are relative to DateTime.now(), so the suite is
//     date-independent.
import 'package:billmed/database/database.dart';
import 'package:billmed/models/bill_status.dart';
import 'package:billmed/screens/bills/bill_detail_screen.dart';
import 'package:billmed/screens/payments/add_payment_screen.dart';
import 'package:billmed/utils/money.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'widget_harness.dart';

final DateFormat _fmt = DateFormat('dd/MM/yyyy');

/// Label of the placeholder home route the payment screen is pushed over, so
/// a successful save's `Navigator.pop` is an observable effect (the screen is
/// not the root route in these tests).
const String _homeMarker = 'open-payment-form';

/// Local midnight [days] away from today (negative = in the past).
///
/// Built from Y/M/D rather than a Duration so a DST change can never shift the
/// date by an hour.
DateTime _dayOffset(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

Future<BillMedDatabase> _memoryDb() async {
  final db = BillMedDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// One supplier + one bill, dated [daysAgo] before today.
Future<int> _seedBill(
  BillMedDatabase db, {
  required int amountPaise,
  int daysAgo = 5,
}) async {
  final dist =
      await db.addDistributor(DistributorsCompanion.insert(name: 'Alpha'));
  return db.addBill(BillsCompanion.insert(
    distributorId: dist,
    billNumber: 'INV-001',
    billDate: _dayOffset(-daysAgo),
    amountPaise: amountPaise,
  ));
}

/// Pumps [AddPaymentScreen] pushed over a placeholder home route.
Future<void> _pumpScreen(
  WidgetTester tester,
  BillMedDatabase db, {
  required int billId,
  required int outstandingPaise,
  Payment? editPayment,
}) async {
  tallSurface(tester);
  await tester.pumpWidget(wrapWithDb(
    Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => AddPaymentScreen(
                  billId: billId,
                  outstandingPaise: outstandingPaise,
                  editPayment: editPayment,
                ),
              ),
            ),
            child: const Text(_homeMarker),
          ),
        ),
      ),
    ),
    db,
  ));
  await tester.tap(find.text(_homeMarker));
  await pumpUntilVisible(tester, find.text('Outstanding'));
}

/// Opens the screen's date field, switches the picker to typed input and
/// submits [date].
///
/// The calendar grid is avoided on purpose: the target day is as likely to sit
/// in a neighbouring month as in the displayed one, so tapping a day cell is
/// date-dependent. Input mode is deterministic (en_US 'mm/dd/yyyy', the
/// ambient locale of a bare MaterialApp).
Future<void> _pickPaymentDate(WidgetTester tester, DateTime date) async {
  // The label sits inside an IgnorePointer, so tapping its text warns about a
  // missed hit test even though the tap does reach the field: tap the field's
  // InkWell instead.
  await tester.tap(find
      .ancestor(of: find.text('Payment Date *'), matching: find.byType(InkWell))
      .first);
  await pumpUntilVisible(tester, find.byType(DatePickerDialog));

  await tester.tap(find.byTooltip('Switch to input'));
  final field = find.descendant(
    of: find.byType(DatePickerDialog),
    matching: find.byType(TextFormField),
  );
  await pumpUntilVisible(tester, field);

  final String mm = date.month.toString().padLeft(2, '0');
  final String dd = date.day.toString().padLeft(2, '0');
  await tester.enterText(field, '$mm/$dd/${date.year}');
  await tester.pump();

  await tester.tap(find.text('OK'));
  await pumpUntilGone(tester, find.byType(DatePickerDialog));
}

/// Bounded pump until a modal bottom sheet has finished sliding up.
///
/// A sheet's text exists in the tree from its first frame, when the sheet is
/// still translated below the screen bottom — "visible" is not "tappable", and
/// a tap mid-slide lands outside the viewport.
Future<void> _sheetSettled(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
}

/// Bounded pump until the drift write behind a save has landed.
Future<void> _pumpUntilSaved(
  WidgetTester tester,
  Future<bool> Function() landed,
) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (await landed()) return;
  }
}

Finder get _amountField => find.byType(TextFormField).first;

void main() {
  testWidgets('a payment dated before the bill is refused when creating',
      (tester) async {
    final db = await _memoryDb();
    final billId = await _seedBill(db, amountPaise: 100000);
    final DateTime beforeBill = _dayOffset(-6);

    await _pumpScreen(tester, db, billId: billId, outstandingPaise: 100000);
    await tester.enterText(_amountField, '1000');
    await tester.pump();

    await _pickPaymentDate(tester, beforeBill);
    // Precondition: the picker really moved the payment date before the bill.
    expect(find.text(_fmt.format(beforeBill)), findsOneWidget);

    await tester.tap(find.text('Record Payment'));
    await pumpUntilVisible(
        tester, find.text('Payment date cannot be before the bill date'));

    expect(find.text('Payment date cannot be before the bill date'),
        findsOneWidget);
    expect(await db.getTotalPaidForBill(billId), 0);
    expect(await db.getPaymentsByBill(billId), isEmpty);
    await disposeTree(tester);
  });

  testWidgets('a payment stranded before its bill can still be edited',
      (tester) async {
    final db = await _memoryDb();
    final billId = await _seedBill(db, amountPaise: 100000);
    // Only reachable by editing the bill's date forward after the payment was
    // recorded: no UI flow creates this state.
    await db.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: _dayOffset(-10),
      amountPaise: 50000,
      mode: 'Cash',
    ));
    final Payment p = (await db.getPaymentsByBill(billId)).single;
    final Bill? bill = await db.getBill(billId);
    expect(p.paymentDate.isBefore(bill!.billDate), isTrue,
        reason: 'precondition: the stored payment predates its bill');

    await _pumpScreen(tester, db,
        billId: billId, outstandingPaise: 100000, editPayment: p);
    await tester.enterText(_amountField, '300');
    await tester.pump();

    await tester.tap(find.text('Update Payment'));
    await _pumpUntilSaved(
        tester, () async => await db.getTotalPaidForBill(billId) == 30000);

    final Payment saved = (await db.getPaymentsByBill(billId)).single;
    expect(saved.amountPaise, 30000);
    // The stranded (pre-bill) date was left alone and did not block the save.
    expect(saved.paymentDate, p.paymentDate);

    // Route popped: the exit transition must finish before the screen is gone.
    await pumpUntilGone(tester, find.text('Update Payment'));
    expect(find.text('Update Payment'), findsNothing);
    expect(find.text(_homeMarker), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets(
      'overpaying asks first; Cancel writes nothing, Record Anyway does',
      (tester) async {
    final db = await _memoryDb();
    final billId = await _seedBill(db, amountPaise: 100000);
    await db.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: _dayOffset(-1),
      amountPaise: 20000,
      mode: 'UPI',
    ));

    // Bill ₹1,000 with ₹200 already paid → ₹800 outstanding.
    await _pumpScreen(tester, db, billId: billId, outstandingPaise: 80000);
    await tester.enterText(_amountField, '1000');
    await tester.pump();

    await tester.tap(find.text('Record Payment'));
    await pumpUntilVisible(tester, find.text('More than balance'));
    await _sheetSettled(tester);
    expect(find.text('Amount exceeds outstanding by ₹200. Record anyway?'),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await pumpUntilGone(tester, find.text('More than balance'));
    expect(await db.getTotalPaidForBill(billId), 20000,
        reason: 'Cancel must not write the payment');
    expect(await db.getPaymentsByBill(billId), hasLength(1));

    // Same form, second attempt: this time confirm.
    await tester.tap(find.text('Record Payment'));
    await pumpUntilVisible(tester, find.text('Record Anyway'));
    await _sheetSettled(tester);
    await tester.tap(find.text('Record Anyway'));
    await _pumpUntilSaved(
        tester, () async => await db.getTotalPaidForBill(billId) == 120000);

    expect(await db.getTotalPaidForBill(billId), 120000);
    final BillPaid? bp = await db.getBillWithPaid(billId);
    expect(bp!.status, BillStatus.overpaid);
    await disposeTree(tester);
  });

  testWidgets('paying exactly the outstanding never asks', (tester) async {
    final db = await _memoryDb();
    // 50025 is deliberately not a whole rupee: an off-by-a-paise comparison
    // would turn this exact payment into an "overpay" prompt.
    final billId = await _seedBill(db, amountPaise: 50025);

    await _pumpScreen(tester, db, billId: billId, outstandingPaise: 50025);
    await tester.enterText(_amountField, '500.25');
    await tester.pump();

    await tester.tap(find.text('Record Payment'));
    await tester.pump();

    // Watch every frame of the save for a confirmation sheet.
    var askedToConfirm = false;
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('More than balance').evaluate().isNotEmpty) {
        askedToConfirm = true;
      }
      if (await db.getTotalPaidForBill(billId) == 50025) break;
    }

    expect(askedToConfirm, isFalse,
        reason: 'an exact payment must save without a confirmation');
    expect(find.text('More than balance'), findsNothing);
    expect(await db.getTotalPaidForBill(billId), 50025);
    expect((await db.getPaymentsByBill(billId)).single.amountPaise, 50025);
    await disposeTree(tester);
  });

  testWidgets('editing the amount keeps mode, reference and notes',
      (tester) async {
    final db = await _memoryDb();
    final billId = await _seedBill(db, amountPaise: 100000);
    await db.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: _dayOffset(-2),
      amountPaise: 50000,
      mode: 'NEFT',
      referenceNo: Value('UTR123'),
      notes: Value('bank transfer'),
    ));
    final Payment p = (await db.getPaymentsByBill(billId)).single;

    await _pumpScreen(tester, db,
        billId: billId, outstandingPaise: 100000, editPayment: p);
    // Only the amount is touched.
    await tester.enterText(_amountField, '600');
    await tester.pump();
    await tester.tap(find.text('Update Payment'));
    await _pumpUntilSaved(
        tester, () async => await db.getTotalPaidForBill(billId) == 60000);

    final Payment saved = (await db.getPaymentsByBill(billId)).single;
    expect(saved.amountPaise, 60000);
    expect(saved.mode, 'NEFT');
    expect(saved.referenceNo, 'UTR123');
    expect(saved.notes, 'bank transfer');
    await disposeTree(tester);
  });

  testWidgets('a malformed amount grouping is refused; a real one saves',
      (tester) async {
    final db = await _memoryDb();
    final billId = await _seedBill(db, amountPaise: 200000);

    await _pumpScreen(tester, db, billId: billId, outstandingPaise: 200000);

    // '12,50' has a two-digit last group, so it is not grouping — reading it
    // as ₹1,250 would be a hundred-fold money error.
    await tester.enterText(_amountField, '12,50');
    await tester.pump();
    await tester.tap(find.text('Record Payment'));
    await pumpUntilVisible(tester, find.text('Enter a valid amount'));

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(await db.getPaymentsByBill(billId), isEmpty);
    expect(await db.getTotalPaidForBill(billId), 0);
    // Still on the form: nothing saved, nothing popped.
    expect(find.text('Record Payment'), findsOneWidget);

    await tester.enterText(_amountField, '1,250');
    await tester.pump();
    await tester.tap(find.text('Record Payment'));
    await _pumpUntilSaved(
        tester, () async => await db.getTotalPaidForBill(billId) == 125000);

    expect(await db.getTotalPaidForBill(billId), 125000);
    expect((await db.getPaymentsByBill(billId)).single.amountPaise, 125000);
    await disposeTree(tester);
  });

  testWidgets('a payment older than its bill still renders in the timeline',
      (tester) async {
    final db = await _memoryDb();
    final billId = await _seedBill(db, amountPaise: 100000);
    final DateTime stranded = _dayOffset(-10);
    await db.addPayment(PaymentsCompanion.insert(
      billId: billId,
      paymentDate: stranded,
      amountPaise: 50000,
      mode: 'Cash',
      referenceNo: Value('R-9'),
    ));

    tallSurface(tester);
    await tester.pumpWidget(wrapWithDb(BillDetailScreen(billId: billId), db));
    await pumpUntilVisible(tester, find.text('Cash'));

    // The DB has no constraint tying a payment to its bill's date, so a
    // pre-bill payment is possible — and the timeline must render it rather
    // than throw.
    expect(tester.takeException(), isNull);
    expect(find.textContaining(_fmt.format(stranded)), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text(formatPaise(50000)), findsOneWidget);
    expect(find.text('Partial'), findsOneWidget);
    await disposeTree(tester);
  });
}
