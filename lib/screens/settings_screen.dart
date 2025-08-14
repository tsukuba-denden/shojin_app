import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import 'package:google_fonts/google_fonts.dart'; // Add Google Fonts
import 'package:shared_preferences/shared_preferences.dart'; // For settings persistence
import 'package:url_launcher/url_launcher.dart'; // For launching URLs
import 'package:flutter_svg/flutter_svg.dart'; // For SVG icons
import '../providers/theme_provider.dart';
import '../providers/template_provider.dart';
import 'template_edit_screen.dart';
import 'tex_test_screen.dart'; // TeX表示テスト画面をインポート
import '../services/enhanced_update_service.dart'; // Use enhanced service
import '../services/auto_update_manager.dart'; // Import auto update manager
import '../services/about_info.dart'; // Import AboutInfo
import '../utils/text_style_helper.dart';
import '../widgets/shared/custom_sliver_app_bar.dart'; // Import CustomSliverAppBar

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
  bool _showUpdateDialog = true; // アップデート通知の表示設定
  Map<String, dynamic>? _aboutInfo;
  @override
  void initState() {
    super.initState();
    _loadCurrentVersion();
    _loadAutoUpdatePreference(); // Load preference
    _loadShowUpdateDialogPreference(); // Load show update dialog preference
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

  // Method to load show update dialog preference
  Future<void> _loadShowUpdateDialogPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedShowUpdateDialog = prefs.getBool('show_update_dialog');
      if (mounted) {
        setState(() {
          _showUpdateDialog = savedShowUpdateDialog ?? true; // デフォルトはtrue
        });
      }
    } catch (e) {
      print('Failed to load show update dialog preference: $e');
    }
  }

  // Method to set show update dialog preference
  Future<void> _setShowUpdateDialog(bool value) async {
    // SharedPreferencesを使って設定を保存
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('show_update_dialog', value);
      if (mounted) {
        setState(() {
          _showUpdateDialog = value;
        });
      }
    } catch (e) {
      print('Failed to save show update dialog preference: $e');
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
      EnhancedAppUpdateInfo? releaseInfo = await _autoUpdateManager
          .checkForUpdatesManually();
      if (!mounted) return;

      if (releaseInfo != null) {
        setState(() {
          _updateCheckResult = "新しいバージョンがあります: ${releaseInfo.version}";
        });
        _showUpdateDialogMethod(releaseInfo);
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
  }

  void _showUpdateDialogMethod(EnhancedAppUpdateInfo releaseInfo) {
    if (!mounted) return;
    _autoUpdateManager.showManualUpdateDialog(context, releaseInfo);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // カスタムSliverAppBar
        CustomSliverAppBar(
          isMainView: true,
          title: Text(
            '設定',
            style: GoogleFonts.notoSansJp(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge!.color,
            ),
          ),
        ),

        // 設定項目のリスト
        SliverList(
          delegate: SliverChildListDelegate([
            // テーマ設定セクション
            _SUpdateThemeUI(),
            const SizedBox(height: 16),

            // 言語設定セクション
            _SUpdateLanguageUI(),
            const SizedBox(height: 16),

            // テンプレート設定セクション
            _STemplateSection(),
            const SizedBox(height: 16),

            // 更新設定セクション
            _SUpdateSection(),
            const SizedBox(height: 16),

            // エクスポート/インポート設定セクション
            _SExportSection(),
            const SizedBox(height: 16),

            // アプリについてセクション
            _SAboutSection(),
            const SizedBox(height: 32),
          ]),
        ),
      ],
    );
  } // 新しいセクションウィジェット群

  Widget _SUpdateThemeUI() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return _SettingsSection(
          title: 'テーマ設定',
          icon: Icons.palette,
          children: [
            ...ThemeModeOption.values.map(
              (mode) => _HapticRadioListTile<ThemeModeOption>(
                title: mode.label,
                value: mode,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) {
                    themeProvider.setThemeMode(value);
                  }
                },
                secondary: _getThemeIcon(mode),
              ),
            ),
            _HapticSwitchListTile(
              title: 'Material You',
              subtitle: 'よりデバイスに近い体験が楽しめます',
              value: themeProvider.useMaterialYou,
              onChanged: themeProvider.setUseMaterialYou,
              icon: Icons.color_lens_outlined,
            ),
            const Divider(),
            // Font Family Selector
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
              child: DropdownButtonFormField<String>(
                value: themeProvider.codeFontFamily,
                decoration: InputDecoration(
                  labelText: 'コードブロックのフォント',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  prefixIcon: const Icon(Icons.font_download_outlined),
                ),
                items: themeProvider.availableCodeFontFamilies.map((
                  String fontFamily,
                ) {
                  return DropdownMenuItem<String>(
                    value: fontFamily,
                    child: Text(
                      fontFamily,
                      style: getMonospaceTextStyle(fontFamily),
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    HapticFeedback.lightImpact();
                    themeProvider.setCodeFontFamily(newValue);
                  }
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ナビゲーションバーの透明度',
                    style: GoogleFonts.notoSansJp(
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
                style: GoogleFonts.notoSansJp(
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
                    builder: (context) =>
                        TemplateEditScreen(language: language),
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
        _HapticSwitchListTile(
          title: 'アップデート通知を表示',
          subtitle: '新しいバージョンが利用可能な時に通知を表示',
          value: _showUpdateDialog,
          onChanged: _setShowUpdateDialog,
          icon: Icons.notifications_outlined,
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
                  style: GoogleFonts.notoSansJp(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _SUpdateLanguageUI() {
    return _SettingsSection(
      title: '言語設定',
      icon: Icons.language,
      children: [
        ListTile(
          title: Text(
            '日本語',
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          subtitle: const Text('Japanese'),
          leading: const Icon(Icons.language),
          trailing: const Icon(Icons.check, color: Colors.green),
          onTap: () {
            HapticFeedback.lightImpact();
            // 将来的に多言語対応する際の実装場所
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('現在は日本語のみサポートしています')));
          },
        ),
      ],
    );
  }

  Widget _SExportSection() {
    return _SettingsSection(
      title: 'エクスポート/インポート',
      icon: Icons.import_export,
      children: [
        ListTile(
          title: Text(
            '設定をエクスポート',
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          subtitle: const Text('現在の設定をファイルに保存'),
          leading: const Icon(Icons.upload_file),
          onTap: () async {
            HapticFeedback.lightImpact();
            await _exportSettings();
          },
        ),
        ListTile(
          title: Text(
            '設定をインポート',
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          subtitle: const Text('ファイルから設定を復元'),
          leading: const Icon(Icons.file_download),
          onTap: () async {
            HapticFeedback.lightImpact();
            await _importSettings();
          },
        ),
        const Divider(),
        ListTile(
          title: Text(
            'テンプレートをエクスポート',
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          subtitle: const Text('カスタムテンプレートをファイルに保存'),
          leading: const Icon(Icons.code_rounded),
          onTap: () async {
            HapticFeedback.lightImpact();
            await _exportTemplates();
          },
        ),
        ListTile(
          title: Text(
            'テンプレートをインポート',
            style: GoogleFonts.notoSansJp(
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          subtitle: const Text('ファイルからテンプレートを復元'),
          leading: const Icon(Icons.code_outlined),
          onTap: () async {
            HapticFeedback.lightImpact();
            await _importTemplates();
          },
        ),
      ],
    );
  }

  Widget _SAboutSection() {
    return _SettingsSection(
      title: 'アプリについて',
      icon: Icons.info_outline,
      children: [
        _CopyableListTile(
          title: 'バージョン',
          subtitle: _currentVersion,
          icon: Icons.tag,
          onCopy: _copyAllAppInfo,
        ),
        // 開発者セクション（ソーシャルメディアリンク付き）
        _DeveloperSection(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: const Text('オープンソースライセンス'),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'Shojin App',
              applicationVersion: _currentVersion,
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('プライバシーポリシー'),
          onTap: () {
            launchUrl(
              Uri.parse(
                'https://github.com/yuubinnkyoku/shojin_app/blob/main/PRIVACY_POLICY.md',
              ),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.article_outlined),
          title: const Text('利用規約'),
          onTap: () {
            launchUrl(
              Uri.parse(
                'https://github.com/yuubinnkyoku/shojin_app/blob/main/TERMS_OF_USE.md',
              ),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.functions),
          title: const Text('TeX表示テスト'),
          subtitle: const Text('LaTeX数式レンダリングの動作確認'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const TexTestScreen()),
            );
          },
        ),
        if (_aboutInfo != null) ...[
          const Divider(),
          if (_aboutInfo!['error'] != null)
            ListTile(
              title: const Text('エラー'),
              subtitle: Text(_aboutInfo!['error']),
              leading: const Icon(Icons.error),
            )
          else
            ..._buildAboutDetails(),
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
      _CopyableListTile(
        title: 'アプリ名',
        subtitle: _aboutInfo!['appName'] ?? '不明',
        icon: Icons.apps,
        onCopy: _copyAllAppInfo,
      ),
      _CopyableListTile(
        title: 'パッケージ名',
        subtitle: _aboutInfo!['packageName'] ?? '不明',
        icon: Icons.inventory,
        onCopy: _copyAllAppInfo,
      ),
      _CopyableListTile(
        title: 'ビルド番号',
        subtitle: _aboutInfo!['buildNumber'] ?? '不明',
        icon: Icons.build,
        onCopy: _copyAllAppInfo,
      ),
      _CopyableListTile(
        title: 'プラットフォーム',
        subtitle: _aboutInfo!['platform'] ?? '不明',
        icon: Icons.computer,
        onCopy: _copyAllAppInfo,
      ),
      if (_aboutInfo!['model'] != null)
        _CopyableListTile(
          title: 'デバイスモデル',
          subtitle: _aboutInfo!['model'],
          icon: Icons.phone_android,
          onCopy: _copyAllAppInfo,
        ),
      if (_aboutInfo!['androidVersion'] != null)
        _CopyableListTile(
          title: 'Androidバージョン',
          subtitle: _aboutInfo!['androidVersion'],
          icon: Icons.android,
          onCopy: _copyAllAppInfo,
        ),
      if (_aboutInfo!['supportedArch'] != null)
        _CopyableListTile(
          title: 'サポートアーキテクチャ',
          subtitle: (_aboutInfo!['supportedArch'] as List).join(', '),
          icon: Icons.architecture,
          onCopy: _copyAllAppInfo,
        ),
      _CopyableListTile(
        title: 'ビルドタイプ',
        subtitle: _aboutInfo!['flavor'] ?? '不明',
        icon: Icons.settings,
        onCopy: _copyAllAppInfo,
      ),
    ];
  }

  Widget _DeveloperSection() {
    return ExpansionTile(
      title: Text(
        '開発者',
        style: GoogleFonts.notoSansJp(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: const Text('〒«ゆうびんきょく»'),
      leading: const Icon(Icons.code),
      shape: const Border(), // 白い線を非表示にする
      collapsedShape: const Border(), // 折りたたみ時の白い線も非表示にする
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              _SocialMediaItem(
                icon: Icons.language,
                title: 'Website',
                subtitle: 'yuubinnkyoku.github.io',
                url: 'https://yuubinnkyoku.github.io/',
              ),
              _SocialMediaItem(
                icon: SvgPicture.asset(
                  'assets/icon/twitter_logo.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                title: 'Twitter',
                subtitle: '@yuubinnkyoku_mk',
                url: 'https://twitter.com/yuubinnkyoku_mk',
              ),
              _SocialMediaItem(
                icon: SvgPicture.asset(
                  'assets/icon/youtube_logo.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                title: 'YouTube',
                subtitle: '@yuubinnkyoku',
                url: 'https://www.youtube.com/@yuubinnkyoku',
              ),
              _SocialMediaItem(
                icon: SvgPicture.asset(
                  'assets/icon/github_logo.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    Theme.of(context).colorScheme.primary,
                    BlendMode.srcIn,
                  ),
                ),
                title: 'GitHub',
                subtitle: 'yuubinnkyoku',
                url: 'https://github.com/yuubinnkyoku',
              ),
            ],
          ),
        ),
      ],
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

  // エクスポート/インポートメソッド群
  Future<void> _exportSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

      final settings = {
        'theme_mode': themeProvider.themeMode.index,
        'use_material_you': themeProvider.useMaterialYou,
        'nav_bar_opacity': themeProvider.navBarOpacity,
        'auto_update_enabled': _autoUpdateCheckEnabled,
        'show_update_dialog': _showUpdateDialog,
      };

      // 将来的にファイルとして保存する実装を追加
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定のエクスポート機能は開発中です')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('設定のエクスポートに失敗しました: $e')));
    }
  }

  Future<void> _importSettings() async {
    try {
      // 将来的にファイルから設定を読み込む実装を追加
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定のインポート機能は開発中です')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('設定のインポートに失敗しました: $e')));
    }
  }

  Future<void> _exportTemplates() async {
    try {
      final templateProvider = Provider.of<TemplateProvider>(
        context,
        listen: false,
      );

      // 将来的にテンプレートをファイルとして保存する実装を追加
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テンプレートのエクスポート機能は開発中です')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('テンプレートのエクスポートに失敗しました: $e')));
    }
  }

  Future<void> _importTemplates() async {
    try {
      // 将来的にファイルからテンプレートを読み込む実装を追加
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テンプレートのインポート機能は開発中です')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('テンプレートのインポートに失敗しました: $e')));
    }
  }

  String _getAllAppInfo() {
    List<String> infoLines = [];

    // バージョン情報
    infoLines.add('バージョン: $_currentVersion');

    // アプリについての詳細情報
    if (_aboutInfo != null && _aboutInfo!['error'] == null) {
      infoLines.add('アプリ名: ${_aboutInfo!['appName'] ?? '不明'}');
      infoLines.add('パッケージ名: ${_aboutInfo!['packageName'] ?? '不明'}');
      infoLines.add('ビルド番号: ${_aboutInfo!['buildNumber'] ?? '不明'}');
      infoLines.add('プラットフォーム: ${_aboutInfo!['platform'] ?? '不明'}');

      if (_aboutInfo!['model'] != null) {
        infoLines.add('デバイスモデル: ${_aboutInfo!['model']}');
      }

      if (_aboutInfo!['androidVersion'] != null) {
        infoLines.add('Androidバージョン: ${_aboutInfo!['androidVersion']}');
      }

      if (_aboutInfo!['supportedArch'] != null) {
        infoLines.add(
          'サポートアーキテクチャ: ${(_aboutInfo!['supportedArch'] as List).join(', ')}',
        );
      }

      infoLines.add('ビルドタイプ: ${_aboutInfo!['flavor'] ?? '不明'}');
    }

    return infoLines.join('\n');
  }

  void _copyAllAppInfo(BuildContext context) {
    String allInfo = _getAllAppInfo();
    Clipboard.setData(ClipboardData(text: allInfo));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('アプリ情報をすべてコピーしました'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
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
                  style: GoogleFonts.notoSansJp(
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
        style: GoogleFonts.notoSansJp(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: GoogleFonts.notoSansJp(
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
        style: GoogleFonts.notoSansJp(
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

// コピー可能なListTile
class _CopyableListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final void Function(BuildContext) onCopy;

  const _CopyableListTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0),
      title: Text(
        title,
        style: GoogleFonts.notoSansJp(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.notoSansJp(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      leading: Icon(icon),
      onLongPress: () => onCopy(context),
      onTap: () {
        HapticFeedback.lightImpact();
        // 短いタップでも説明を表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('長押しでアプリ情報をすべてコピーします'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}

// ソーシャルメディアアイテム
class _SocialMediaItem extends StatelessWidget {
  final dynamic icon; // IconData or Widget
  final String title;
  final String subtitle;
  final String url;

  const _SocialMediaItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
  });
  Future<void> _launchUrl(BuildContext context) async {
    try {
      final uri = Uri.parse(url);
      // より確実なURL起動方法を使用
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      // canLaunchUrlをチェックしないで直接起動を試行
      // 失敗した場合のフォールバック処理
      try {
        await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
        HapticFeedback.lightImpact();
      } catch (fallbackError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('URLを開けませんでした: $url'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'コピー',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URLをクリップボードにコピーしました'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
      leading: icon is IconData
          ? Icon(icon as IconData, color: Theme.of(context).colorScheme.primary)
          : icon as Widget,
      title: Text(
        title,
        style: GoogleFonts.notoSansJp(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.notoSansJp(
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.open_in_new,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        size: 20,
      ),
      onTap: () => _launchUrl(context),
    );
  }
}
