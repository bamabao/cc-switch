import 'package:flutter_test/flutter_test.dart';
import 'package:bamabao/main.dart';

void main() {
  testWidgets('App launches with main screen', (WidgetTester tester) async {
    await tester.pumpWidget(const BamabaoApp());
    await tester.pump();

    // Verify the app title is shown
    expect(find.text('爸妈宝'), findsWidgets);
  });
}
