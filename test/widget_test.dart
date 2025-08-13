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

    // 非同期処理やアニメーションがすべて完了するまで待機します。
    // これにより、プロバイダのロードなども完了した状態になります。
    await tester.pumpAndSettle();

    // メイン画面が正しく表示されていることを確認します。
    // MainScreenの代わりに実際に最初に表示されるウィジェットを指定してください。
    // 例： expect(find.byType(NewHomeScreen), findsOneWidget);
    expect(find.byType(MainScreen), findsOneWidget);
  });
}