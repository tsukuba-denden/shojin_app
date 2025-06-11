import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:google_fonts/google_fonts.dart'; // Add Google Fonts
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
    return CustomScrollView(
      slivers: [
        // カスタムヘッダー
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
            child: Text(
              '設定',
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        
        // 設定項目のリスト
        SliverList(
          delegate: SliverChildListDelegate([
            // テーマ設定セクション
            _SUpdateThemeUI(),
            const SizedBox(height: 16),
            
            // テンプレート設定セクション
            _STemplateSection(),
            const SizedBox(height: 16),
            
            // 更新設定セクション
            _SUpdateSection(),
            const SizedBox(height: 16),
            
            // アプリについてセクション
            _SAboutSection(),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  }  // 新しいセクションウィジェット群
  Widget _SUpdateThemeUI() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return _SettingsSection(
          title: 'テーマ設定',
          icon: Icons.palette,
          children: [
            ...ThemeModeOption.values.map((mode) => _HapticRadioListTile<ThemeModeOption>(
              title: mode.label,
              value: mode,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                }
              },
              secondary: _getThemeIcon(mode),
            )),
            _HapticSwitchListTile(
              title: 'Material You (ダイナミックカラー)',
              subtitle: '壁紙の色に基づいてテーマを生成',
              value: themeProvider.useMaterialYou,
              onChanged: themeProvider.setUseMaterialYou,
              icon: Icons.color_lens_outlined,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ナビゲーションバーの透明度',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    min: 0.0,
                    max: 1.0,
                    divisions: 20,
                    label: themeProvider.navBarOpacity.toStringAsFixed(2),
                    value: themeProvider.navBarOpacity,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      themeProvider.setNavBarOpacity(value);
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _STemplateSection() {
    return Consumer<TemplateProvider>(
      builder: (context, templateProvider, child) {
        return _SettingsSection(
          title: 'テンプレート設定',
          icon: Icons.code,
          children: templateProvider.supportedLanguages.map((language) {
            return ListTile(
              title: Text(
                language,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              trailing: Icon(
                Icons.edit_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              onTap: () {
                HapticFeedback.lightImpact();
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
      },
    );
  }

  Widget _SUpdateSection() {
    return _SettingsSection(
      title: '更新設定',
      icon: Icons.system_update_alt,
      children: [
        _HapticSwitchListTile(
          title: 'アプリ起動時に自動で更新を確認',
          value: _autoUpdateCheckEnabled,
          onChanged: _setAutoUpdatePreference,
          icon: Icons.sync_outlined,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingUpdate ? null : _checkForUpdates,
                  icon: const Icon(Icons.update),
                  label: const Text('アップデートを手動で確認'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ),
              if (_isLoadingUpdate) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
              if (_updateCheckResult.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _updateCheckResult,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _SAboutSection() {
    return _SettingsSection(
      title: 'アプリについて',
      icon: Icons.info_outline,
      children: [
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
        if (_aboutInfo != null) ...[
          const Divider(),
          if (_aboutInfo!['error'] != null)
            ListTile(
              title: const Text('エラー'),
              subtitle: Text(_aboutInfo!['error']),
              leading: const Icon(Icons.error),
            )
          else ..._buildAboutDetails(),
        ] else
          const ListTile(
            title: Text('情報の読み込み中...'),
            leading: CircularProgressIndicator(),
          ),
      ],
    );
  }

  List<Widget> _buildAboutDetails() {
    return [
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
    ];
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

// 設定セクションのベースウィジェット
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 8.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ハプティックフィードバック付きスイッチListTile
class _HapticSwitchListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;

  const _HapticSwitchListTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      value: value,
      onChanged: (newValue) {
        HapticFeedback.lightImpact();
        onChanged(newValue);
      },
      secondary: Icon(icon),
    );
  }
}

// ハプティックフィードバック付きRadioListTile
class _HapticRadioListTile<T> extends StatelessWidget {
  final String title;
  final T value;
  final T? groupValue;
  final ValueChanged<T?> onChanged;
  final Widget secondary;

  const _HapticRadioListTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
      title: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      value: value,
      groupValue: groupValue,
      onChanged: (newValue) {
        HapticFeedback.lightImpact();
        onChanged(newValue);
      },
      secondary: secondary,
    );
  }
}
