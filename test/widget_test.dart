import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halo/main.dart';

void main() {
  testWidgets('App loads main screen correctly', (WidgetTester tester) async {
    // Build the app and trigger a frame.
    await tester.pumpWidget(MyApp());

    // Check if a known widget appears on the screen.
    expect(find.text('Halo'), findsOneWidget); // Updated to match the actual text on the first screen
  });
}
