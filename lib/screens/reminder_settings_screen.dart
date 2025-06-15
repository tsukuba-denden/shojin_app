import 'package:flutter/material.dart';
import '../models/reminder_setting.dart';
import '../services/reminder_storage_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final ReminderStorageService _storageService = ReminderStorageService();
  List<ReminderSetting> _reminderSettings = [];
  bool _isLoading = true;

  // 利用可能なコンテスト種別とデフォルトの通知時間
  final Map<ContestType, String> _contestTypeNames = {
    ContestType.abc: 'AtCoder Beginner Contest',
    ContestType.arc: 'AtCoder Regular Contest',
    ContestType.agc: 'AtCoder Grand Contest',
    ContestType.ahc: 'AtCoder Heuristic Contest',
  };

  // 通知タイミングの選択肢 (分)
  final List<int> _notificationMinutesOptions = [5, 10, 15, 30, 60];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    final loadedSettings = await _storageService.loadReminderSettings();
    // 不足しているコンテストタイプがあればデフォルト値で補完
    for (var type in _contestTypeNames.keys) {
      if (!loadedSettings.any((s) => s.contestType == type)) {
        loadedSettings.add(ReminderSetting(
          contestType: type,
          minutesBefore: 15, // デフォルト15分前
          isEnabled: true,
        ));
      }
    }
    // 表示順を固定するためにソート
    loadedSettings.sort((a, b) =>
        _contestTypeNames.keys.toList().indexOf(a.contestType) -
        _contestTypeNames.keys.toList().indexOf(b.contestType));

    setState(() {
      _reminderSettings = loadedSettings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    await _storageService.saveReminderSettings(_reminderSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('リマインダー設定'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_outlined),
            tooltip: '設定を保存',
            onPressed: _isLoading ? null : _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reminderSettings.isEmpty
              ? const Center(child: Text('設定項目がありません。'))
              : ListView.builder(
                  itemCount: _reminderSettings.length,
                  itemBuilder: (context, index) {
                    final setting = _reminderSettings[index];
                    final contestName = _contestTypeNames[setting.contestType] ?? 'その他';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contestName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('通知タイミング:'),
                                DropdownButton<int>(
                                  value: _notificationMinutesOptions.contains(setting.minutesBefore)
                                      ? setting.minutesBefore
                                      : _notificationMinutesOptions.first, // カスタム値の場合は先頭を選択
                                  items: _notificationMinutesOptions
                                      .map((minutes) => DropdownMenuItem(
                                            value: minutes,
                                            child: Text('$minutes 分前'),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _reminderSettings[index].minutesBefore = value;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                            SwitchListTile(
                              title: const Text('リマインダーを有効にする'),
                              value: setting.isEnabled,
                              onChanged: (bool value) {
                                setState(() {
                                  _reminderSettings[index].isEnabled = value;
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}