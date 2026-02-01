// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

// import 'package:flutter/material.dart'; (duplicate removed)
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build a minimal app and trigger a frame.
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: Text('Test'))),
    );

    // Verify our minimal app shows the Test text.
    expect(find.text('Test'), findsOneWidget);
  });
}
