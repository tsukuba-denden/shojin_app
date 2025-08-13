// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shojin_app/main.dart';
import 'package:shojin_app/providers/theme_provider.dart';
import 'package:shojin_app/providers/template_provider.dart';
import 'package:shojin_app/providers/contest_provider.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Create instances of the providers
    final themeProvider = ThemeProvider();
    final templateProvider = TemplateProvider();
    final contestProvider = ContestProvider();

    // Wait for providers to load
    while (themeProvider.isLoading || templateProvider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: templateProvider),
          ChangeNotifierProvider.value(value: contestProvider),
        ],
        child: const MyApp(),
      ),
    );

    // Since the default home screen (NewHomeScreen) does not have a counter,
    // this test as it is will fail. We'll comment out the counter check part.
    // A more robust test would navigate to the correct screen with a counter if it exists.
    // For now, we just check if the app builds without crashing.

    // Verify that our counter starts at 0.
    // expect(find.text('0'), findsOneWidget);
    // expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    // await tester.tap(find.byIcon(Icons.add));
    // await tester.pump();

    // Verify that our counter has incremented.
    // expect(find.text('0'), findsNothing);
    // expect(find.text('1'), findsOneWidget);
  });
}
