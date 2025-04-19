import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart'; // Import webview_flutter
import 'package:shared_preferences/shared_preferences.dart'; // For storing home sites
import 'dart:convert'; // For JSON encoding/decoding
import 'screens/problem_detail_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/template_provider.dart';
import 'dart:developer' as developer; // developerログのために追加
import 'package:flutter/services.dart'; // 触覚フィードバックのために追加
import 'dart:ui';

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
  developer.log('App started successfully');
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
  String _currentProblemId = 'default_problem'; // For EditorScreen
  String? _problemIdFromWebView; // State variable to hold ID from WebView click

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
    // Check if mounted before calling setState
    if (mounted) {
      setState(() {
        _selectedIndex = 1; // Switch to Problems tab
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
      HomeScreen(navigateToProblem: _navigateToProblemTabWithId), // Pass the class method
      ProblemsScreen(
          problemIdToLoad: idToPass, // Pass the ID from state
          onProblemChanged: _updateProblemIdForEditor
      ),
      EditorScreen(
        key: ValueKey(_currentProblemId),
        problemId: _currentProblemId,
      ),
      const SettingsScreen(),
    ];
  }

  void _onItemTapped(int index) {
    // 触覚フィードバックを追加
    HapticFeedback.lightImpact(); 
    // Check if mounted before calling setState
    if (mounted) {
      setState(() {
        _selectedIndex = index;
        // Optional: Clear the pending problem ID if user manually switches tabs
        // if (_problemIdFromWebView != null) {
        //   _problemIdFromWebView = null;
        //   developer.log('Reset _problemIdFromWebView due to manual tab switch', name: 'MainScreen');
        // }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Now _buildScreens is a class method and uses the state variable _problemIdFromWebView
    final screens = _buildScreens();

    return Scaffold(
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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
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
            ),
          ),
        ),
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
  late WebViewController _controller;
  late SharedPreferences _prefs;
  List<Map<String, String>> _sites = [];
  bool _isControllerReady = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final sitesJson = _prefs.getStringList('homeSites') ?? [];
    _sites = sitesJson.map((e) => Map<String, String>.from(jsonDecode(e))).toList();
    // WebViewControllerの初期化
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
              widget.navigateToProblem(uri.pathSegments[3]);
              return NavigationDecision.prevent;
            }
            if (request.url.startsWith('https://atcoder-novisteps.vercel.app/')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_sites.isNotEmpty ? _sites.first['url']! : 'https://atcoder-novisteps.vercel.app/problems'));
    _isControllerReady = true;
    setState(() {});
  }

  Future<void> _addSite() async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サイトを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'タイトル'),
            ),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final url = urlController.text.trim();
              if (title.isNotEmpty && url.isNotEmpty) {
                _sites.add({'title': title, 'url': url});
                final list = _sites.map((e) => jsonEncode(e)).toList();
                await _prefs.setStringList('homeSites', list);
                setState(() {});
                Navigator.pop(context);
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._sites.map((site) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ElevatedButton(
                  onPressed: () => _controller.loadRequest(Uri.parse(site['url']!)),
                  child: Text(site['title']!),
                ),
              )),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ElevatedButton(
                  onPressed: _addSite,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isControllerReady
              ? WebViewWidget(controller: _controller)
              : const Center(child: CircularProgressIndicator()),
        ),
      ],
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