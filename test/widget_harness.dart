// Shared widget-test harness for BillMed.
//
// Discovered by iterating until green (mirrors widget_flows_test.dart):
// - No pumpAndSettle: loading states render a SkeletonList shimmer
//   (AnimationController.repeat → infinite), so pumpAndSettle never settles.
//   Bounded pumps are used instead.
// - Tall surface: loading skeletons are plain Columns and overflow the default
//   600 px viewport, which flutter_test records as a failure.
// - pump-until-visible: stream emission timing varies under load, so tests pump
//   until the expected content appears (bounded) instead of a fixed count.
// - Explicit unmount at test end: drift schedules a zero-duration timer when
//   its watched-query streams are cancelled on ProviderScope dispose, which
//   flutter_test reports as "A Timer is still pending".
import 'package:billmed/database/database.dart';
import 'package:billmed/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// [home] inside a ProviderScope whose database is the given in-memory DB.
Widget wrapWithDb(Widget home, BillMedDatabase db) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(home: home),
    );

/// Tall test surface so transient skeleton overflow cannot fail a test.
void tallSurface(
  WidgetTester tester, {
  Size size = const Size(900, 1600),
}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// The reporting user's phone: 1080 x 2400 px at 2.75x → 393 x 873 logical dp.
/// Row layouts that fit on a tablet width break here, so name overflow is
/// tested at exactly this width.
void phoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Pumps until [done] or a bound (60 × 100 ms fake time), so slow stream
/// emission under load can't flake the suite — and an unmet condition fails on
/// the subsequent expect, never by hanging.
Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] matches at least one widget (bounded, see [pumpUntil]).
Future<void> pumpUntilVisible(WidgetTester tester, Finder finder) =>
    pumpUntil(tester, () => finder.evaluate().isNotEmpty);

/// Pumps until [finder] matches nothing (bounded, see [pumpUntil]).
Future<void> pumpUntilGone(WidgetTester tester, Finder finder) =>
    pumpUntil(tester, () => finder.evaluate().isEmpty);

/// Unmounts the tree and flushes drift's stream-cancel timer inside the test
/// body, keeping flutter_test's post-test timer check clean.
Future<void> disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(Container());
  await tester.pump(const Duration(milliseconds: 50));
}
