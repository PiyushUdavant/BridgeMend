// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:mend_ai/main.dart';

void main() {
  testWidgets('App launches with welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MendApp());

    // Verify that the welcome screen is displayed
    expect(find.text('Mend'), findsOneWidget);
    expect(find.text('Your AI-powered relationship companion'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Join Your Partner'), findsOneWidget);
  });
}
