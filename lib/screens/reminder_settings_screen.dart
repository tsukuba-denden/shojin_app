import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reminder_setting.dart';
import '../providers/reminder_settings_provider.dart';

class ReminderSettingsScreen extends StatelessWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('リマインダー設定'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _showResetDialog(context);
            },
            tooltip: 'デフォルトに戻す',
          ),
        ],
      ),
      body: Consumer<ReminderSettingsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const Text(
                'コンテスト開始前の通知設定',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '各コンテストタイプごとに、開始何分前に通知するかを設定できます。',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ...ContestType.values
                  .where((type) => type != ContestType.other)
                  .map((contestType) => _buildContestSetting(
                        context,
                        provider,
                        contestType,
                      ))
                  .toList(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContestSetting(
    BuildContext context,
    ReminderSettingsProvider provider,
    ContestType contestType,
  ) {
    final setting = provider.getSettingForContestType(contestType);
    if (setting == null) return const SizedBox.shrink();

    final contestName = _getContestName(contestType);
    final minutesOptions = [5, 10, 15, 30, 60, 120]; // 通知時間の選択肢

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  contestName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: setting.isEnabled,
                  onChanged: (value) {
                    provider.toggleEnabled(contestType);
                  },
                ),
              ],
            ),
            if (setting.isEnabled) ...[
              const SizedBox(height: 12),
              const Text(
                '通知する時間:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              DropdownButton<int>(
                value: setting.minutesBefore,
                isExpanded: true,
                items: minutesOptions.map((minutes) {
                  return DropdownMenuItem<int>(
                    value: minutes,
                    child: Text('$minutes分前'),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    provider.updateMinutesBefore(contestType, newValue);
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getContestName(ContestType contestType) {
    switch (contestType) {
      case ContestType.abc:
        return 'AtCoder Beginner Contest (ABC)';
      case ContestType.arc:
        return 'AtCoder Regular Contest (ARC)';
      case ContestType.agc:
        return 'AtCoder Grand Contest (AGC)';
      case ContestType.ahc:
        return 'AtCoder Heuristic Contest (AHC)';
      case ContestType.other:
        return 'その他のコンテスト';
    }
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('設定をリセット'),
          content: const Text('すべてのリマインダー設定をデフォルト値に戻しますか？'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('リセット'),
              onPressed: () {
                context.read<ReminderSettingsProvider>().resetToDefaults();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('設定をリセットしました')),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
