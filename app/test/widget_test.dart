import 'package:flutter_test/flutter_test.dart';
import 'package:bamabao/main.dart';

void main() {
  testWidgets('App launches without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BamabaoApp());
    await tester.pump();

    // Just verify the app renders without crashing
    expect(tester.takeException(), isNull);
  });
}
