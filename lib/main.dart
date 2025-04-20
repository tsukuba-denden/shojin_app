import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'screens/problem_detail_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/template_provider.dart';
import 'dart:developer' as developer;
import 'package:flutter/services.dart';
import 'dart:ui';

// Add these imports
import 'package:http/http.dart' as http;
import 'package:favicon/favicon.dart';
import 'package:palette_generator/palette_generator.dart';


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

// Helper function to determine text color based on background
Color _getTextColorForBackground(Color backgroundColor) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

class _HomeScreenState extends State<HomeScreen> {
  late WebViewController _controller;
  late SharedPreferences _prefs;
  // Update site data structure to include optional faviconUrl and colorHex
  List<Map<String, String?>> _sites = [];
  bool _isControllerReady = false;
  bool _loadFailed = false; // ページ読み込み失敗フラグ
  String _currentUrl = '';   // 現在のURLを保持
  bool _isLoadingWebView = false; // WebView読み込み中フラグを追加

  // Default sites
  final String _noviStepsUrl = 'https://atcoder-novisteps.vercel.app/problems';
  final String _noviStepsTitle = 'NoviSteps';
  final String? _noviStepsFaviconUrl = 'https://raw.githubusercontent.com/AtCoder-NoviSteps/AtCoderNoviSteps/staging/static/favicon.png';
  final String? _noviStepsColorHex = '#48955D'; // Default color for NoviSteps

  final String _atcoderProblemsUrl = 'https://kenkoooo.com/atcoder/#/table/';
  final String _atcoderProblemsTitle = 'Problems';
  final String? _atcoderProblemsFaviconUrl = 'https://github.com/kenkoooo/AtCoderProblems/raw/refs/heads/master/atcoder-problems-frontend/public/favicon.ico';
  // AtCoder Problems doesn't have a readily available dominant color, so we'll leave it null for now or set a default
  final String? _atcoderProblemsColorHex = '#66C84D'; // Or a default like '#333333'

  // Map to cache PaletteGenerator futures to avoid redundant processing
  final Map<String, Future<PaletteGenerator?>> _paletteFutures = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final sitesJson = _prefs.getStringList('homeSites') ?? [];
    // Load site data, including potentially null faviconUrl and colorHex
    _sites = sitesJson.map((e) => Map<String, String?>.from(jsonDecode(e))).toList();

    // Check if default sites are already present (by URL)
    bool noviStepsExists = _sites.any((site) => site['url'] == _noviStepsUrl);
    bool atcoderProblemsExists = _sites.any((site) => site['url'] == _atcoderProblemsUrl);

    // Add default sites if they don't exist in saved preferences
    // Note: This adds them to the runtime list, but doesn't save them back immediately.
    // They will be saved if the user adds/removes/edits other sites.
    // Or, we could explicitly save here if needed.
    // if (!noviStepsExists) {
    //   _sites.insert(0, { // Insert NoviSteps at the beginning if needed
    //     'title': _noviStepsTitle,
    //     'url': _noviStepsUrl,
    //     'faviconUrl': _noviStepsFaviconUrl,
    //     'colorHex': _noviStepsColorHex,
    //   });
    // }
    // if (!atcoderProblemsExists) {
    //    // Insert AtCoder Problems after NoviSteps if needed
    //    int insertIndex = noviStepsExists ? 1 : 0; // Adjust index based on NoviSteps presence
    //   _sites.insert(insertIndex, {
    //     'title': _atcoderProblemsTitle,
    //     'url': _atcoderProblemsUrl,
    //     'faviconUrl': _atcoderProblemsFaviconUrl,
    //     'colorHex': _atcoderProblemsColorHex,
    //   });
    // }
    // Consider saving if defaults were added:
    // if (!noviStepsExists || !atcoderProblemsExists) {
    //    final list = _sites.map((e) => jsonEncode(e)).toList();
    //    await _prefs.setStringList('homeSites', list);
    // }


