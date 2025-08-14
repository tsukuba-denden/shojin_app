import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'screens/problem_detail_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen_new.dart'; // Import new home screen
import 'screens/browser_screen.dart'; // Import the new browser screen
import 'providers/theme_provider.dart';
import 'providers/template_provider.dart';
import 'providers/contest_provider.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // 追加
import 'l10n/app_localizations.dart'; // 追加 (生成されるファイル)
import 'services/auto_update_manager.dart'; // Add auto update manager
import 'services/notification_service.dart'; // Import NotificationService

void main() async {
  // Flutter Engineの初期化を保証
  WidgetsFlutterBinding.ensureInitialized();

  // NotificationServiceの初期化と権限リクエスト
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();

  // Providerのインスタンスを作成
  final themeProvider = ThemeProvider();
  final templateProvider = TemplateProvider();
  final contestProvider = ContestProvider();

  // 非同期でテーマとテンプレートの読み込みが完了するのを待つ
  // 各プロバイダー内の_loadFromPrefsの完了を待つため、
  // isLoadingがfalseになるまで短い遅延を入れて待機する
  while (themeProvider.isLoading || templateProvider.isLoading) {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  runApp(
    MultiProvider(      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: templateProvider),
        ChangeNotifierProvider.value(value: contestProvider),
      ],
      child: const MyApp(),
    ),
  );
  developer.log('App started successfully');
}

// デフォルトのカラースキーム（MaterialYou ON時）
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

// カスタムテーマ（MaterialYou OFF時）
final _lightCustomTheme = ColorScheme.fromSeed(
  seedColor: Colors.purple,
  brightness: Brightness.light,
).copyWith(
  primary: const Color(0xFF4C51C0),
);

final _darkCustomTheme = ColorScheme.fromSeed(
  seedColor: Colors.purple,
  brightness: Brightness.dark,
).copyWith(
  primary: const Color(0xFFBFC1FF),
  surface: const Color(0xFF131316),
);

