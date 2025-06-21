import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_setting.dart';

class ReminderStorageService {
  static const _keyReminderSettings = 'reminder_settings';

  Future<void> saveReminderSettings(List<ReminderSetting> settings) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      settings.map((setting) => setting.toJson()).toList(),
    );
    await prefs.setString(_keyReminderSettings, encodedData);
  }

  Future<List<ReminderSetting>> loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encodedData = prefs.getString(_keyReminderSettings);
    if (encodedData == null) {
      return []; // まだ設定がない場合は空のリストを返す
    }
    final List<dynamic> decodedData = jsonDecode(encodedData);
    return decodedData
        .map((item) => ReminderSetting.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // 特定のコンテストタイプの設定を更新または追加するヘルパーメソッド (任意)
  Future<void> updateReminderSetting(ReminderSetting settingToUpdate) async {
    List<ReminderSetting> currentSettings = await loadReminderSettings();
    int existingIndex = currentSettings.indexWhere(
        (s) => s.contestType == settingToUpdate.contestType);

    if (existingIndex != -1) {
      currentSettings[existingIndex] = settingToUpdate;
    } else {
      currentSettings.add(settingToUpdate);
    }
    await saveReminderSettings(currentSettings);
  }

  // 特定のコンテストタイプの設定を取得するヘルパーメソッド (任意)
  Future<ReminderSetting?> getReminderSetting(ContestType contestType) async {
    List<ReminderSetting> currentSettings = await loadReminderSettings();
    try {
      return currentSettings
          .firstWhere((s) => s.contestType == contestType);
    } catch (e) {
      return null; // 見つからない場合はnull
    }
  }
}