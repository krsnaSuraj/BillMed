import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billmed/main.dart';

void main() {
  testWidgets('App displays BillMed title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BillMedApp()),
    );
    expect(find.text('BillMed'), findsWidgets);
  });
}
