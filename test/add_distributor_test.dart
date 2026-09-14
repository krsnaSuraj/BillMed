// Add / edit supplier form. The screen had no tests, so nothing pinned the two
// things it must never get wrong: a supplier with no name (unreadable rows
// everywhere else in the app) and a phone that is not a phone.
//
// Harness rules (see widget_harness.dart): never pumpAndSettle (the loading
// shimmer repeats forever), a real in-memory drift DB, a tall surface, and an
// explicit disposeTree at the end so drift's stream-cancel timer is flushed
// inside the test body.
import 'package:billmed/database/database.dart';
import 'package:billmed/screens/distributors/add_distributor_screen.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_harness.dart';

/// Root route that pushes the form the way the app does, so the form's
/// `Navigator.pop(context, true)` lands on a real previous route and one test
/// can open the form again for the next case.
class _FormHost extends StatefulWidget {
  const _FormHost({this.edit, this.label = 'OPEN FORM'});

  final Distributor? edit;
  final String label;

  @override
  State<_FormHost> createState() => _FormHostState();
}

class _FormHostState extends State<_FormHost> {
  /// The result the form popped with: `true` means it saved and closed.
  bool? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final r = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => AddDistributorScreen(edit: widget.edit),
              ),
            );
            if (mounted) setState(() => result = r);
          },
          child: Text(widget.label),
        ),
      ),
    );
  }
}

