// Long supplier names must always be fully readable. Two different things are
// checked, and they are different problems:
//
//  1. layout capacity — how wide the name column actually is (a phone row used
//     to hand the name only ~138 dp, next to the dues amount, so a 37-character
//     trade name was cut with an ellipsis);
//  2. real text fit — whether the string fits that width in the font the app
//     ships. Widget tests render every glyph as a 1-em box (the test font), so
//     "does it fit" is measured with the bundled Roboto through a TextPainter.
//
// When a name still cannot fit (or the test font makes everything wide), the
// widget must fall back to the scrolling name instead of clipping it.
import 'dart:io';

import 'package:billmed/database/database.dart';
import 'package:billmed/screens/bills/add_bill_screen.dart';
import 'package:billmed/screens/bills/bill_list_screen.dart';
import 'package:billmed/screens/dashboard/dashboard_screen.dart';
import 'package:billmed/screens/distributors/distributor_detail_screen.dart';
import 'package:billmed/screens/distributors/distributor_list_screen.dart';
import 'package:billmed/widgets/widgets.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_harness.dart';

/// The real complaint: 37 characters, two words in brackets.
const String kLongName = 'Shree Ganesh Medical Agency (Wholesale)';

/// No spaces at all — must still fit without a forced mid-word break.
const String kUnbreakableName = 'ShreeBalajiMedicalStores';

/// Hindi trade name (Devanagari; the bundled Roboto has no Devanagari glyphs,
/// so this one is checked for layout safety rather than glyph metrics).
const String kHindiName = 'अंबिका एजेंसी (जयनारायण चौधरी)';

/// Past any reasonable wrapping: must fall back to the scrolling name.
final String kAbsurdName = 'Shree Balaji Medical & General Stores '
    '${'Super Speciality Distributors ' * 4}'
    'and Sons';

/// The narrowest column a supplier name may get: what a 37-character Roboto
/// name needs for its longest word group ("(Wholesale)") to wrap at
/// a word boundary.
const double kMinNameColumnWidth = 180;

Future<void> _loadShippedFonts() async {
  Future<ByteData> read(String path) async {
    final bytes = File(path).readAsBytesSync();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }

  final loader = FontLoader('Roboto')
    ..addFont(read('assets/fonts/Roboto-Regular.ttf'))
    ..addFont(read('assets/fonts/Roboto-Bold.ttf'));
  await loader.load();
}

TextPainter _painter(
  String text,
  double fontSize, {
  FontWeight weight = FontWeight.w400,
  int? maxLines,
}) =>
    TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: weight,
        ),
      ),
      maxLines: maxLines,
      textDirection: TextDirection.ltr,
    );

/// Asserts [text] fits [width] within [maxLines] lines in the shipped font, and
/// that no single word is wider than the column (a word that does not fit is
/// broken mid-word, which is what makes a name unreadable).
void expectFitsShipped(
  String text,
  double width, {
  required double fontSize,
  int maxLines = 2,
  FontWeight weight = FontWeight.w400,
}) {
  final fit = _painter(text, fontSize, weight: weight, maxLines: maxLines)
    ..layout(maxWidth: width);
  expect(
    fit.didExceedMaxLines,
    isFalse,
    reason: '"$text" needs more than $maxLines line(s) at '
        '${width.toStringAsFixed(1)} dp in the shipped Roboto',
  );
  fit.dispose();

  final word = _painter(text, fontSize, weight: weight)..layout();
  expect(
    word.minIntrinsicWidth,
    lessThanOrEqualTo(width),
    reason: 'a single word of "$text" is wider than '
        '${width.toStringAsFixed(1)} dp, so it breaks mid-word',
  );
  word.dispose();
}

/// The width the row hands the supplier name.
double _nameWidth(WidgetTester tester) =>
    tester.getSize(find.byType(WrapOrScrollText)).width;

/// Pumps until every rendered instance of [finder] is unclipped.
///
/// `WrapOrScrollText` lays the text out first and only decides between
/// wrapping and scrolling in a post-frame callback, so the frame in which the
/// name appears can still be the ellipsised one. Assertions must wait for the
/// decision, not for the text.
Future<void> pumpUntilNameRendered(WidgetTester tester, Finder finder) async {
  await pumpUntil(tester, () {
    if (finder.evaluate().isEmpty) return false;
    return tester
        .renderObjectList<RenderParagraph>(finder)
        .every((paragraph) => !paragraph.didExceedMaxLines);
  });
}

