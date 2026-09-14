// The Pay Full chip on Add Payment. The bug it fixes: the chip rendered a
// tick before any tap, so it claimed "full amount set" while the field was
// still empty. The tick is now derived from the field's real value.
import 'package:billmed/database/database.dart';
import 'package:billmed/screens/payments/add_payment_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_harness.dart';

const int _outstanding = 50025; // ₹500.25 — exercises the paise path

Finder get _chip => find.byType(InputChip);
Finder _chipIcon(IconData icon) =>
    find.descendant(of: _chip, matching: find.byIcon(icon));

String _amountText(WidgetTester tester) => tester
    .widget<TextFormField>(find.byType(TextFormField).first)
    .controller!
    .text;

bool _chipSelected(WidgetTester tester) =>
    tester.widget<InputChip>(_chip).selected;

Future<void> _pumpScreen(
  WidgetTester tester, {
  int outstanding = _outstanding,
  Payment? edit,
  BillMedDatabase? db,
  int billId = 1,
}) async {
  tallSurface(tester);
  final database = db ?? BillMedDatabase(NativeDatabase.memory());
  if (db == null) addTearDown(database.close);
  await tester.pumpWidget(wrapWithDb(
    AddPaymentScreen(
      billId: billId,
      outstandingPaise: outstanding,
      editPayment: edit,
    ),
    database,
  ));
  await pumpUntilVisible(tester, find.text('Outstanding'));
}

void main() {
  testWidgets('starts unticked with an empty amount field', (tester) async {
    await _pumpScreen(tester);

    expect(_chip, findsOneWidget);
    expect(find.text('Pay Full'), findsOneWidget);
    expect(find.text('Full amount'), findsNothing);

    // The regression: a tick that nobody asked for.
    expect(_chipIcon(Icons.check), findsNothing);
    expect(_chipIcon(Icons.bolt), findsOneWidget);
    expect(_chipSelected(tester), isFalse);
    expect(_amountText(tester), isEmpty);
    await disposeTree(tester);
  });

  testWidgets('tapping fills the exact outstanding and then shows the tick',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Pay Full'));
    await tester.pump();

    expect(_amountText(tester), '500.25');
    expect(find.text('Full amount'), findsOneWidget);
    expect(find.text('Pay Full'), findsNothing);
    expect(_chipIcon(Icons.check), findsOneWidget);
    expect(_chipIcon(Icons.bolt), findsNothing);
    expect(_chipSelected(tester), isTrue);
    await disposeTree(tester);
  });

  testWidgets('whole-rupee outstanding fills without decimals', (tester) async {
    await _pumpScreen(tester, outstanding: 150000);

    await tester.tap(find.text('Pay Full'));
    await tester.pump();

    expect(_amountText(tester), '1500');
    expect(_chipSelected(tester), isTrue);
    await disposeTree(tester);
  });

  testWidgets('a second tap on the ticked chip takes the fill back',
      (tester) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Pay Full'));
    await tester.pump();
    expect(_amountText(tester), '500.25');

    await tester.tap(find.text('Full amount'));
    await tester.pump();

    expect(_amountText(tester), isEmpty);
    expect(_chipSelected(tester), isFalse);
    expect(_chipIcon(Icons.check), findsNothing);

    // And it can be filled again.
    await tester.tap(find.text('Pay Full'));
    await tester.pump();
    expect(_amountText(tester), '500.25');
    await disposeTree(tester);
  });

  testWidgets('typing the full amount by hand ticks the chip too',
      (tester) async {
    await _pumpScreen(tester);

    await tester.enterText(find.byType(TextFormField).first, '500.25');
    await tester.pump();

    expect(_chipSelected(tester), isTrue);
    expect(find.text('Full amount'), findsOneWidget);

    // Editing it back down un-ticks immediately.
    await tester.enterText(find.byType(TextFormField).first, '500.2');
    await tester.pump();
    expect(_chipSelected(tester), isFalse);
    expect(find.text('Pay Full'), findsOneWidget);
    expect(_chipIcon(Icons.check), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('only the exact amount counts as full', (tester) async {
    await _pumpScreen(tester);

    for (final partial in ['0', '499', '500.24', '500.26', '1000']) {
      await tester.enterText(find.byType(TextFormField).first, partial);
      await tester.pump();
      expect(_chipSelected(tester), isFalse, reason: partial);
    }

    // Comma grouping parses to the same paise, so it is genuinely full.
    await tester.enterText(find.byType(TextFormField).first, '500.25');
    await tester.pump();
    expect(_chipSelected(tester), isTrue);
    await disposeTree(tester);
  });

  testWidgets('comma grouping on a large amount still reads as full',
      (tester) async {
    await _pumpScreen(tester, outstanding: 100025);

    await tester.enterText(find.byType(TextFormField).first, '1,000.25');
    await tester.pump();

    expect(_chipSelected(tester), isTrue);
    expect(find.text('Full amount'), findsOneWidget);
    await disposeTree(tester);
  });

  testWidgets('nothing outstanding means no chip at all', (tester) async {
    await _pumpScreen(tester, outstanding: 0);

    expect(_chip, findsNothing);
    expect(find.text('Pay Full'), findsNothing);
    expect(find.text('Full amount'), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('editing an existing payment shows no chip', (tester) async {
    final now = DateTime.now();
    final payment = Payment(
      id: 1,
      billId: 1,
      paymentDate: now,
      amountPaise: 50000,
      mode: 'Cash',
      createdAt: now,
    );
    await _pumpScreen(tester, edit: payment, outstanding: 100000);

    expect(_chip, findsNothing);
    // Prefilled with the payment's own amount, still no tick anywhere.
    expect(_amountText(tester), '500');
    await disposeTree(tester);
  });

  testWidgets('Pay Full then Record Payment stores exactly the outstanding',
      (tester) async {
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dist =
        await db.addDistributor(DistributorsCompanion.insert(name: 'Alpha'));
    final billId = await db.addBill(BillsCompanion.insert(
      distributorId: dist,
      billNumber: 'INV-001',
      billDate: DateTime.now().subtract(const Duration(days: 1)),
      amountPaise: _outstanding,
    ));

    await _pumpScreen(tester, db: db, billId: billId);
    await tester.tap(find.text('Pay Full'));
    await tester.pump();
    await tester.tap(find.text('Record Payment'));

    // Bounded settle: the save writes through drift and pops the route.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (await db.getTotalPaidForBill(billId) > 0) break;
    }

    expect(await db.getTotalPaidForBill(billId), _outstanding);
    final saved = await db.getPaymentsByBill(billId);
    expect(saved.single.amountPaise, _outstanding);
    expect(saved.single.mode, 'UPI');
    await disposeTree(tester);
  });
}