    // Initialize WebViewController - Start with NoviSteps by default
    _currentUrl = _noviStepsUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
         onPageStarted: (String url) { // 読み込み開始
           if (mounted) {
             setState(() { _isLoadingWebView = true; _loadFailed = false; }); // 開始時にインジケーター表示、エラーフラグリセット
           }
         },
         onPageFinished: (String url) { // 読み込み完了
           if (mounted) {
             setState(() { _isLoadingWebView = false; _loadFailed = false; });
           }
          },
          onWebResourceError: (WebResourceError error) { // 読み込みエラー
           if (mounted) {
             setState(() { _isLoadingWebView = false; _loadFailed = true; }); // エラー時もインジケーター非表示
           }
           developer.log('WebView load error: ${error.description}', name: 'HomeScreenWebView');
          },
         onNavigationRequest: (NavigationRequest request) {
           _currentUrl = request.url; // クリック時のURLを記憶
            final uri = Uri.parse(request.url);
            developer.log('Navigating to: ${request.url}', name: 'HomeScreenWebView');

            // 1. AtCoder問題ページかチェック
            if (uri.host == 'atcoder.jp' && uri.pathSegments.length == 4 &&
                uri.pathSegments[0] == 'contests' && uri.pathSegments[2] == 'tasks') {
              if (uri.pathSegments[3].contains('_')) { // Simple check for task ID format
                 widget.navigateToProblem(uri.pathSegments[3]);
                 if (mounted) {
                   setState(() { _isLoadingWebView = false; });
                 }
                 return NavigationDecision.prevent; // WebView内では遷移しない
              }
            }

            // 2. 許可されたサイトかチェック (NoviSteps, AtCoder Problems, ユーザー追加サイト)
            final requestBaseUrl = uri.origin; // e.g., https://example.com
            bool isAllowedSite = request.url.startsWith(_noviStepsUrl) ||
                               request.url.startsWith(_atcoderProblemsUrl) ||
                               _sites.any((site) => site['url'] != null && requestBaseUrl == Uri.parse(site['url']!).origin);

            if (isAllowedSite) {
               developer.log('Allowing navigation within allowed sites: ${request.url}', name: 'HomeScreenWebView');
              return NavigationDecision.navigate; // WebView内で遷移を許可
            }

            // 3. 許可されていないサイトの場合も WebView 内での遷移を許可する
            developer.log('Allowing navigation to non-allowed site: ${request.url}', name: 'HomeScreenWebView');
            // 以前はここで外部ブラウザ起動と prevent をしていたが、navigate に変更
            return NavigationDecision.navigate;

            /* --- 外部ブラウザで開く処理を削除 ---
            developer.log('Preventing navigation to external site: ${request.url}. Opening in external browser.', name: 'HomeScreenWebView');
            // Stop the loading indicator
            if (mounted) {
              setState(() { _isLoadingWebView = false; });
            }

            // Launch URL externally
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication); // 外部アプリで開く
            } else {
              developer.log('Could not launch $uri', name: 'HomeScreenWebView');
              // Optionally show a snackbar or message to the user
              if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${request.url} を開けませんでした。')),
                );
              }
            }
            return NavigationDecision.prevent; // WebView内での遷移は常に防ぐ
            */
          },
        ),
      )
      ..loadRequest(Uri.parse(_noviStepsUrl));
    _isControllerReady = true;
    if (mounted) {
      setState(() {});
    }
     // Optionally trigger background fetch for missing metadata for existing sites
     _updateMissingMetadata();
  }

  // Fetch metadata for sites that don't have it yet
  Future<void> _updateMissingMetadata() async {
    bool needsUpdate = false;
    for (int i = 0; i < _sites.length; i++) {
      if (_sites[i]['faviconUrl'] == null || _sites[i]['colorHex'] == null) {
        final url = _sites[i]['url'];
        if (url != null) {
          try {
            final metadata = await _fetchSiteMetadata(url);
            _sites[i]['faviconUrl'] = metadata['faviconUrl'];
            _sites[i]['colorHex'] = metadata['colorHex'];
            needsUpdate = true;
          } catch (e) {
            developer.log('Error fetching metadata for ${url}: $e', name: 'HomeScreenMetadata');
            // Keep existing null values or set defaults
             _sites[i]['faviconUrl'] ??= null; // Keep null if already null
             _sites[i]['colorHex'] ??= null;
          }
        }
      }
    }
    if (needsUpdate && mounted) {
      setState(() {});
      // Save updated metadata back to SharedPreferences
      final list = _sites.map((e) => jsonEncode(e)).toList();
      await _prefs.setStringList('homeSites', list);
    }
  }


  // Fetches favicon URL and dominant color
  Future<Map<String, String?>> _fetchSiteMetadata(String url) async {
    String? faviconUrl;
    String? colorHex;
    PaletteGenerator? paletteGenerator;

    try {
      // 1. Find Favicon URL
      final icons = await FaviconFinder.getAll(url);
      if (icons.isNotEmpty) {
        // Prioritize larger icons or specific types if needed
        faviconUrl = icons.first.url; // Take the first one for simplicity
        developer.log('Favicon found for $url: $faviconUrl', name: 'HomeScreenMetadata');

        // 2. Fetch Favicon Image and Generate Palette (if URL found)
        if (faviconUrl != null) {
           // Use cache key based on faviconUrl
           final cacheKey = faviconUrl;
           if (_paletteFutures.containsKey(cacheKey)) {
             paletteGenerator = await _paletteFutures[cacheKey];
           } else {
             final future = PaletteGenerator.fromImageProvider(
               NetworkImage(faviconUrl), // Use NetworkImage
               maximumColorCount: 20, // Adjust as needed
             ).catchError((e) {
               developer.log('Error generating palette for $faviconUrl: $e', name: 'HomeScreenMetadata');
               return null; // Return null on error
             });
             _paletteFutures[cacheKey] = future; // Store future in cache
             paletteGenerator = await future;
           }


          if (paletteGenerator != null && paletteGenerator.dominantColor != null) {
            colorHex = '#${paletteGenerator.dominantColor!.color.value.toRadixString(16).padLeft(8, '0')}'; // Format as #AARRGGBB
            developer.log('Dominant color found for $faviconUrl: $colorHex', name: 'HomeScreenMetadata');
          } else {
             developer.log('Could not generate palette or find dominant color for $faviconUrl', name: 'HomeScreenMetadata');
          }
        }
      } else {
         developer.log('No favicon found for $url', name: 'HomeScreenMetadata');
      }
    } catch (e) {
      developer.log('Error fetching metadata for $url: $e', name: 'HomeScreenMetadata');
      // Handle errors gracefully, return nulls
    }
    return {'faviconUrl': faviconUrl, 'colorHex': colorHex};
  }


  Future<void> _addSite() async {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String? urlErrorText;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
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
                  decoration: InputDecoration(
                    labelText: 'URL',
                    errorText: urlErrorText,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    if (urlErrorText != null) {
                      setStateDialog(() {
                        urlErrorText = null;
                      });
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              TextButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final url = urlController.text.trim();
                  bool isValid = true;

                  setStateDialog(() { urlErrorText = null; });

                  if (title.isEmpty || url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('タイトルとURLを入力してください。')),
                    );
                    isValid = false;
                  } else {
                    if (title == _noviStepsTitle && url == _noviStepsUrl) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('NoviStepsは既に追加されています。')),
                      );
                      isValid = false;
                    }

                    if (isValid) {
                      final uri = Uri.tryParse(url);
                      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                        setStateDialog(() {
                          urlErrorText = '有効なURLを入力してください (例: https://example.com)';
                        });
                        isValid = false;
                      }
                    }
                  }

                  if (isValid) {
                    // Show loading indicator while fetching metadata
                    showDialog(
                       context: context,
                       barrierDismissible: false,
                       builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                       final metadata = await _fetchSiteMetadata(url);
                       Navigator.pop(context); // Dismiss loading indicator

                       // Add site with metadata
                       _sites.add({
                         'title': title,
                         'url': url,
                         'faviconUrl': metadata['faviconUrl'],
                         'colorHex': metadata['colorHex'],
                       });
                       final list = _sites.map((e) => jsonEncode(e)).toList();
                       await _prefs.setStringList('homeSites', list);
                       if (mounted) {
                         setState(() {}); // Update main screen list
                       }
                       Navigator.pop(context); // Close add dialog
                    } catch (e) {
                       Navigator.pop(context); // Dismiss loading indicator
                       developer.log('Error adding site $url: $e', name: 'HomeScreenAddSite');
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('サイトメタデータの取得に失敗しました: $e')),
                       );
                       // Optionally add site without metadata or keep dialog open
                    }
                  }
                },
                child: const Text('追加'),
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _removeSite(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サイトを削除'),
        content: Text('\'${_sites[index]['title']}\' を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Remove associated palette future from cache if it exists
      final faviconUrl = _sites[index]['faviconUrl'];
      if (faviconUrl != null) {
         _paletteFutures.remove(faviconUrl);
      }

      _sites.removeAt(index);
      final list = _sites.map((e) => jsonEncode(e)).toList();
      await _prefs.setStringList('homeSites', list);
      if (mounted) {
        setState(() {});
      }
    }
  }

  // Edit existing site: long press invokes this
  Future<void> _editSite(int index) async {
    final site = _sites[index];
    final titleController = TextEditingController(text: site['title']);
    final urlController = TextEditingController(text: site['url']);
    String? urlErrorText;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('サイトを編集'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                ),
                TextField(
                  controller: urlController,
                  decoration: InputDecoration(
                    labelText: 'URL',
                    errorText: urlErrorText,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) {
                    if (urlErrorText != null) setStateDialog(() => urlErrorText = null);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Delete option
                  Navigator.pop(context);
                  await _removeSite(index);
                },
                child: const Text('削除', style: TextStyle(color: Colors.red)),
              ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('キャンセル')),
              TextButton(
                onPressed: () async {
                  final newTitle = titleController.text.trim();
                  final newUrl = urlController.text.trim();
                  if (newTitle.isEmpty || newUrl.isEmpty) {
                    setStateDialog(() {
                      urlErrorText = 'タイトルとURLを入力してください。';
                    });
                    return;
                  }
                  final uri = Uri.tryParse(newUrl);
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    setStateDialog(() => urlErrorText = '有効なURLを入力してください。');
                    return;
                  }
                  final oldUrl = site['url'];
                  // Update data
                  site['title'] = newTitle;
                  if (newUrl != oldUrl) {
                    site['url'] = newUrl;
                    site['faviconUrl'] = null;
                    site['colorHex'] = null;
                  }
                  final list = _sites.map((e) => jsonEncode(e)).toList();
                  await _prefs.setStringList('homeSites', list);
                  if (mounted) setState(() {});
                  if (newUrl != oldUrl) _updateMissingMetadata();
                  Navigator.pop(context);
                },
                child: const Text('更新'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper widget to build individual site buttons
  Widget _buildSiteButton({
    required String title,
    required String url,
    String? faviconUrl,
    String? colorHex,
    VoidCallback? onLongPress,
  }) {
    Color? backgroundColor;
    Color textColor = Theme.of(context).colorScheme.onSurfaceVariant; // Default text color for buttons

    if (colorHex != null) {
      try {
        // Handle potential alpha channel in hex color
        String hex = colorHex.replaceFirst('#', '');
        if (hex.length == 6) hex = 'FF$hex'; // Add full opacity if missing
        if (hex.length == 8) {
           backgroundColor = Color(int.parse('0x$hex'));
           textColor = _getTextColorForBackground(backgroundColor);
        } else {
           throw FormatException("Invalid hex color format");
        }
      } catch (e) {
        developer.log('Error parsing color hex $colorHex: $e', name: 'HomeScreenButton');
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest; // Use a theme color on error
        textColor = Theme.of(context).colorScheme.onSurfaceVariant;
      }
    } else {
       // Use default theme colors if no colorHex provided
       backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
       textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ElevatedButton(
        onPressed: () {
           // Only load if the URL is different from the current one
           if (_currentUrl != url) {
             _currentUrl = url; // Update current URL immediately
             // ボタン押下時にもインジケーターを表示開始
             if (mounted) {
               setState(() { _isLoadingWebView = true; _loadFailed = false; });
             }
             _controller.loadRequest(Uri.parse(url));
           } else {
             developer.log('Button pressed for already loaded URL: $url', name: 'HomeScreenButton');
             // 同じURLでもリロードしたい場合は以下を実行
             // if (mounted) {
             //   setState(() { _isLoadingWebView = true; _loadFailed = false; });
             // }
             // _controller.reload();
           }
        },
        onLongPress: onLongPress,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor, // Apply fetched or default color
          foregroundColor: textColor, // Apply calculated or default text color
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // Softer corners
          elevation: 1, // Subtle elevation
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faviconUrl != null)
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Add a border based on the text color for contrast
                  border: Border.all(color: textColor.withOpacity(0.5), width: 1.0),
                ),
                child: ClipOval(
                  child: Image.network(
                    faviconUrl,
                    width: 20,
                    height: 20,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(Icons.public, size: 18, color: textColor.withOpacity(0.8)),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                         width: 18, height: 18, // Slightly smaller for progress indicator
                         child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                         )
                      );
                    },
                  ),
                ),
              )
            else
              Icon(Icons.public, size: 18, color: textColor.withOpacity(0.8)), // Default icon
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: textColor)),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 60, // Adjust height if needed for icons
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            scrollDirection: Axis.horizontal,
            children: [
              // NoviSteps Button (using helper)
              _buildSiteButton(
                title: _noviStepsTitle,
                url: _noviStepsUrl,
                faviconUrl: _noviStepsFaviconUrl,
                colorHex: _noviStepsColorHex,
                // No long press for default NoviSteps
              ),
              // AtCoder Problems Button (using helper)
              _buildSiteButton(
                title: _atcoderProblemsTitle,
                url: _atcoderProblemsUrl,
                faviconUrl: _atcoderProblemsFaviconUrl,
                colorHex: _atcoderProblemsColorHex,
                 // No long press for default AtCoder Problems
              ),
              // User-added sites (using helper)
              ..._sites.asMap().entries.map((entry) {
                 int index = entry.key;
                 Map<String, String?> site = entry.value;
                 // Only show user-added sites here (filter out defaults if they were loaded from prefs)
                 if (site['url'] != _noviStepsUrl && site['url'] != _atcoderProblemsUrl && site['title'] != null && site['url'] != null) {
                    return _buildSiteButton(
                      title: site['title']!,
                      url: site['url']!,
                      faviconUrl: site['faviconUrl'],
                      colorHex: site['colorHex'],
                      onLongPress: () => _editSite(index), // Allow editing/deleting user sites
                    );
                 } else {
                    return const SizedBox.shrink(); // Hide default sites if they were in _sites
                 }
              }),
              // Add site button (remains the same)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ElevatedButton(
                  onPressed: _addSite,
                  style: ElevatedButton.styleFrom( // Consistent styling
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack( // WebViewとインジケーターを重ねるためにStackを使用
            children: [
              if (_isControllerReady)
                // WebView自体は常にStackの最背面に配置
                WebViewWidget(controller: _controller)
              else // WebView準備中のインジケーター
                const Center(child: CircularProgressIndicator()),

              // 読み込み失敗時の表示 (WebViewの上に表示)
              if (_isControllerReady && _loadFailed)
                Center(
                  child: Container( // 背景を追加して見やすくする (任意)
                     padding: const EdgeInsets.all(20),
                     // Use surface container high for better contrast on various themes
                     color: Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.9),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       mainAxisSize: MainAxisSize.min, // Columnが必要な高さだけ取るように
                       children: [
                         Text('ページを読み込めませんでした', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                         const SizedBox(height: 16),
                         ElevatedButton(
                           onPressed: () {
                             // 再試行時にもインジケーター表示
                             if (mounted) {
                               setState(() { _isLoadingWebView = true; _loadFailed = false; });
                             }
                             _controller.loadRequest(Uri.parse(_currentUrl));
                           },
                           child: const Text('再試行'),
                         ),
                       ],
                     ),
                  ),
                ),

              // WebView読み込み中のインジケーター (準備完了後、かつ失敗していない場合、WebViewの上に表示)
              if (_isControllerReady && _isLoadingWebView && !_loadFailed)
                // Add a semi-transparent background scrim to make the indicator more visible
                Container(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
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