/// Pumps (bounded) until [finder] has travelled left from where it started.
///
/// A scroll offset applied during an animation tick lands on the following
/// frame, so "it moved" has to be waited for rather than sampled once.
Future<bool> pumpUntilMovedLeft(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) return false;
  final double start = tester.getTopLeft(finder).dx;
  await pumpUntil(tester, () {
    if (finder.evaluate().isEmpty) return false;
    return tester.getTopLeft(finder).dx < start - 1;
  });
  if (finder.evaluate().isEmpty) return false;
  return tester.getTopLeft(finder).dx < start - 1;
}

/// The name is never allowed to be cut with an ellipsis: it either fits, or it
/// scrolls its own line until the end is readable.
void expectNeverClipped(WidgetTester tester, Finder finder) {
  final paragraphs = tester.renderObjectList<RenderParagraph>(finder).toList();
  expect(paragraphs, isNotEmpty, reason: 'nothing rendered for this finder');
  for (final paragraph in paragraphs) {
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '"${paragraph.text.toPlainText()}" was ellipsized instead of '
          'being wrapped or scrolled',
    );
  }
}

BillMedDatabase _openDb() {
  final db = BillMedDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

/// One supplier with one bill plus a part payment, so the row shows dues.
Future<Distributor> _seed(BillMedDatabase db, String name) async {
  final id = await db.addDistributor(DistributorsCompanion.insert(name: name));
  final billId = await db.addBill(BillsCompanion.insert(
    distributorId: id,
    billNumber: 'INV-001',
    billDate: DateTime.now().subtract(const Duration(days: 3)),
    amountPaise: 3575200,
  ));
  await db.addPayment(PaymentsCompanion.insert(
    billId: billId,
    paymentDate: DateTime.now().subtract(const Duration(days: 1)),
    amountPaise: 1420000,
    mode: 'Cash',
  ));
  return (await db.getDistributor(id))!;
}

/// Direct harness for the widget itself, at a chosen column width.
Widget _harness(
  double width, {
  String name = kLongName,
  int maxLines = 2,
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: WrapOrScrollText(
              name: name,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadShippedFonts);

  group('supplier name rendering', () {
    testWidgets('fits on one line in a wide column, and never moves',
        (tester) async {
      await tester.pumpWidget(_harness(400));
      await tester.pump();

      expect(find.text(kLongName), findsOneWidget);
      expectNeverClipped(tester, find.text(kLongName));
      final double first = tester.getTopLeft(find.text(kLongName)).dx;
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.getTopLeft(find.text(kLongName)).dx, first);
      // No travel: nothing to animate, so no frames are scheduled for it.
      await disposeTree(tester);
    });

    testWidgets('scrolling name starts at the left edge and walks over time',
        (tester) async {
      // Test-font glyphs are 1 em wide, so 37 characters cannot fit 120 dp:
      // this is the branch a name too long even for wrapping takes.
      await tester.pumpWidget(_harness(120, maxLines: 1));
      await tester.pump();

      expect(find.text(kLongName), findsOneWidget);
      expectNeverClipped(tester, find.text(kLongName));
      expect(await pumpUntilMovedLeft(tester, find.text(kLongName)), isTrue,
          reason: 'the name must walk across its own line');
      // Never leaves the column: the widget clips instead of overflowing.
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('wrapping branch is preferred over scrolling when it fits',
        (tester) async {
      // 30 dp per line pair: two test-font lines of 20 chars.
      await tester
          .pumpWidget(_harness(310, name: 'Shree Ganesh Medical Agency'));
      await tester.pump();

      final double first =
          tester.getTopLeft(find.text('Shree Ganesh Medical Agency')).dx;
      await tester.pump(const Duration(milliseconds: 800));
      expect(
          tester.getTopLeft(find.text('Shree Ganesh Medical Agency')).dx, first,
          reason: 'a name that fits two lines must not scroll');
      expectNeverClipped(tester, find.text('Shree Ganesh Medical Agency'));
      await disposeTree(tester);
    });

    testWidgets('animations disabled at OS level: static, still not cut',
        (tester) async {
      await tester
          .pumpWidget(_harness(120, maxLines: 1, disableAnimations: true));
      await tester.pump();

      final double first = tester.getTopLeft(find.text(kLongName)).dx;
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.getTopLeft(find.text(kLongName)).dx, first,
          reason: 'the name moved although animations are disabled');
      await disposeTree(tester);
    });

    testWidgets('large accessibility text falls back to the safe branch',
        (tester) async {
      await tester.pumpWidget(
          _harness(300, maxLines: 2, textScale: 2, name: kLongName));
      await tester.pump();

      // At 2x text the name cannot fit two lines, so it must scroll rather
      // than shrink or clip.
      expectNeverClipped(tester, find.text(kLongName));
      expect(await pumpUntilMovedLeft(tester, find.text(kLongName)), isTrue,
          reason: 'at 2x text the whole name must still be reachable');
      await disposeTree(tester);
    });

    testWidgets('empty name renders nothing instead of throwing',
        (tester) async {
      await tester.pumpWidget(_harness(200, name: ''));
      await tester.pump();

      expect(find.text(''), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('unbounded width falls back to plain text', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              WrapOrScrollText(
                name: kLongName,
                style: TextStyle(fontSize: 15),
              ),
            ],
          ),
        ),
      ));
      await tester.pump();

      expect(find.text(kLongName), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });
  });

  group('screens', () {
    testWidgets('suppliers list gives a long name the room to render in full',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kLongName);

      await tester.pumpWidget(wrapWithDb(const DistributorListScreen(), db));
      await pumpUntilVisible(tester, find.text(kLongName));

      expect(_nameWidth(tester), greaterThanOrEqualTo(kMinNameColumnWidth));
      expectFitsShipped(kLongName, _nameWidth(tester),
          fontSize: 15, weight: FontWeight.w600);
      expectNeverClipped(tester, find.text(kLongName));
      // The dues amount did not get pushed out of the row by the wider name.
      expect(find.text('₹21,552'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('dashboard dues row gives a long name the same room',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kLongName);

      await tester.pumpWidget(wrapWithDb(const DashboardScreen(), db));
      await pumpUntilVisible(tester, find.text(kLongName));

      expect(_nameWidth(tester), greaterThanOrEqualTo(kMinNameColumnWidth));
      expectFitsShipped(kLongName, _nameWidth(tester),
          fontSize: 15, weight: FontWeight.w600);
      expectNeverClipped(tester, find.text(kLongName));
      await disposeTree(tester);
    });

    testWidgets('supplier detail: hero and app bar both keep the whole name',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      final supplier = await _seed(db, kLongName);

      await tester.pumpWidget(
        wrapWithDb(DistributorDetailScreen(distributor: supplier), db),
      );
      await pumpUntilVisible(tester, find.text('#INV-001'));
      await pumpUntilNameRendered(tester, find.text(kLongName));

      // Hero (26 px) + collapsed app-bar title (16 px).
      expect(find.byType(WrapOrScrollText), findsNWidgets(2));
      expectNeverClipped(tester, find.text(kLongName));
      for (final width in tester
          .widgetList<WrapOrScrollText>(find.byType(WrapOrScrollText))
          .map((w) => w.style.fontSize)) {
        expect(width, isNotNull);
      }
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('bill row keeps the supplier name readable next to the date',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kLongName);

      await tester.pumpWidget(wrapWithDb(const BillListScreen(), db));
      await pumpUntilVisible(tester, find.text('INV-001'));

      final row = find.textContaining(kLongName);
      expect(row, findsOneWidget);
      expectNeverClipped(tester, row);
      // The column the row hands the text (never the painted, possibly
      // scrolled, text width).
      final double width = tester.getSize(find.byType(WrapOrScrollText)).width;
      final String rowText =
          tester.renderObject<RenderParagraph>(row).text.toPlainText();
      expectFitsShipped(rowText, width, fontSize: 13, maxLines: 2);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('add-bill field shows the full selected supplier name',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      final supplier = await _seed(db, kLongName);

      await tester.pumpWidget(
        wrapWithDb(AddBillScreen(presetDistributorId: supplier.id), db),
      );
      await pumpUntilVisible(tester, find.text(kLongName));

      final name = find.text(kLongName);
      expect(tester.widget<Text>(name).maxLines, greaterThanOrEqualTo(2));
      expectNeverClipped(tester, find.text(kLongName));
      expectFitsShipped(
          kLongName, tester.renderObject<RenderParagraph>(name).size.width,
          fontSize: 16, weight: FontWeight.w600, maxLines: 3);
      await disposeTree(tester);
    });

    testWidgets('supplier picker sheet shows the full name', (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kLongName);

      await tester.pumpWidget(wrapWithDb(const AddBillScreen(), db));
      await pumpUntilVisible(tester, find.text('Select supplier'));

      await tester.tap(find.text('Select supplier'));
      await pumpUntilVisible(tester, find.text(kLongName));

      expectNeverClipped(tester, find.text(kLongName));
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('unbreakable name wraps instead of breaking mid-word',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kUnbreakableName);

      await tester.pumpWidget(wrapWithDb(const DistributorListScreen(), db));
      await pumpUntilVisible(tester, find.text(kUnbreakableName));

      expectFitsShipped(kUnbreakableName, _nameWidth(tester),
          fontSize: 15, weight: FontWeight.w600);
      expectNeverClipped(tester, find.text(kUnbreakableName));
      await disposeTree(tester);
    });

    testWidgets('Devanagari supplier name lays out safely', (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kHindiName);

      await tester.pumpWidget(wrapWithDb(const DistributorListScreen(), db));
      await pumpUntilVisible(tester, find.text(kHindiName));

      // Roboto ships no Devanagari, so this asserts layout rather than glyphs:
      // a real column and no clipping.
      expect(_nameWidth(tester), greaterThanOrEqualTo(kMinNameColumnWidth));
      expectNeverClipped(tester, find.text(kHindiName));
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('absurdly long name scrolls instead of being cut down',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kAbsurdName);

      await tester.pumpWidget(wrapWithDb(const DistributorListScreen(), db));
      await pumpUntilVisible(tester, find.text(kAbsurdName));
      await pumpUntilNameRendered(tester, find.text(kAbsurdName));

      expectNeverClipped(tester, find.text(kAbsurdName));
      // It is alive: the name walks across its line.
      expect(await pumpUntilMovedLeft(tester, find.text(kAbsurdName)), isTrue,
          reason: 'an absurdly long name must travel, not be cut');
      // Nothing else in the row was lost to the long name.
      expect(find.text('₹21,552'), findsOneWidget);
      expect(find.byTooltip('More options'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('an empty name does not break the row', (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await db.addDistributor(DistributorsCompanion.insert(name: ''));

      await tester.pumpWidget(wrapWithDb(const DistributorListScreen(), db));
      await pumpUntilVisible(tester, find.byTooltip('More options'));

      // The avatar falls back to a placeholder glyph and the row still lays out.
      expect(find.text('?'), findsWidgets);
      expect(tester.takeException(), isNull);
      await disposeTree(tester);
    });

    testWidgets('delete confirmation survives a very long name',
        (tester) async {
      phoneSurface(tester);
      final db = _openDb();
      await _seed(db, kAbsurdName);

      await tester.pumpWidget(wrapWithDb(const DistributorListScreen(), db));
      await pumpUntilVisible(tester, find.text(kAbsurdName));
      await pumpUntilNameRendered(tester, find.text(kAbsurdName));

      await tester.tap(find.byTooltip('More options'));
      await pumpUntilVisible(tester, find.text('Delete'));
      // A sheet's text exists in the tree while it is still sliding up, so the
      // tap must wait for the animation, not just for the widget.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Delete'));
      await pumpUntilVisible(
          tester, find.textContaining('permanently deletes'));
      await tester.pump(const Duration(milliseconds: 600));

      // The sheet scrolls, so its buttons stay reachable with a huge title.
      expect(tester.takeException(), isNull);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Delete'), findsWidgets);
      await disposeTree(tester);
    });
  });
}
