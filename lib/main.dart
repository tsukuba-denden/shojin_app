import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart'; // Import webview_flutter
import 'screens/problem_detail_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/template_provider.dart';
import 'dart:developer' as developer; // developerログのために追加

void main() async {
  // Flutter Engineの初期化を保証
  WidgetsFlutterBinding.ensureInitialized();

  // Providerのインスタンスを作成
  final themeProvider = ThemeProvider();
  final templateProvider = TemplateProvider();

  // 非同期でテーマとテンプレートの読み込みが完了するのを待つ
  // 各プロバイダー内の_loadFromPrefsの完了を待つため、
  // isLoadingがfalseになるまで短い遅延を入れて待機する
  while (themeProvider.isLoading || templateProvider.isLoading) {
    await Future.delayed(const Duration(milliseconds: 10));
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: templateProvider),
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
  String _currentProblemId = 'default_problem'; // Keep this for EditorScreen

  // This callback is for ProblemDetailScreen -> EditorScreen update
  void _updateProblemIdForEditor(String newProblemUrl) {
     // Extract problemId from URL if needed, or adjust Problem model/service
     // Assuming AtCoderService returns a Problem object with an id field like 'abc388_a'
     // Or modify ProblemDetailScreen's onProblemChanged to pass the id directly
     final uri = Uri.parse(newProblemUrl);
     if (uri.host == 'atcoder.jp' && uri.pathSegments.length == 4 &&
         uri.pathSegments[0] == 'contests' && uri.pathSegments[2] == 'tasks') {
       final problemId = uri.pathSegments[3]; // e.g., abc388_a
       setState(() {
         _currentProblemId = problemId;
       });
       developer.log('Editor Problem ID updated via ProblemDetailScreen: $_currentProblemId', name: 'MainScreen');
     } else {
       developer.log('Could not extract problem ID from URL: $newProblemUrl', name: 'MainScreen');
       // Handle cases where URL might not be a standard problem URL if necessary
       // Maybe set _currentProblemId = 'default_problem' or some error state
     }
  }

  // This function handles navigation from HomeScreen (WebView)
  void navigateToProblemTabWithId(String problemId) {
    developer.log('navigateToProblemTabWithId called with problemId: $problemId', name: 'MainScreen');
    setState(() {
      _selectedIndex = 1; // Switch to Problems tab
      // We don't directly set _currentProblemId here for ProblemDetailScreen,
      // instead, we pass it down. We update _currentProblemId via _updateProblemIdForEditor
      // when ProblemDetailScreen successfully fetches.
    });
     // Trigger update in ProblemsScreen/ProblemDetailScreen by passing the new ID
     // This requires ProblemsScreen to handle the ID change.
     // Let's modify _buildScreens to pass the ID intended for ProblemDetailScreen.
  }


  List<Widget> _buildScreens(String problemIdToLoad) { // Accept problemId
    return [
      HomeScreen(navigateToProblem: navigateToProblemTabWithId), // Pass the correct function
      // Pass the problemId from WebView and the callback for manual fetch
      ProblemsScreen(
          problemIdToLoad: problemIdToLoad, // Pass the ID from WebView click
          onProblemChanged: _updateProblemIdForEditor // For manual fetch update
      ),
      EditorScreen(
        key: ValueKey(_currentProblemId),
        problemId: _currentProblemId, // Editor uses the ID updated by onProblemChanged
      ),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Determine the problemId to load based on current state or navigation trigger
    // This logic needs refinement. How do we pass the ID from navigateToProblemTabWithId
    // into the build method cleanly? Using a state variable specifically for this might work.

    // Let's introduce a state variable for the ID triggered by WebView
    String? _problemIdFromWebView;

    // Modify navigateToProblemTabWithId to update this state variable
    void navigateToProblemTabWithId(String problemId) {
      developer.log('navigateToProblemTabWithId called with problemId: $problemId', name: 'MainScreen');
      setState(() {
        _selectedIndex = 1; // Switch to Problems tab
        _problemIdFromWebView = problemId; // Store the ID to pass down
      });
    }

    // Rebuild _buildScreens to use the state variable
    List<Widget> _buildScreens() {
      String? idToPass = _problemIdFromWebView;
      _problemIdFromWebView = null; // Reset after passing down once

      return [
        HomeScreen(navigateToProblem: navigateToProblemTabWithId),
        ProblemsScreen(
            // Pass the ID only if it came from WebView this build cycle
            problemIdToLoad: idToPass,
            onProblemChanged: _updateProblemIdForEditor
        ),
        EditorScreen(
          key: ValueKey(_currentProblemId),
          problemId: _currentProblemId,
        ),
        const SettingsScreen(),
      ];
    }


    final screens = _buildScreens();

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: screens,
        ),
      ),
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

// HomeScreenにコールバックを受け取るプロパティを追加
class HomeScreen extends StatefulWidget {
  final Function(String) navigateToProblem; // コールバック関数を受け取る

  const HomeScreen({super.key, required this.navigateToProblem});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {},
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            developer.log('Navigating to: ${request.url}', name: 'HomeScreenWebView');

            if (uri.host == 'atcoder.jp' && uri.pathSegments.length == 4 &&
                uri.pathSegments[0] == 'contests' && uri.pathSegments[2] == 'tasks') {
              final taskId = uri.pathSegments[3]; // Correctly extract taskId (e.g., abc388_a)
              final problemId = taskId; // Use taskId as problemId

              developer.log('AtCoder problem page detected: $problemId', name: 'HomeScreenWebView');
              widget.navigateToProblem(problemId); // Pass the correct ID
              return NavigationDecision.prevent;
            }

            if (request.url.startsWith('https://atcoder-novisteps.vercel.app/')) {
               developer.log('Allowing navigation within NoviSteps', name: 'HomeScreenWebView');
              return NavigationDecision.navigate;
            }

            developer.log('Preventing navigation to external site: ${request.url}', name: 'HomeScreenWebView');
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse('https://atcoder-novisteps.vercel.app/problems'));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
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
    // Pass both the ID to load and the callback
    return ProblemDetailScreen(
      problemIdToLoad: problemIdToLoad, // Pass the ID down
      onProblemChanged: onProblemChanged, // Pass the callback down
    );
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