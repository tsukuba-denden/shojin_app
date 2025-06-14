// filepath: d:\GitHub_tsukuba-denden\shojin_app\lib\screens\browser_screen.dart
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../constants/browser_constants.dart';
import '../models/browser_site.dart';
import '../providers/theme_provider.dart';
import '../services/browser_site_service.dart';

class BrowserScreen extends StatefulWidget {
  final Function(String) navigateToProblem;

  const BrowserScreen({super.key, required this.navigateToProblem});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late WebViewController _controller;
  List<BrowserSite> _sites = [];
  bool _isControllerReady = false;
  bool _loadFailed = false;
  String _currentUrl = '';
  bool _isLoadingWebView = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _sites = await BrowserSiteService.loadSites();

    // Initialize WebViewController
    _currentUrl = BrowserConstants.defaultSites.first.url;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() { 
                _isLoadingWebView = true; 
                _loadFailed = false; 
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() { 
                _isLoadingWebView = false; 
                _loadFailed = false; 
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) {
              setState(() { 
                _isLoadingWebView = false; 
                _loadFailed = true; 
              });
            }
            developer.log('WebView load error: ${error.description}', name: 'BrowserScreenWebView');
          },
          onNavigationRequest: (NavigationRequest request) {
            return _handleNavigationRequest(request);
          },
        ),
      )
      ..loadRequest(Uri.parse(BrowserConstants.defaultSites.first.url));
    
    _isControllerReady = true;
    if (mounted) {
      setState(() {});
    }
    
    // Update missing metadata for user-added sites
    _updateMissingMetadata();
  }

  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    _currentUrl = request.url;
    final uri = Uri.parse(request.url);
    developer.log('Navigating to: ${request.url}', name: 'BrowserScreenWebView');

    // 1. AtCoder problem page check
    if (uri.host == BrowserConstants.atcoderHost && 
        uri.pathSegments.length == BrowserConstants.atcoderProblemPathLength &&
        uri.pathSegments[BrowserConstants.atcoderContestIndex] == BrowserConstants.atcoderProblemPathSegments[0] && 
        uri.pathSegments[BrowserConstants.atcoderTasksIndex] == BrowserConstants.atcoderProblemPathSegments[1]) {
      if (uri.pathSegments[BrowserConstants.atcoderProblemIndex].contains('_')) {
        widget.navigateToProblem(uri.pathSegments[BrowserConstants.atcoderProblemIndex]);
        if (mounted) {
          setState(() { _isLoadingWebView = false; });
        }
        return NavigationDecision.prevent;
      }
    }

    // 2. Allowed site check (default sites + user-added)
    final requestBaseUrl = uri.origin;
    bool isAllowedSite = _isAllowedSite(requestBaseUrl, request.url);

    if (isAllowedSite) {
      developer.log('Allowing navigation within allowed sites: ${request.url}', name: 'BrowserScreenWebView');
      return NavigationDecision.navigate;
    }

    // 3. Allow navigation to non-allowed sites within WebView
    developer.log('Allowing navigation to non-allowed site: ${request.url}', name: 'BrowserScreenWebView');
    return NavigationDecision.navigate;
  }

  bool _isAllowedSite(String requestBaseUrl, String fullUrl) {
    // Check default sites
    for (final defaultSite in BrowserConstants.defaultSites) {
      if (fullUrl.startsWith(defaultSite.url)) return true;
    }

    // Check user-added sites
    for (final site in _sites) {
      if (site.baseUrl == requestBaseUrl) return true;
    }

    return false;
  }  Future<void> _updateMissingMetadata() async {
    bool needsUpdate = false;
    for (int i = 0; i < _sites.length; i++) {
      if (_sites[i].faviconUrl == null || _sites[i].colorHex == null) {
        try {
          final metadata = await BrowserSiteService.fetchSiteMetadata(_sites[i].url);
          _sites[i] = _sites[i].copyWith(
            faviconUrl: metadata.faviconUrl,
            colorHex: metadata.colorHex,
          );
          needsUpdate = true;
        } catch (e) {
          developer.log('Error fetching metadata for ${_sites[i].url}: $e', name: 'BrowserScreenMetadata');
        }
      }
    }
    if (needsUpdate) {
      await BrowserSiteService.saveSites(_sites);
      if (mounted) {
        setState(() {});
      }
    }
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
                    isValid = false;                  } else {
                    // Check if site already exists
                    final existingDefault = BrowserConstants.defaultSites.any(
                      (defaultSite) => defaultSite.title == title && defaultSite.url == url
                    );
                    if (existingDefault) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$titleは既に追加されています。')),
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
                    );                    try {
                       final newSite = BrowserSite(title: title, url: url);
                       final metadata = await BrowserSiteService.fetchSiteMetadata(url);
                       final siteWithMetadata = newSite.copyWithMetadata(
                         faviconUrl: metadata.faviconUrl,
                         colorHex: metadata.colorHex,
                       );
                       Navigator.pop(context); // Dismiss loading

                       _sites.add(siteWithMetadata);
                       await BrowserSiteService.saveSites(_sites);
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
        content: Text('\'${_sites[index].title}\' を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('キャンセル')
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('削除')
          ),
        ],
      ),
    );

    if (confirm == true) {
      _sites.removeAt(index);
      await BrowserSiteService.saveSites(_sites);
      if (mounted) {
        setState(() {});
      }
    }
  }
  Future<void> _editSite(int index) async {
    final site = _sites[index];
    final titleController = TextEditingController(text: site.title);
    final urlController = TextEditingController(text: site.url);
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
                    if (urlErrorText != null) {
                      setStateDialog(() => urlErrorText = null);
                    }
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
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('キャンセル')
              ),
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
                  
                  final oldUrl = site.url;
                  final updatedSite = site.copyWith(
                    title: newTitle,
                    url: newUrl,
                    // Clear metadata if URL changed
                    faviconUrl: newUrl != oldUrl ? null : site.faviconUrl,
                    colorHex: newUrl != oldUrl ? null : site.colorHex,
                  );
                  
                  _sites[index] = updatedSite;
                  await BrowserSiteService.saveSites(_sites);
                  
                  if (mounted) setState(() {});
                  
                  if (newUrl != oldUrl) {
                    _updateMissingMetadata();
                  }
                  
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

  Color _getTextColorForBackground(Color backgroundColor) {
    // Calculate luminance to determine if we should use light or dark text
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black87 : Colors.white;
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
        }      } catch (e) {
        developer.log('Error parsing color hex $colorHex: $e', name: 'BrowserScreenButton');
        backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        textColor = Theme.of(context).colorScheme.onSurfaceVariant;
      }
    } else {
       // デフォルトの背景色とテキスト色を設定
       backgroundColor = Theme.of(context).colorScheme.surfaceContainerHighest;
       textColor = Theme.of(context).colorScheme.onSurfaceVariant;
       
       // MaterialYou使用時はプライマリカラーで軽いティントを追加してコントラストを向上
       final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
       if (themeProvider.useMaterialYou) {
         backgroundColor = backgroundColor.withOpacity(0.9);
       }
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
            scrollDirection: Axis.horizontal,            children: [
              // Default sites
              ...BrowserConstants.defaultSites.map((defaultSite) => 
                _buildSiteButton(
                  title: defaultSite.title,
                  url: defaultSite.url,
                  faviconUrl: defaultSite.faviconUrl,
                  colorHex: defaultSite.colorHex,
                )
              ),
              // User-added sites
              ..._sites.asMap().entries.map((entry) {
                 int index = entry.key;
                 BrowserSite site = entry.value;
                 return _buildSiteButton(
                   title: site.title,
                   url: site.url,
                   faviconUrl: site.faviconUrl,
                   colorHex: site.colorHex,
                   onLongPress: () => _editSite(index),
                 );
              }),
              // Add site button
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