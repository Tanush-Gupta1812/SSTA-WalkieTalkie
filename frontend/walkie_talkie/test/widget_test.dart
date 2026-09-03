import 'package:flutter_test/flutter_test.dart';
import 'package:walkie_talkie/main.dart';

void main() {
  testWidgets('WalkieApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WalkieApp());
    expect(find.text('Walkie Channels'), findsOneWidget);
  });
}
