import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
const String _navOpacityKey = 'nav_opacity'; // Key for bottom nav opacity

class ThemeProvider extends ChangeNotifier {
  final String _prefsKey = 'theme_mode';
  double _navBarOpacity = 0.5; // Default bottom nav opacity
  ThemeModeOption _themeMode = ThemeModeOption.system;
  bool _isLoading = true;

  ThemeProvider() {
    _loadFromPrefs();
  }

  // 現在のテーマモード
  ThemeModeOption get themeMode => _themeMode;
  
  // BottomNavigationBar transparency
  double get navBarOpacity => _navBarOpacity;

  // ローディング状態
  bool get isLoading => _isLoading;
  
  // テーマモードがピュアブラックかどうか
  bool get isPureBlack => _themeMode == ThemeModeOption.pureBlack;
  
  // テーマモードをFlutterのThemeModeに変換
  ThemeMode get themeModeForFlutter => _themeMode.toThemeMode();

  // テーマモードを変更
  Future<void> setThemeMode(ThemeModeOption mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await _saveToPrefs();
    notifyListeners();
  }

  // テーマモードを設定から読み込む
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_prefsKey);
    // Load saved nav opacity if exists
    final savedOpacity = prefs.getDouble(_navOpacityKey);
    if (savedOpacity != null) {
      _navBarOpacity = savedOpacity;
    }
    
    if (themeModeIndex != null && 
        themeModeIndex >= 0 && 
        themeModeIndex < ThemeModeOption.values.length) {
      _themeMode = ThemeModeOption.values[themeModeIndex];
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // テーマモードを設定に保存
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, _themeMode.index);
  }
  
  // Set bottom nav opacity and persist
  Future<void> setNavBarOpacity(double opacity) async {
    _navBarOpacity = opacity;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_navOpacityKey, opacity);
    notifyListeners();
  }
}

// テーマモードの選択肢
enum ThemeModeOption {
  system('システム設定に従う'), 
  light('ライトモード'), 
  dark('ダークモード'),
  pureBlack('ピュアブラック');
  
  final String label;
  const ThemeModeOption(this.label);
}

// テーマモードとFlutterのThemeModeの変換メソッド
extension ThemeModeExtension on ThemeModeOption {
  ThemeMode toThemeMode() {
    switch (this) {
      case ThemeModeOption.system:
        return ThemeMode.system;
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
      case ThemeModeOption.pureBlack:
        return ThemeMode.dark;
    }
  }
}
