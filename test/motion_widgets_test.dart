// Motion-widget smoke tests: MeshHeader, GlassBar, DrawSparkline,
// TiltOnScroll. Bounded pumps only (no pumpAndSettle): DrawSparkline owns a
// 900ms AnimationController, so fixed short pumps are used instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:billmed/widgets/draw_sparkline.dart';
import 'package:billmed/widgets/glass.dart';
import 'package:billmed/widgets/mesh_header.dart';
import 'package:billmed/widgets/sparkline.dart';
import 'package:billmed/widgets/tilt_hero.dart';

void main() {
  testWidgets('MeshHeader pumps at height 200 without crashing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MeshHeader(height: 200)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MeshHeader), findsOneWidget);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    expect(tester.getSize(find.byType(MeshHeader)), const Size(800, 200));
  });

  testWidgets('GlassBar shows its child without crashing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GlassBar(child: Text('frost'))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(GlassBar), findsOneWidget);
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.text('frost'), findsOneWidget);
  });

  testWidgets('DrawSparkline shows chart for values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: DrawSparkline(values: [100.0, 200.0, 150.0]),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DrawSparkline), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DrawSparkline),
        matching: find.byType(MiniSparkline),
      ),
      findsOneWidget,
    );
  });

  testWidgets('DrawSparkline with empty values renders SizedBox.shrink',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DrawSparkline(values: [])),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DrawSparkline), findsOneWidget);
    expect(find.byType(MiniSparkline), findsNothing);
    expect(
      find.descendant(
        of: find.byType(DrawSparkline),
        matching: find.byType(SizedBox),
      ),
      findsOneWidget,
    );
  });

  testWidgets('TiltOnScroll pumps, scrolls, no crash', (tester) async {
    final ctrl = ScrollController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: ctrl,
            children: [
              TiltOnScroll(
                scrollController: ctrl,
                child: const Text('tilt child'),
              ),
              for (var i = 0; i < 30; i++) ListTile(title: Text('row $i')),
            ],
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TiltOnScroll), findsOneWidget);
    expect(find.text('tilt child'), findsOneWidget);

    ctrl.jumpTo(200);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // The header scrolled out of the viewport (ListView drops off-screen
    // children), so scroll back before asserting it survived the scroll.
    ctrl.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TiltOnScroll), findsOneWidget);
    expect(find.text('tilt child'), findsOneWidget);
  });
}
