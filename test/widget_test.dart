import 'package:flutter_test/flutter_test.dart';
import 'package:dawa/app.dart';

void main() {
  testWidgets('DAWA App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DawaApp());
    expect(find.byType(DawaApp), findsOneWidget);
  });
}
