import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import '../providers/theme_provider.dart';
import '../providers/template_provider.dart';
import 'template_edit_screen.dart';
import '../services/enhanced_update_service.dart'; // Use enhanced service
import '../services/auto_update_manager.dart'; // Import auto update manager
import '../services/about_info.dart'; // Import AboutInfo

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentVersion = "読み込み中...";
  bool _isLoadingUpdate = false;
  String _updateCheckResult = "";
  final EnhancedUpdateService _updateService = EnhancedUpdateService();
  final AutoUpdateManager _autoUpdateManager = AutoUpdateManager();
  bool _autoUpdateCheckEnabled = true;
  Map<String, dynamic>? _aboutInfo;

  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadAutoUpdatePreference(); // Load preference
    _loadAboutInfo(); // Load about info
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
    bool enabled = await _autoUpdateManager.isAutoUpdateEnabled();
    if (mounted) {
      setState(() {
        _autoUpdateCheckEnabled = enabled;
      });
    }
  }

  // Method to save auto update preference
  Future<void> _setAutoUpdatePreference(bool value) async {
    await _autoUpdateManager.setAutoUpdateEnabled(value);
    if (mounted) {
      setState(() {
        _autoUpdateCheckEnabled = value;
      });
    }
  }

  Future<void> _loadAboutInfo() async {
    try {
      final info = await AboutInfo.getInfo();
      if (mounted) {
        setState(() {
          _aboutInfo = info;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aboutInfo = {'error': 'アプリ情報の取得に失敗しました'};
        });
      }
    }
  }
  Future<void> _checkForUpdates() async {
    if (!mounted) return;
    setState(() {
      _isLoadingUpdate = true;
      _updateCheckResult = "";
    });

    try {
      EnhancedAppUpdateInfo? releaseInfo = await _autoUpdateManager.checkForUpdatesManually();
      if (!mounted) return;

      if (releaseInfo != null) {
        setState(() {
          _updateCheckResult = "新しいバージョンがあります: ${releaseInfo.version}";
        });
        _showUpdateDialog(releaseInfo);
      } else {
        setState(() {
          _updateCheckResult = "お使いのバージョンは最新です。";
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
  }  void _showUpdateDialog(EnhancedAppUpdateInfo releaseInfo) {
    if (!mounted) return;
    _autoUpdateManager.showManualUpdateDialog(context, releaseInfo);
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
                        ),                        const SizedBox(height: 16), // Spacing
                        // Moved UI Elements for manual update check
                        ElevatedButton(
                          onPressed: _isLoadingUpdate ? null : _checkForUpdates,
                          child: const Text('アップデートを手動で確認'), // Changed text for clarity
                        ),
                        if (_isLoadingUpdate)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: CircularProgressIndicator(),
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
                  childrenPadding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),                  children: [
                    ListTile(
                      title: const Text('バージョン'),
                      subtitle: Text(_currentVersion),
                      leading: const Icon(Icons.tag),
                    ),
                    const ListTile(
                      title: Text('開発者'),
                      subtitle: Text('筑波大学附属中学校 電子電脳技術研究会'),
                      leading: Icon(Icons.code),
                    ),
                    const Divider(),
                    // アプリについての詳細情報
                    if (_aboutInfo != null) ...[
                      if (_aboutInfo!['error'] != null)
                        ListTile(
                          title: const Text('エラー'),
                          subtitle: Text(_aboutInfo!['error']),
                          leading: const Icon(Icons.error),
                        )
                      else ...[
                        ListTile(
                          title: const Text('アプリ名'),
                          subtitle: Text(_aboutInfo!['appName'] ?? '不明'),
                          leading: const Icon(Icons.apps),
                        ),
                        ListTile(
                          title: const Text('パッケージ名'),
                          subtitle: Text(_aboutInfo!['packageName'] ?? '不明'),
                          leading: const Icon(Icons.inventory),
                        ),
                        ListTile(
                          title: const Text('ビルド番号'),
                          subtitle: Text(_aboutInfo!['buildNumber'] ?? '不明'),
                          leading: const Icon(Icons.build),
                        ),
                        ListTile(
                          title: const Text('プラットフォーム'),
                          subtitle: Text(_aboutInfo!['platform'] ?? '不明'),
                          leading: const Icon(Icons.computer),
                        ),
                        if (_aboutInfo!['model'] != null)
                          ListTile(
                            title: const Text('デバイスモデル'),
                            subtitle: Text(_aboutInfo!['model']),
                            leading: const Icon(Icons.phone_android),
                          ),
                        if (_aboutInfo!['androidVersion'] != null)
                          ListTile(
                            title: const Text('Androidバージョン'),
                            subtitle: Text(_aboutInfo!['androidVersion']),
                            leading: const Icon(Icons.android),
                          ),
                        if (_aboutInfo!['supportedArch'] != null)
                          ListTile(
                            title: const Text('サポートアーキテクチャ'),
                            subtitle: Text((_aboutInfo!['supportedArch'] as List).join(', ')),
                            leading: const Icon(Icons.architecture),
                          ),
                        ListTile(
                          title: const Text('ビルドタイプ'),
                          subtitle: Text(_aboutInfo!['flavor'] ?? '不明'),
                          leading: const Icon(Icons.settings),
                        ),
                      ],
                    ] else ...[
                      const ListTile(
                        title: Text('情報の読み込み中...'),
                        leading: CircularProgressIndicator(),
                      ),
                    ],
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