// ピュアブラックモードのカラースキーム（カスタムテーマベース）
final _pureBlackColorScheme = ColorScheme.fromSeed(
  seedColor: Colors.purple,
  brightness: Brightness.dark,
).copyWith(
  primary: const Color(0xFFBFC1FF),
  surface: Colors.black,
  surfaceContainerHighest: Colors.black,
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
        // Material You / Custom theme 基本スキーム決定
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;
        if (themeProvider.useMaterialYou) {
          lightColorScheme = lightDynamic ?? _defaultLightColorScheme;
          darkColorScheme = themeProvider.isPureBlack
              ? _pureBlackColorScheme
              : (darkDynamic ?? _defaultDarkColorScheme);
        } else {
          lightColorScheme = _lightCustomTheme;
          darkColorScheme = themeProvider.isPureBlack
              ? _pureBlackColorScheme
              : _darkCustomTheme;
        }

        // AtCoderレーティング色をそのままテーマの主色に適用（ハーモナイズなしで忠実に）
        if (themeProvider.useAtcoderRatingColor &&
            themeProvider.atcoderAccentColor != null) {
          final seed = themeProvider.atcoderAccentColor!;
          final onPrimary = seed.computeLuminance() > 0.5 ? Colors.black : Colors.white;

          lightColorScheme = lightColorScheme.copyWith(
            primary: seed,
            onPrimary: onPrimary,
            primaryContainer: seed,
            onPrimaryContainer: onPrimary,
            surfaceTint: Colors.transparent,
          );

          final baseDark = darkColorScheme;
          final darkAdjusted = baseDark.copyWith(
            primary: seed,
            onPrimary: onPrimary,
            primaryContainer: seed,
            onPrimaryContainer: onPrimary,
            surfaceTint: Colors.transparent,
          );
          darkColorScheme = themeProvider.isPureBlack
              ? darkAdjusted.copyWith(
                  surface: Colors.black,
                  surfaceContainerHighest: Colors.black,
                  onSurface: Colors.white,
                  surfaceTint: Colors.transparent,
                )
              : darkAdjusted;
        }

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
          bodyMedium: GoogleFonts.notoSansJp(fontSize: 14),          bodySmall: GoogleFonts.notoSansJp(fontSize: 12),
          labelLarge: GoogleFonts.notoSansJp(fontSize: 14, fontWeight: FontWeight.w500),
          labelMedium: GoogleFonts.notoSansJp(fontSize: 12, fontWeight: FontWeight.w500),
          labelSmall: GoogleFonts.notoSansJp(fontSize: 11, fontWeight: FontWeight.w500),
        );

        return MaterialApp(
          title: 'Shojin App',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ja'),
          onGenerateTitle: (BuildContext context) => AppLocalizations.of(context)!.appTitle, // 修正
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
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              indicatorColor: lightColorScheme.primary.withOpacity(0.20),
              iconTheme: MaterialStateProperty.resolveWith((states) {
                final color = states.contains(MaterialState.selected)
                    ? lightColorScheme.primary
                    : lightColorScheme.onSurfaceVariant;
                return IconThemeData(color: color);
              }),
              labelTextStyle: MaterialStateProperty.resolveWith((states) {
                final color = states.contains(MaterialState.selected)
                    ? lightColorScheme.primary
                    : lightColorScheme.onSurfaceVariant;
                return TextStyle(color: color);
              }),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              margin: const EdgeInsets.all(8),
              // MaterialYou使用時のコントラスト改善
              surfaceTintColor: themeProvider.useMaterialYou 
                  ? lightColorScheme.primary.withOpacity(0.08)
                  : null,
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
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              indicatorColor: darkColorScheme.primary.withOpacity(0.20),
              iconTheme: MaterialStateProperty.resolveWith((states) {
                final color = states.contains(MaterialState.selected)
                    ? darkColorScheme.primary
                    : darkColorScheme.onSurfaceVariant;
                return IconThemeData(color: color);
              }),
              labelTextStyle: MaterialStateProperty.resolveWith((states) {
                final color = states.contains(MaterialState.selected)
                    ? darkColorScheme.primary
                    : darkColorScheme.onSurfaceVariant;
                return TextStyle(color: color);
              }),
            ),
            cardTheme: CardThemeData(
              elevation: 2,
              margin: const EdgeInsets.all(8),
              color: themeProvider.isPureBlack ? const Color(0xFF121212) : null,
              // MaterialYou使用時のコントラスト改善
              surfaceTintColor: themeProvider.useMaterialYou 
                  ? darkColorScheme.primary.withOpacity(0.08)
                  : null,
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
  int _selectedIndex = 0; // Default to new Home tab
  String _currentProblemId = 'default_problem';
  String? _problemIdFromWebView;
  UpdateLifecycleManager? _updateLifecycleManager;

  @override
  void initState() {
    super.initState();
    
    // Initialize auto update manager for startup update checks
    _updateLifecycleManager = UpdateLifecycleManager(context);
    _updateLifecycleManager!.startListening();
    
    // Schedule initial update check after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoUpdateManager = AutoUpdateManager();
      autoUpdateManager.checkForUpdatesOnStartup(context);
    });
  }

  @override
  void dispose() {
    _updateLifecycleManager?.stopListening();
    super.dispose();
  }

  // Callback for ProblemDetailScreen -> EditorScreen update
  void _updateProblemIdForEditor(String newProblemUrl) {
     final uri = Uri.parse(newProblemUrl);
     if (uri.host == 'atcoder.jp' && uri.pathSegments.length == 4 &&
         uri.pathSegments[0] == 'contests' && uri.pathSegments[2] == 'tasks') {
       final problemId = uri.pathSegments[3]; // e.g., abc388_a
       // Check if mounted before calling setState
       if (mounted) {
         setState(() {
           _currentProblemId = problemId;
         });
       }
       developer.log('Editor Problem ID updated via ProblemDetailScreen: $_currentProblemId', name: 'MainScreen');
     } else {
       developer.log('Could not extract problem ID from URL: $newProblemUrl', name: 'MainScreen');
     }
  }

  // Handles navigation from HomeScreen (WebView) - Now a class method
  void _navigateToProblemTabWithId(String problemId) {
    developer.log('_navigateToProblemTabWithId called with problemId: $problemId', name: 'MainScreen');
    if (mounted) {
      setState(() {
        _selectedIndex = 2; // Index of Problems tab
        _problemIdFromWebView = problemId; // Store the ID in the state variable
      });
    }
  }
  // Builds the list of screens - Now a class method
  List<Widget> _buildScreens() {
    String? idToPass = _problemIdFromWebView;
    developer.log('_buildScreens: Passing problemIdToLoad=$idToPass', name: 'MainScreen');

    // Reset the ID after using it in this build cycle.
    // Use addPostFrameCallback to schedule the reset after the build.
    if (_problemIdFromWebView != null) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         // Check if still mounted and if the ID hasn't been changed again by another event
         if (mounted && _problemIdFromWebView == idToPass) {
            setState(() {
               _problemIdFromWebView = null;
               developer.log('Reset _problemIdFromWebView in post frame callback', name: 'MainScreen');
            });
         }
       });
    }

    return [
      NewHomeScreen(key: const ValueKey('home')), // Index 0
      BrowserScreen(
        key: const ValueKey('browser'),
        navigateToProblem: _navigateToProblemTabWithId,
      ), // Index 1 - Use imported screen
      ProblemsScreen( // Index 2
          key: const ValueKey('problems'),
          problemIdToLoad: idToPass,
          onProblemChanged: _updateProblemIdForEditor
      ),
      EditorScreen( // Index 3
        key: ValueKey('editor_$_currentProblemId'),
        problemId: _currentProblemId,
      ),
      SettingsScreen(key: const ValueKey('settings')), // Index 4
    ];
  }

  void _onItemTapped(int index) {
    // 触覚フィードバックを追加
    HapticFeedback.lightImpact(); 
    _hideKeyboard(context);
    // Check if mounted before calling setState
    if (mounted) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  /// Hides the keyboard by unfocussing the current (textform) element
  /// 
  /// 現在の（テキストフォーム）要素のフォーカスを外してキーボードを隠す
  void _hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
  @override
  Widget build(BuildContext context) {
    // Now _buildScreens is a class method and uses the state variable _problemIdFromWebView
    final screens = _buildScreens();

    return GestureDetector(
      onTap: () {
        // Hide the keyboard on tap outside of the keyboard
        // キーボードの外側のタップでキーボードを隠す
        _hideKeyboard(context);
      },      child: Scaffold(
        extendBody: true, // Allow body to extend behind BottomNavigationBar for backdrop blur
        body: SafeArea(
          bottom: false, // allow content under BottomNavigationBar for BackdropFilter
          child: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
        ),
        bottomNavigationBar: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              // Adjust opacity from settings
              color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withOpacity(Provider.of<ThemeProvider>(context).navBarOpacity),
              child: Material(
                color: Colors.transparent, // Let the translucent container show
                child: NavigationBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent, // Disable M3 surface tint
                  shadowColor: Colors.transparent,     // Remove shadow
                  elevation: 0,
                  onDestinationSelected: _onItemTapped,
                  selectedIndex: _selectedIndex,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'ホーム',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.public_outlined),
                      selectedIcon: Icon(Icons.public),
                      label: 'ブラウザ',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.list_alt_outlined),
                      selectedIcon: Icon(Icons.list_alt),
                      label: '問題',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.code_outlined),
                      selectedIcon: Icon(Icons.code),
                      label: 'エディタ',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: '設定',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ProblemsScreen はコールバックを受け取るように修正が必要
class ProblemsScreen extends StatelessWidget {
  final String? problemIdToLoad; // ID from WebView click
  final Function(String) onProblemChanged; // Callback for manual fetch

  const ProblemsScreen({
    super.key,
    this.problemIdToLoad,
    required this.onProblemChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Add log to see the value being passed down
    developer.log('ProblemsScreen build: problemIdToLoad=$problemIdToLoad', name: 'ProblemsScreen');
    // Pass both the ID to load and the callback
    return ProblemDetailScreen(
      problemIdToLoad: problemIdToLoad, // Pass the ID down
      onProblemChanged: onProblemChanged, // Pass the callback down
    );
  }
}