import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shojin_app/main.dart';
import 'package:shojin_app/providers/theme_provider.dart';
import 'package:shojin_app/providers/template_provider.dart';
import 'package:shojin_app/providers/contest_provider.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => TemplateProvider()),
          ChangeNotifierProvider(create: (_) => ContestProvider()),
        ],
        child: const MyApp(),
      ),
    );

    // Wait for all frames to settle.
    await tester.pumpAndSettle(const Duration(seconds: 5)); // Increased duration to allow for async operations

    // Verify that our app shows the main screen.
    expect(find.byType(MainScreen), findsOneWidget);
  });
}
