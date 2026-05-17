import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:billmed/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Splash screen shows BILLMED', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: BillMedApp()),
    );
    await tester.pump();
    expect(find.text('BILLMED'), findsOneWidget);
  });
}
