import 'package:flutter_test/flutter_test.dart';

import 'package:parentshield/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ParentShieldApp());
    expect(find.text('ParentShield'), findsWidgets);
  });
}
