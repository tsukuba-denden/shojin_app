import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
                      subtitle: const Text('1.0.0'),
                      leading: const Icon(Icons.tag),
                    ),
                    ListTile(
                      title: const Text('開発者'),
                      subtitle: const Text('筑波電子同好会'),
                      leading: const Icon(Icons.code),
                    ),
                  ],
                ),
              ),
            ),
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
