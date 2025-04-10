import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/problem_detail_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/template_edit_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/template_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => TemplateProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// デフォルトのカラースキーム
const _defaultLightColorScheme = ColorScheme.light(
  primary: Colors.blue,
  onPrimary: Colors.white,
  secondary: Colors.blueAccent,
);

const _defaultDarkColorScheme = ColorScheme.dark(
  primary: Colors.blue,
  onPrimary: Colors.black,
  secondary: Colors.blueAccent,
);

// ピュアブラックモードのカラースキーム
final _pureBlackColorScheme = ColorScheme.dark(
  primary: Colors.blue,
  onPrimary: Colors.white,
  secondary: Colors.blueAccent,
  background: Colors.black,
  surface: Colors.black,
  surfaceVariant: Colors.black,
  onSurface: Colors.white,
  surfaceTint: Colors.transparent,
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // テーマプロバイダーの状態を監視
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        // ダイナミックカラーが利用できる場合はそれを使用し、利用できない場合はデフォルトのカラースキームを使用
        ColorScheme lightColorScheme = lightDynamic ?? _defaultLightColorScheme;
        // ピュアブラックモードが選択されている場合はピュアブラックカラースキームを使用
        ColorScheme darkColorScheme = themeProvider.isPureBlack
            ? _pureBlackColorScheme
            : (darkDynamic ?? _defaultDarkColorScheme);

        // Noto Sans JPフォントをテキストテーマに適用
        final textTheme = TextTheme(
          displayLarge: GoogleFonts.notoSansJp(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.notoSansJp(fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: GoogleFonts.notoSansJp(fontSize: 24, fontWeight: FontWeight.bold),
          headlineLarge: GoogleFonts.notoSansJp(fontSize: 22, fontWeight: FontWeight.w600),
          headlineMedium: GoogleFonts.notoSansJp(fontSize: 20, fontWeight: FontWeight.w600),
          headlineSmall: GoogleFonts.notoSansJp(fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.notoSansJp(fontSize: 18, fontWeight: FontWeight.w500),
          titleMedium: GoogleFonts.notoSansJp(fontSize: 16, fontWeight: FontWeight.w500),
          titleSmall: GoogleFonts.notoSansJp(fontSize: 14, fontWeight: FontWeight.w500),
          bodyLarge: GoogleFonts.notoSansJp(fontSize: 16),
          bodyMedium: GoogleFonts.notoSansJp(fontSize: 14),
          bodySmall: GoogleFonts.notoSansJp(fontSize: 12),
          labelLarge: GoogleFonts.notoSansJp(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: GoogleFonts.notoSansJp(fontSize: 12, fontWeight: FontWeight.w500),
          labelSmall: GoogleFonts.notoSansJp(fontSize: 11, fontWeight: FontWeight.w500),
        );        return MaterialApp(
          title: 'Shojin App',
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
            appBarTheme: const AppBarTheme(
              centerTitle: true,
              elevation: 2,
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 2,
              ),
            ),
            cardTheme: const CardTheme(
              elevation: 2,
              margin: EdgeInsets.all(8),
            ),
            textTheme: textTheme,
            fontFamily: GoogleFonts.notoSansJp().fontFamily,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 2,
              backgroundColor: themeProvider.isPureBlack ? Colors.black : null,
            ),
            cardTheme: CardTheme(
              elevation: 2,
              margin: const EdgeInsets.all(8),
              color: themeProvider.isPureBlack ? const Color(0xFF121212) : null,
            ),
            scaffoldBackgroundColor: themeProvider.isPureBlack ? Colors.black : null,
            textTheme: textTheme,
            fontFamily: GoogleFonts.notoSansJp().fontFamily,
          ),
          themeMode: themeProvider.themeModeForFlutter,
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  static final List<Widget> _screens = [
    const HomeScreen(),
    const ProblemsScreen(),
    const EditorScreen(),
    const SettingsScreen(),
  ];
  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        title: const Text('Shojin App'),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: _onItemTapped,
        selectedIndex: _selectedIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            label: '問題',
          ),
          NavigationDestination(
            icon: Icon(Icons.code),
            label: 'エディタ',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: '設定',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'ホーム画面',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'AtCoderの練習アプリへようこそ',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProblemsScreen extends StatelessWidget {
  const ProblemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 問題詳細画面を直接表示する
    return const ProblemDetailScreen();
  }
}
  
  // テーマモードに対応するアイコンを返す
  Widget _getThemeIcon(ThemeModeOption mode) {
    switch (mode) {
      case ThemeModeOption.system:
        return const Icon(Icons.settings_suggest);
      case ThemeModeOption.light:
        return const Icon(Icons.light_mode);
      case ThemeModeOption.dark:
        return const Icon(Icons.dark_mode);
      case ThemeModeOption.pureBlack:
        return const Icon(Icons.nights_stay);
    }
  }