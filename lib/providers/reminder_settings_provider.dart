import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/reminder_setting.dart';

class ReminderSettingsProvider with ChangeNotifier {
  static const String _storageKey = 'reminder_settings';
  
  // デフォルトの設定値
  final Map<ContestType, ReminderSetting> _defaultSettings = {
    ContestType.abc: ReminderSetting(contestType: ContestType.abc, minutesBefore: 10),
    ContestType.arc: ReminderSetting(contestType: ContestType.arc, minutesBefore: 15),
    ContestType.agc: ReminderSetting(contestType: ContestType.agc, minutesBefore: 15),
    ContestType.ahc: ReminderSetting(contestType: ContestType.ahc, minutesBefore: 30),
  };

  Map<ContestType, ReminderSetting> _settings = {};
  bool _isLoading = false;

  Map<ContestType, ReminderSetting> get settings => _settings;
  bool get isLoading => _isLoading;

  // 特定のコンテストタイプの設定を取得
  ReminderSetting? getSettingForContestType(ContestType contestType) {
    return _settings[contestType];
  }

  // 初期化（アプリ起動時に呼び出す）
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadSettings();
    } catch (e) {
      debugPrint('リマインダー設定の読み込みに失敗しました: $e');
      // エラーが発生した場合はデフォルト設定を使用
      _settings = Map.from(_defaultSettings);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 設定をローカルストレージから読み込み
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_storageKey);
    
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> jsonMap = json.decode(settingsJson);
        _settings = {};
        
        jsonMap.forEach((key, value) {
          final contestType = ContestType.values.firstWhere(
            (e) => e.toString() == key,
            orElse: () => ContestType.other,
          );
          _settings[contestType] = ReminderSetting.fromJson(value);
        });
        
        // デフォルト設定で不足している項目を補完
        _defaultSettings.forEach((contestType, defaultSetting) {
          if (!_settings.containsKey(contestType)) {
            _settings[contestType] = defaultSetting;
          }
        });
      } catch (e) {
        debugPrint('リマインダー設定のJSONパースに失敗しました: $e');
        _settings = Map.from(_defaultSettings);
      }
    } else {
      // 初回起動時などで設定がない場合はデフォルト設定を使用
      _settings = Map.from(_defaultSettings);
    }
  }

  // 設定をローカルストレージに保存
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> jsonMap = {};
    
    _settings.forEach((contestType, setting) {
      jsonMap[contestType.toString()] = setting.toJson();
    });
    
    await prefs.setString(_storageKey, json.encode(jsonMap));
  }

  // 特定のコンテストタイプの設定を更新
  Future<void> updateSetting(ContestType contestType, ReminderSetting newSetting) async {
    _settings[contestType] = newSetting;
    notifyListeners();
    await _saveSettings();
  }

  // 特定のコンテストタイプの通知時間を更新
  Future<void> updateMinutesBefore(ContestType contestType, int minutesBefore) async {
    final currentSetting = _settings[contestType];
    if (currentSetting != null) {
      _settings[contestType] = ReminderSetting(
        contestType: contestType,
        minutesBefore: minutesBefore,
        isEnabled: currentSetting.isEnabled,
      );
      notifyListeners();
      await _saveSettings();
    }
  }

  // 特定のコンテストタイプの有効/無効を切り替え
  Future<void> toggleEnabled(ContestType contestType) async {
    final currentSetting = _settings[contestType];
    if (currentSetting != null) {
      _settings[contestType] = ReminderSetting(
        contestType: contestType,
        minutesBefore: currentSetting.minutesBefore,
        isEnabled: !currentSetting.isEnabled,
      );
      notifyListeners();
      await _saveSettings();
    }
  }

  // すべての設定をリセット（デフォルト値に戻す）
  Future<void> resetToDefaults() async {
    _settings = Map.from(_defaultSettings);
    notifyListeners();
    await _saveSettings();
  }
}
