// filepath: d:\GitHub_tsukuba-denden\shojin_app\lib\screens\browser_screen.dart
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:favicon/favicon.dart';
import 'package:palette_generator/palette_generator.dart';
// For fetching favicon image

// Helper function to determine text color based on background
Color _getTextColorForBackground(Color backgroundColor) {
  return ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark
      ? Colors.white
      : Colors.black;
}

class BrowserScreen extends StatefulWidget {
  final Function(String) navigateToProblem;

  const BrowserScreen({super.key, required this.navigateToProblem});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late WebViewController _controller;
  late SharedPreferences _prefs;
  List<Map<String, String?>> _sites = [];
  bool _isControllerReady = false;
  bool _loadFailed = false;
  String _currentUrl = '';
  bool _isLoadingWebView = false;

  // Default sites
  final String _noviStepsUrl = 'https://atcoder-novisteps.vercel.app/problems';
  final String _noviStepsTitle = 'NoviSteps';
  final String _noviStepsFaviconUrl = 'https://raw.githubusercontent.com/AtCoder-NoviSteps/AtCoderNoviSteps/staging/static/favicon.png';
  final String _noviStepsColorHex = '#48955D';

  final String _atcoderProblemsUrl = 'https://kenkoooo.com/atcoder/#/table/';
  final String _atcoderProblemsTitle = 'Problems';
  final String _atcoderProblemsFaviconUrl = 'https://github.com/kenkoooo/AtCoderProblems/raw/refs/heads/master/atcoder-problems-frontend/public/favicon.ico';
  final String _atcoderProblemsColorHex = '#66C84D';

  final Map<String, Future<PaletteGenerator?>> _paletteFutures = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final sitesJson = _prefs.getStringList('homeSites') ?? [];
    _sites = sitesJson.map((e) => Map<String, String?>.from(jsonDecode(e))).toList();

