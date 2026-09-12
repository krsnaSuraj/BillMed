// Bottom-sheet contract tests with a real MaterialApp.
// Bounded pumps only (no pumpAndSettle): sheets animate in/out, so tests
// pump until the sheet content appears/disappears with a fixed bound.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billmed/widgets/sheets.dart';

/// Pumps a real MaterialApp + Scaffold host and captures a context that sits
/// under the app Navigator (suitable for confirmSheet/showActionSheet).
Future<BuildContext> _pumpHost(WidgetTester tester) async {
  late BuildContext ctx;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) {
            ctx = c;
            return const Text('home');
          },
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return ctx;
}

/// Pumps until [done] or a bound (60 x 100ms), so sheet entrance/exit
/// animation timing under load can't flake the suite.
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pumpUntilVisible(WidgetTester tester, Finder finder) =>
    _pumpUntil(tester, () => finder.evaluate().isNotEmpty);

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) =>
    _pumpUntil(tester, () => finder.evaluate().isEmpty);

/// Lets the sheet entrance animation finish (bounded): right after
/// [_pumpUntilVisible] fires, the sheet is still sliding up, so its buttons
/// sit below the viewport and tap() would miss (leaving the sheet future
/// pending forever). One fixed pump covers the enter transition.
Future<void> _settleEntrance(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 500));

void main() {
  testWidgets('confirmSheet returns true on confirm tap', (tester) async {
    final ctx = await _pumpHost(tester);

    final fut = confirmSheet(ctx, title: 'Delete it?', message: 'Sure?');
    await _pumpUntilVisible(tester, find.text('Delete it?'));
    await _settleEntrance(tester);

    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(await fut.timeout(const Duration(seconds: 15)), isTrue);
    await _pumpUntilGone(tester, find.text('Delete it?'));
  });

  testWidgets('confirmSheet returns false on cancel', (tester) async {
    final ctx = await _pumpHost(tester);

    final fut = confirmSheet(ctx, title: 'Remove?', message: 'Sure?');
    await _pumpUntilVisible(tester, find.text('Remove?'));
    await _settleEntrance(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(await fut.timeout(const Duration(seconds: 15)), isFalse);
    await _pumpUntilGone(tester, find.text('Remove?'));
  });

  testWidgets(
      'confirmSheet second call while first open returns false (double-open guard)',
      (tester) async {
    final ctx = await _pumpHost(tester);

    final first = confirmSheet(ctx, title: 'First?', message: 'one');
    await _pumpUntilVisible(tester, find.text('First?'));

    // Second call while the first sheet is still open must be rejected.
    final second = await confirmSheet(ctx, title: 'Second?', message: 'two')
        .timeout(const Duration(seconds: 15));
    expect(second, isFalse);
    expect(find.text('Second?'), findsNothing);

    await _settleEntrance(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(await first.timeout(const Duration(seconds: 15)), isFalse);
    await _pumpUntilGone(tester, find.text('First?'));
  });

  testWidgets('showActionSheet returns selected value', (tester) async {
    final ctx = await _pumpHost(tester);

    final fut = showActionSheet<int>(
      ctx,
      title: 'Pick',
      options: const [
        SheetAction(icon: Icons.add, label: 'One', value: 1),
        SheetAction(icon: Icons.remove, label: 'Two', value: 2),
      ],
    );
    await _pumpUntilVisible(tester, find.text('Two'));
    await _settleEntrance(tester);

    await tester.tap(find.text('Two'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(await fut.timeout(const Duration(seconds: 15)), 2);
    await _pumpUntilGone(tester, find.text('Two'));
  });

  testWidgets('showActionSheet returns null on dismiss', (tester) async {
    final ctx = await _pumpHost(tester);

    final fut = showActionSheet<int>(
      ctx,
      options: const [
        SheetAction(icon: Icons.add, label: 'Solo', value: 1),
      ],
    );
    await _pumpUntilVisible(tester, find.text('Solo'));

    Navigator.of(ctx).pop();
    await tester.pump(const Duration(milliseconds: 100));

    expect(await fut.timeout(const Duration(seconds: 15)), isNull);
    await _pumpUntilGone(tester, find.text('Solo'));
  });
}
