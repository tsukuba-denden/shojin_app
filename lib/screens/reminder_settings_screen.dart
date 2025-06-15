import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // TextInputFormatterのため
import '../models/reminder_setting.dart';
import '../services/reminder_storage_service.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _NotificationTimeOption {
  final String label;
  final int? value; // null の場合はカスタム入力を示す

  const _NotificationTimeOption(this.label, this.value);
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final ReminderStorageService _storageService = ReminderStorageService();
  List<ReminderSetting> _reminderSettings = [];
  bool _isLoading = true;

  final Map<ContestType, String> _contestTypeNames = {
    ContestType.abc: 'AtCoder Beginner Contest',
    ContestType.arc: 'AtCoder Regular Contest',
    ContestType.agc: 'AtCoder Grand Contest',
    ContestType.ahc: 'AtCoder Heuristic Contest',
  };

  static const List<_NotificationTimeOption> _timeOptions = [
    _NotificationTimeOption('0分前', 0),
    _NotificationTimeOption('5分前', 5),
    _NotificationTimeOption('10分前', 10),
    _NotificationTimeOption('15分前', 15),
    _NotificationTimeOption('30分前', 30),
    _NotificationTimeOption('1時間前', 60),
    _NotificationTimeOption('2時間前', 120),
    _NotificationTimeOption('カスタム...', null), // カスタム入力用
  ];


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
    for (var type in _contestTypeNames.keys) {
      if (!loadedSettings.any((s) => s.contestType == type)) {
        loadedSettings.add(ReminderSetting(
          contestType: type,
          minutesBefore: [15],
          isEnabled: true,
        ));
      }
    }
    loadedSettings.sort((a, b) =>
        _contestTypeNames.keys.toList().indexOf(a.contestType) -
        _contestTypeNames.keys.toList().indexOf(b.contestType));

    setState(() {
      _reminderSettings = loadedSettings;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    for (var setting in _reminderSettings) {
      if (setting.minutesBefore.isEmpty) {
        setting.minutesBefore = [15];
      }
    }
    await _storageService.saveReminderSettings(_reminderSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    }
  }

  Future<void> _showCustomTimeInputDialog(int settingIndex) async {
    final TextEditingController controller = TextEditingController();
    final newTime = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('通知時間を入力 (分前)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(hintText: '例: 10'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0) { // 0分前も許可
                Navigator.of(context).pop(value);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('有効な数値を入力してください')),
                );
              }
            },
            child: const Text('決定'),
          ),
        ],
      ),
    );

    if (newTime != null) {
      setState(() {
        if (!_reminderSettings[settingIndex].minutesBefore.contains(newTime)) {
          _reminderSettings[settingIndex].minutesBefore.add(newTime);
          _reminderSettings[settingIndex].minutesBefore.sort();
        }
      });
    }
  }

  Future<void> _addNotificationTime(int settingIndex) async {
    final selectedOption = await showDialog<_NotificationTimeOption>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('通知時間を選択'),
          children: _timeOptions.map((option) {
            return SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, option);
              },
              child: Text(option.label),
            );
          }).toList(),
        );
      },
    );

    if (selectedOption != null) {
      if (selectedOption.value != null) {
        // 事前定義された時間
        setState(() {
          if (!_reminderSettings[settingIndex].minutesBefore.contains(selectedOption.value!)) {
            _reminderSettings[settingIndex].minutesBefore.add(selectedOption.value!);
            _reminderSettings[settingIndex].minutesBefore.sort();
          }
        });
      } else {
        // カスタム入力
        await _showCustomTimeInputDialog(settingIndex);
      }
    }
  }

  void _removeNotificationTime(int settingIndex, int timeToRemove) {
    setState(() {
      _reminderSettings[settingIndex].minutesBefore.remove(timeToRemove);
    });
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
                            const Text('通知タイミング (分前):'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: setting.minutesBefore.map((time) {
                                return Chip(
                                  label: Text('$time 分前'),
                                  onDeleted: () => _removeNotificationTime(index, time),
                                );
                              }).toList(),
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.add_alarm_outlined),
                              label: const Text('時間を追加'),
                              onPressed: () => _addNotificationTime(index),
                            ),
                            const SizedBox(height: 8),
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