    // Initialize WebViewController
    _currentUrl = _noviStepsUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() { _isLoadingWebView = true; _loadFailed = false; });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() { _isLoadingWebView = false; _loadFailed = false; });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() { _isLoadingWebView = false; _loadFailed = true; });
            }
            developer.log('WebView load error: ${error.description}', name: 'BrowserScreenWebView');
          },
          onNavigationRequest: (NavigationRequest request) {
            _currentUrl = request.url;
            final uri = Uri.parse(request.url);
            developer.log('Navigating to: ${request.url}', name: 'BrowserScreenWebView');

            // 1. AtCoder problem page check
            if (uri.host == 'atcoder.jp' && uri.pathSegments.length == 4 &&
                uri.pathSegments[0] == 'contests' && uri.pathSegments[2] == 'tasks') {
              if (uri.pathSegments[3].contains('_')) {
                widget.navigateToProblem(uri.pathSegments[3]);
                if (mounted) {
                  setState(() { _isLoadingWebView = false; });
                }
                return NavigationDecision.prevent;
              }
            }

            // 2. Allowed site check (NoviSteps, AtCoder Problems, user-added)
            final requestBaseUrl = uri.origin;
            bool isAllowedSite = request.url.startsWith(_noviStepsUrl) ||
                               request.url.startsWith(_atcoderProblemsUrl) ||
                               _sites.any((site) => site['url'] != null && requestBaseUrl == Uri.parse(site['url']!).origin);

            if (isAllowedSite) {
              developer.log('Allowing navigation within allowed sites: ${request.url}', name: 'BrowserScreenWebView');
              return NavigationDecision.navigate;
            }

            // 3. Allow navigation to non-allowed sites within WebView
            developer.log('Allowing navigation to non-allowed site: ${request.url}', name: 'BrowserScreenWebView');
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_noviStepsUrl));
    _isControllerReady = true;
    if (mounted) {
      setState(() {});
    }
    _updateMissingMetadata();
  }

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
            developer.log('Error fetching metadata for $url: $e', name: 'BrowserScreenMetadata');
          }
        }
      }
    }
    if (needsUpdate && mounted) {
      setState(() {});
      final list = _sites.map((e) => jsonEncode(e)).toList();
      await _prefs.setStringList('homeSites', list);
    }
  }

  Future<Map<String, String?>> _fetchSiteMetadata(String url) async {
    String? faviconUrl;
    String? colorHex;
    PaletteGenerator? paletteGenerator;

    try {
      final icons = await FaviconFinder.getAll(url);
      if (icons.isNotEmpty) {
        faviconUrl = icons.first.url;
        developer.log('Favicon found for $url: $faviconUrl', name: 'BrowserScreenMetadata');

        final cacheKey = faviconUrl;
        if (_paletteFutures.containsKey(cacheKey)) {
          paletteGenerator = await _paletteFutures[cacheKey];
        } else {
          final future = PaletteGenerator.fromImageProvider(
            NetworkImage(faviconUrl),
            maximumColorCount: 20,
          ).catchError((e) {
            developer.log('Error generating palette for $faviconUrl: $e', name: 'BrowserScreenMetadata');
            return null;
          });
          _paletteFutures[cacheKey] = future;
          paletteGenerator = await future;
        }

        if (paletteGenerator != null && paletteGenerator.dominantColor != null) {
          colorHex = '#${paletteGenerator.dominantColor!.color.value.toRadixString(16).padLeft(8, '0')}';
          developer.log('Dominant color found for $faviconUrl: $colorHex', name: 'BrowserScreenMetadata');
        } else {
           developer.log('Could not generate palette or find dominant color for $faviconUrl', name: 'BrowserScreenMetadata');
        }
            } else {
         developer.log('No favicon found for $url', name: 'BrowserScreenMetadata');
      }
    } catch (e) {
      developer.log('Error fetching metadata for $url: $e', name: 'BrowserScreenMetadata');
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
                      setStateDialog(() { urlErrorText = null; });
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
                     if (isValid && title == _atcoderProblemsTitle && url == _atcoderProblemsUrl) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('AtCoder Problemsは既に追加されています。')),
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
                    showDialog(
                       context: context,
                       barrierDismissible: false,
                       builder: (context) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                       final metadata = await _fetchSiteMetadata(url);
                       Navigator.pop(context); // Dismiss loading

                       _sites.add({
                         'title': title,
                         'url': url,
                         'faviconUrl': metadata['faviconUrl'],
                         'colorHex': metadata['colorHex'],
                       });
                       final list = _sites.map((e) => jsonEncode(e)).toList();
                       await _prefs.setStringList('homeSites', list);
                       if (mounted) {
                         setState(() {});
                       }
                       Navigator.pop(context); // Close add dialog
                    } catch (e) {
                       Navigator.pop(context); // Dismiss loading
                       developer.log('Error adding site $url: $e', name: 'BrowserScreenAddSite');
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('サイトメタデータの取得に失敗しました: $e')),
                       );
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );

    if (confirm == true) {
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
                    setStateDialog(() { urlErrorText = 'タイトルとURLを入力してください。'; });
                    return;
                  }
                  final uri = Uri.tryParse(newUrl);
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    setStateDialog(() => urlErrorText = '有効なURLを入力してください。');
                    return;
                  }
                  final oldUrl = site['url'];
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

  Widget _buildSiteButton({
    required String title,
    required String url,
    String? faviconUrl,
    String? colorHex,
    VoidCallback? onLongPress,
  }) {
    Color? backgroundColor;
    Color textColor = Theme.of(context).colorScheme.onSurfaceVariant;

    if (colorHex != null) {
      try {
        String hex = colorHex.replaceFirst('#', '');
        if (hex.length == 6) hex = 'FF$hex';
        if (hex.length == 8) {
           backgroundColor = Color(int.parse('0x$hex'));
           textColor = _getTextColorForBackground(backgroundColor);
        } else {
           throw const FormatException("Invalid hex color format");
        }
      } catch (e) {
        developer.log('Error parsing color hex $colorHex: $e', name: 'BrowserScreenButton');
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurfaceVariant;
      }
    } else {
       backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
       textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ElevatedButton(
        onPressed: () {
           if (_currentUrl != url) {
             _currentUrl = url;
             if (mounted) {
               setState(() { _isLoadingWebView = true; _loadFailed = false; });
             }
             _controller.loadRequest(Uri.parse(url));
           } else {
             developer.log('Button pressed for already loaded URL: $url', name: 'BrowserScreenButton');
             // Optionally reload:
             // if (mounted) { setState(() { _isLoadingWebView = true; _loadFailed = false; }); }
             // _controller.reload();
           }
        },
        onLongPress: onLongPress,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
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
                         width: 18, height: 18,
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
              Icon(Icons.public, size: 18, color: textColor.withOpacity(0.8)),
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
          height: 60,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            scrollDirection: Axis.horizontal,
            children: [
              _buildSiteButton(
                title: _noviStepsTitle,
                url: _noviStepsUrl,
                faviconUrl: _noviStepsFaviconUrl,
                colorHex: _noviStepsColorHex,
              ),
              _buildSiteButton(
                title: _atcoderProblemsTitle,
                url: _atcoderProblemsUrl,
                faviconUrl: _atcoderProblemsFaviconUrl,
                colorHex: _atcoderProblemsColorHex,
              ),
              ..._sites.asMap().entries.map((entry) {
                 int index = entry.key;
                 Map<String, String?> site = entry.value;
                 if (site['url'] != _noviStepsUrl && site['url'] != _atcoderProblemsUrl && site['title'] != null && site['url'] != null) {
                    return _buildSiteButton(
                      title: site['title']!,
                      url: site['url']!,
                      faviconUrl: site['faviconUrl'],
                      colorHex: site['colorHex'],
                      onLongPress: () => _editSite(index),
                    );
                 } else {
                    return const SizedBox.shrink();
                 }
              }),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ElevatedButton(
                  onPressed: _addSite,
                  style: ElevatedButton.styleFrom(
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
          child: Stack(
            children: [
              if (_isControllerReady)
                WebViewWidget(controller: _controller)
              else
                const Center(child: CircularProgressIndicator()),

              if (_isControllerReady && _loadFailed)
                Center(
                  child: Container(
                     padding: const EdgeInsets.all(20),
                     color: Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.9),
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text('ページを読み込めませんでした', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                         const SizedBox(height: 16),
                         ElevatedButton(
                           onPressed: () {
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

              if (_isControllerReady && _isLoadingWebView && !_loadFailed)
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