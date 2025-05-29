import 'dart:io'; // For Platform
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:url_launcher/url_launcher.dart'; // For launching URLs
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import '../providers/theme_provider.dart';
import '../providers/template_provider.dart';
import 'template_edit_screen.dart';
import '../services/update_service.dart'; // Import UpdateService
import '../services/update_manager.dart'; // Import UpdateManager

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = "読み込み中...";
  bool _isLoadingUpdate = false;
  String _updateCheckResult = "";
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  AppUpdateInfo? _availableUpdateInfo;
  final UpdateService _updateService = UpdateService();
  final UpdateManager _updateManager = UpdateManager();
  bool _autoUpdateCheckEnabled = true; // Added state variable

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadAutoUpdatePreference(); // Load preference
  }

  Future<void> _loadCurrentVersion() async {
    try {
      String version = await _updateService.getCurrentAppVersion();
      if (mounted) {
        setState(() {
          _currentVersion = version;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentVersion = "取得エラー";
        });
      }
      print('Failed to load current version: $e');
    }
  }

  // Method to load auto update preference
  Future<void> _loadAutoUpdatePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _autoUpdateCheckEnabled = prefs.getBool('autoUpdateCheckEnabled') ?? true;
      });
    }
  }

  // Method to save auto update preference
  Future<void> _setAutoUpdatePreference(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoUpdateCheckEnabled', value);
    if (mounted) {
      setState(() {
        _autoUpdateCheckEnabled = value;
      });
    }
  }


  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUpdate = true;
      _updateCheckResult = "";
      _availableUpdateInfo = null;
      _isDownloading = false; // Reset download state
      _downloadProgress = 0.0; // Reset progress
    });

    try {
      AppUpdateInfo? releaseInfo = await _updateService.getLatestReleaseInfo("tsukuba-denden", "Shojin_App");
      if (!mounted) return;

      if (releaseInfo != null) {
        bool updateAvailable = _updateService.isUpdateAvailable(_currentVersion, releaseInfo.version);
        if (updateAvailable) {
          setState(() {
            _availableUpdateInfo = releaseInfo;
            _updateCheckResult = "新しいバージョンがあります: ${releaseInfo.version}";
          });
          _showUpdateDialog(releaseInfo);
        } else {
          setState(() {
            _updateCheckResult = "お使いのバージョンは最新です。";
          });
        }
      } else {
        setState(() {
          _updateCheckResult = "更新情報の取得に失敗しました。";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _updateCheckResult = "更新チェック中にエラーが発生しました: $e";
        });
      }
      print('Error checking for updates: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUpdate = false;
        });
      }
    }
  }

  void _showUpdateDialog(AppUpdateInfo releaseInfo) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Ensure version string is not null and handle 'v' prefix for URL
        String versionTag = releaseInfo.version;
        if (!versionTag.startsWith('v')) {
          versionTag = 'v$versionTag';
        }
        final String releaseUrl = "https://github.com/tsukuba-denden/Shojin_App/releases/tag/$versionTag";

        return AlertDialog(
          title: const Text("アップデート利用可能"),
          content: SingleChildScrollView(
            child: ListBody( // Use ListBody for better structure
              children: <Widget>[
                Text("バージョン: ${releaseInfo.version}"),
                const SizedBox(height: 10),
                Text(releaseInfo.releaseNotes ?? 'リリースノートはありません。'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("後で"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("GitHubで表示"),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  if (await canLaunchUrl(Uri.parse(releaseUrl))) {
                    await launchUrl(Uri.parse(releaseUrl), mode: LaunchMode.externalApplication);
                  } else {
                    throw 'Could not launch $releaseUrl';
                  }
                } catch (e) {
                   if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('URLを開けませんでした: $e')));
                }
              },
            ),
            if (releaseInfo.downloadUrl != null) // Only show if download URL is available
              ElevatedButton(
                child: const Text("ダウンロードとインストール"),
                onPressed: () {
                  Navigator.of(context).pop();
                  _downloadAndApplyUpdate(releaseInfo);
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _downloadAndApplyUpdate(AppUpdateInfo releaseInfo) async {
    if (!mounted) return;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _updateCheckResult = ""; // Clear previous results
    });

    if (Platform.isAndroid) {
      bool permissionGranted = await _updateService.requestStoragePermission();
      if (!mounted) return;
      if (!permissionGranted) {
        setState(() {
          _updateCheckResult = "ストレージ権限が必要です。";
          _isDownloading = false;
        });
        return;
      }
    }

    try {
      String? filePath = await _updateService.downloadUpdate(releaseInfo, (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      });
      if (!mounted) return;

      if (filePath != null) {
        setState(() {
          _updateCheckResult = "ダウンロード完了: $filePath";
        });
        await _updateManager.applyUpdate(filePath, releaseInfo.assetName);
        // Potentially add more user feedback after applyUpdate if needed
        if (mounted) { // Check mounted again before showing SnackBar
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('インストールを開始します... アプリの指示に従ってください。')),
           );
        }
      } else {
        setState(() {
          _updateCheckResult = "ダウンロードに失敗しました。";
        });
      }
    } catch (e) {
        if (mounted) {
            setState(() {
                _updateCheckResult = "アップデート処理中にエラー: $e";
            });
        }
        print('Error during download/apply: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '設定',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // テーマ設定のアコーディオン
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // 区切り線を透明に
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  title: Text(
                    'テーマ設定',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  leading: const Icon(Icons.palette),
                  childrenPadding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  children: [
                    ...ThemeModeOption.values.map((mode) => RadioListTile<ThemeModeOption>(
                      title: Text(mode.label),
                      value: mode,
                      groupValue: themeProvider.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          themeProvider.setThemeMode(value);
                        }
                      },
                      secondary: _getThemeIcon(mode),
                    )),
                    // Material Youの有効/無効スイッチ
                    SwitchListTile(
                      title: const Text('Material You (ダイナミックカラー)'),
                      subtitle: const Text('壁紙の色に基づいてテーマを生成'),
                      value: themeProvider.useMaterialYou,
                      onChanged: (value) {
                        themeProvider.setUseMaterialYou(value);
                      },
                      secondary: const Icon(Icons.color_lens_outlined),
                    ),
                    const Divider(), // Add a divider
                    // ナビゲーションバーの透明度設定
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0), // Add padding
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ナビゲーションバーの透明度', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary)),
                          Slider(
                            min: 0.0,
                            max: 1.0,
                            divisions: 20,
                            label: themeProvider.navBarOpacity.toStringAsFixed(2),
                            value: themeProvider.navBarOpacity,
                            onChanged: (value) {
                              HapticFeedback.lightImpact(); // Haptic feedback
                              themeProvider.setNavBarOpacity(value);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // テンプレート設定のアコーディオン
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // 区切り線を透明に
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  title: Text(
                    'テンプレート設定',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  leading: const Icon(Icons.code),
                  childrenPadding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  children: [
                    _buildTemplateList(context),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 更新設定のアコーディオン
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  initiallyExpanded: true,
                  title: Text(
                    '更新設定',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  leading: const Icon(Icons.system_update_alt),
                  childrenPadding: const EdgeInsets.only(bottom: 8, left: 16, right: 16), // Adjusted padding
                  children: [
                    Column( // Wrap in Column for multiple children
                      children: [
                        SwitchListTile(
                          title: const Text('アプリ起動時に自動で更新を確認'),
                          value: _autoUpdateCheckEnabled,
                          onChanged: (bool value) {
                            _setAutoUpdatePreference(value);
                          },
                          secondary: const Icon(Icons.sync_outlined),
                        ),
                        const SizedBox(height: 16), // Spacing
                        // Moved UI Elements for manual update check
                        ElevatedButton(
                          onPressed: (_isLoadingUpdate || _isDownloading) ? null : _checkForUpdates,
                          child: const Text('アップデートを手動で確認'), // Changed text for clarity
                        ),
                        if (_isLoadingUpdate)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: CircularProgressIndicator(),
                          ),
                        if (_isDownloading)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Column(
                              children: [
                                LinearProgressIndicator(value: _downloadProgress < 0 ? null : _downloadProgress),
                                const SizedBox(height: 4),
                                Text('ダウンロード中: ${(_downloadProgress * 100).toStringAsFixed(0)}%'),
                              ],
                            ),
                          ),
                        if (_updateCheckResult.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(_updateCheckResult, textAlign: TextAlign.center),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),


            // アプリについてのアコーディオン
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent, // 区切り線を透明に
                ),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  title: Text(
                    'アプリについて',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  leading: const Icon(Icons.info_outline),
                  childrenPadding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  children: [
                    ListTile(
                      title: const Text('バージョン'),
                      subtitle: Text(_currentVersion),
                      leading: const Icon(Icons.tag),
                    ),
                    // Manual update check UI was here, now moved
                    ListTile(
                      title: const Text('開発者'),
                      subtitle: const Text('筑波大学附属中学校 電子電脳技術研究会'),
                      leading: const Icon(Icons.code),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // 言語テンプレート一覧を構築
  Widget _buildTemplateList(BuildContext context) {
    final templateProvider = Provider.of<TemplateProvider>(context);

    return Column(
      children: templateProvider.supportedLanguages.map((language) {
        return ListTile(
          title: Text(language),
          trailing: const Icon(Icons.edit),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TemplateEditScreen(language: language),
              ),
            );
          },
        );
      }).toList(),
    );
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
}
