import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shojin_app/main.dart';
import 'package:shojin_app/providers/theme_provider.dart';
import 'package:shojin_app/providers/template_provider.dart';
import 'package:shojin_app/providers/contest_provider.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
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
    // Let initial async work settle to avoid false negatives
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