/// Every stored supplier, oldest first — the assertion surface for "was a row
/// really written?".
Future<List<Distributor>> _all(BillMedDatabase db) =>
    (db.select(db.distributors)..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();

Future<void> _pumpHost(
  WidgetTester tester,
  BillMedDatabase db, {
  Distributor? edit,
}) async {
  await tester.pumpWidget(wrapWithDb(
    _FormHost(edit: edit, label: edit == null ? 'OPEN FORM' : 'OPEN EDIT'),
    db,
  ));
}

/// Bounded wait for a page transition to finish. A route that is still
/// transitioning ignores pointers and its Navigator absorbs them, so a tap
/// during the animation silently misses its target. Never pumpAndSettle: the
/// loading shimmer repeats forever.
Future<void> _settleRoute(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the form from the host route and waits for its save button.
Future<void> _openForm(
  WidgetTester tester, {
  bool editing = false,
}) async {
  await _settleRoute(tester);
  await tester.tap(find.text(editing ? 'OPEN EDIT' : 'OPEN FORM'));
  await pumpUntilVisible(
      tester, find.text(editing ? 'Update Supplier' : 'Save Supplier'));
  await _settleRoute(tester);
}

/// Types into the name / company / phone fields, in that order.
Future<void> _fill(
  WidgetTester tester, {
  required String name,
  String company = '',
  String phone = '',
}) async {
  await tester.enterText(find.byType(TextFormField).at(0), name);
  await tester.enterText(find.byType(TextFormField).at(1), company);
  await tester.enterText(find.byType(TextFormField).at(2), phone);
  await tester.pump();
}

String _fieldText(WidgetTester tester, int index) =>
    tester.widget<TextFormField>(find.byType(TextFormField).at(index))
        .controller!
        .text;

/// Taps save and waits for the form to close back to the host route.
Future<void> _saveAndClose(
  WidgetTester tester, {
  bool editing = false,
}) async {
  final String saveLabel = editing ? 'Update Supplier' : 'Save Supplier';
  await tester.tap(find.text(saveLabel));
  await tester.pump();
  await pumpUntilGone(tester, find.text(saveLabel));
  await pumpUntilVisible(tester, find.text(editing ? 'OPEN EDIT' : 'OPEN FORM'));
  // The pop animation is still running here; the host route is on screen but
  // not yet accepting pointers.
  await _settleRoute(tester);
}

void main() {
  testWidgets('saving with an empty name is refused and inserts nothing',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _pumpHost(tester, db);
    await _openForm(tester);

    // Untouched form.
    await tester.tap(find.text('Save Supplier'));
    await tester.pump();
    expect(find.text('Enter supplier name'), findsOneWidget);
    expect(find.text('Save Supplier'), findsOneWidget,
        reason: 'a refused save must leave the form open');

    // Whitespace is not a name either — it is trimmed before the check.
    await _fill(tester, name: '   ', company: 'Some Company');
    await tester.tap(find.text('Save Supplier'));
    await tester.pump();
    expect(find.text('Enter supplier name'), findsOneWidget);

    expect(await _all(db), isEmpty,
        reason: 'nothing may be inserted while the name is invalid');
    await disposeTree(tester);
  });

  testWidgets('a valid supplier is saved with whitespace trimmed',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _pumpHost(tester, db);
    await _openForm(tester);
    await _fill(
      tester,
      name: '  Sterling Pharma  ',
      company: '  Alkem Labs  ',
      phone: '  9876543210  ',
    );

    await _saveAndClose(tester);

    expect(tester.state<_FormHostState>(find.byType(_FormHost)).result, isTrue,
        reason: 'the form pops with true once the row is written');

    final rows = await _all(db);
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Sterling Pharma');
    expect(rows.single.company, 'Alkem Labs');
    expect(rows.single.phone, '9876543210');
    await disposeTree(tester);
  });

  testWidgets('a phone with too few digits is refused and inserts nothing',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _pumpHost(tester, db);
    await _openForm(tester);
    await _fill(tester, name: 'Short Phone Co', phone: '12345');

    await tester.tap(find.text('Save Supplier'));
    await tester.pump();

    expect(find.text('Enter valid phone'), findsOneWidget);
    expect(await _all(db), isEmpty);
    await disposeTree(tester);
  });

  testWidgets('a phone with no digits at all is refused and inserts nothing',
      (tester) async {
    // The validator strips every non-digit before measuring, and a phone of
    // pure letters strips to '' — which it treats as "no phone given" and
    // accepts, storing 'abcdefghij' as the supplier's phone. That is not a
    // phone: the correct behaviour is the same 'Enter valid phone' refusal as
    // any other unusable number, so this test is expected to fail until the
    // validator distinguishes "empty field" from "nothing but letters".
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // This test is expected to fail until the validator is fixed, so unmount
    // from a tear-down as well: that keeps drift's stream-cancel timer out of
    // the failure report, which then shows the assertion alone.
    addTearDown(() => disposeTree(tester));

    await _pumpHost(tester, db);
    await _openForm(tester);
    await _fill(tester, name: 'Letter Phone Co', phone: 'abcdefghij');

    await tester.tap(find.text('Save Supplier'));
    await tester.pump();

    // Asserted first so the failure report shows the row that was really
    // written, not just the missing error message.
    final rows = await _all(db);
    expect(rows.map((Distributor d) => d.phone).toList(), isEmpty,
        reason: 'a phone of letters must never be stored: this save writes a '
            'supplier whose phone is the literal text "abcdefghij"');
    expect(find.text('Enter valid phone'), findsOneWidget,
        reason: 'letters are not a phone number');
    await disposeTree(tester);
  });

  testWidgets('10, 11 (leading 0) and 12 digit numbers are all accepted',
      (tester) async {
    // The rule the screen documents: strip non-digits, then accept 10–15 of
    // them. Landlines written with a leading 0 and numbers written with a
    // country code (12 digits) are therefore valid.
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await _pumpHost(tester, db);

    Future<void> saveNew(String name, String phone) async {
      await _openForm(tester);
      await _fill(tester, name: name, phone: phone);
      await _saveAndClose(tester);
    }

    await saveNew('Ten Digits', '9876543210');
    await saveNew('Zero Prefix', '09876543210');
    await saveNew('Country Code', '919876543210');

    final rows = await _all(db);
    expect(rows.map((Distributor d) => d.phone).toList(),
        ['9876543210', '09876543210', '919876543210']);
    await disposeTree(tester);
  });

  testWidgets('editing prefills the row and saving updates every field',
      (tester) async {
    tallSurface(tester);
    final db = BillMedDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.addDistributor(DistributorsCompanion.insert(
      name: 'Old Name',
      company: const Value('Old Company'),
      phone: const Value('9876543210'),
    ));
    final existing = (await db.getDistributor(id))!;

    await _pumpHost(tester, db, edit: existing);
    await _openForm(tester, editing: true);

    expect(find.text('Edit Supplier'), findsOneWidget);
    expect(_fieldText(tester, 0), 'Old Name');
    expect(_fieldText(tester, 1), 'Old Company');
    expect(_fieldText(tester, 2), '9876543210');

    await _fill(
      tester,
      name: 'New Name',
      company: 'New Company',
      phone: '9123456780',
    );
    await _saveAndClose(tester, editing: true);

    final row = (await db.getDistributor(id))!;
    expect(row.name, 'New Name');
    expect(row.company, 'New Company');
    expect(row.phone, '9123456780');
    expect(await _all(db), hasLength(1),
        reason: 'an edit updates the row; it never adds a second one');
    await disposeTree(tester);
  });
}
