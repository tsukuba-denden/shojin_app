import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart'; // For haptic feedback
import '../providers/theme_provider.dart';
import '../providers/template_provider.dart';
import 'template_edit_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
                      subtitle: const Text('Alpha'),
                      leading: const Icon(Icons.tag),
                    ),
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
