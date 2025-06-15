import 'package:flutter/foundation.dart';
import '../models/contest.dart';
import '../models/reminder_setting.dart';
import '../providers/contest_provider.dart';
import '../providers/reminder_settings_provider.dart';
import './notification_service.dart';

class ContestReminderService {
  final NotificationService _notificationService = NotificationService();
    // コンテスト名から ContestType を判定
  ContestType _getContestTypeFromName(String contestName) {
    final lowerName = contestName.toLowerCase();
    if (lowerName.contains('abc') || lowerName.contains('beginner')) {
      return ContestType.abc;
    } else if (lowerName.contains('arc') || lowerName.contains('regular')) {
      return ContestType.arc;
    } else if (lowerName.contains('agc') || lowerName.contains('grand')) {
      return ContestType.agc;
    } else if (lowerName.contains('ahc') || lowerName.contains('heuristic')) {
      return ContestType.ahc;
    }
    return ContestType.other;
  }

  // 単一コンテストのリマインダーをスケジュール
  Future<void> scheduleReminderForContest(
    Contest contest,
    ReminderSetting reminderSetting,
  ) async {
    if (!reminderSetting.isEnabled) {
      debugPrint('リマインダーが無効のため、スケジュールをスキップします: ${contest.nameJa}');
      return;
    }

    // 通知時刻を計算
    final notificationTime = contest.startTime.subtract(
      Duration(minutes: reminderSetting.minutesBefore),
    );

    // 過去の時刻の場合はスケジュールしない
    if (notificationTime.isBefore(DateTime.now())) {
      debugPrint('通知時刻が過去のため、スケジュールをスキップします: ${contest.nameJa}');
      return;
    }

    // 通知IDを生成（コンテストIDのハッシュなど）
    final notificationId = contest.nameJa.hashCode;

    try {
      await _notificationService.scheduleNotification(
        id: notificationId,
        title: 'コンテスト開始のお知らせ',
        body: '${contest.nameJa} が ${reminderSetting.minutesBefore} 分後に開始されます',
        scheduledTime: notificationTime,
        payload: 'contest_reminder:${contest.nameJa}',
      );

      debugPrint('リマインダーをスケジュールしました: ${contest.nameJa} at $notificationTime');
    } catch (e) {
      debugPrint('リマインダーのスケジュールに失敗しました: ${contest.nameJa}, エラー: $e');
    }
  }
  // 複数コンテストのリマインダーを一括スケジュール
  Future<void> scheduleRemindersForContests(
    List<Contest> contests,
    ReminderSettingsProvider reminderSettingsProvider,
  ) async {
    for (final contest in contests) {
      final contestType = _getContestTypeFromName(contest.nameJa);
      final reminderSetting = reminderSettingsProvider.getSettingForContestType(contestType);
      
      if (reminderSetting != null) {
        await scheduleReminderForContest(contest, reminderSetting);
      }
    }
  }
  // 既存のリマインダーをすべてキャンセル
  Future<void> cancelAllReminders() async {
    await _notificationService.cancelAllNotifications();
    debugPrint('すべてのリマインダーをキャンセルしました');
  }

  // 特定のコンテストのリマインダーをキャンセル
  Future<void> cancelReminderForContest(Contest contest) async {
    final notificationId = contest.nameJa.hashCode;
    await _notificationService.cancelNotification(notificationId);
    debugPrint('リマインダーをキャンセルしました: ${contest.nameJa}');
  }

  // ContestProvider からコンテスト情報を取得してリマインダーを更新
  Future<void> updateRemindersFromContestProvider(
    ContestProvider contestProvider,
    ReminderSettingsProvider reminderSettingsProvider,
  ) async {
    try {
      // 既存のリマインダーをキャンセル
      await cancelAllReminders();

      // 今後のコンテストを取得
      final upcomingContests = contestProvider.upcomingContests;
      
      if (upcomingContests.isNotEmpty) {
        await scheduleRemindersForContests(upcomingContests, reminderSettingsProvider);
        debugPrint('${upcomingContests.length} 個のコンテストのリマインダーを更新しました');
      } else {
        debugPrint('今後のコンテストが見つかりませんでした');
      }
    } catch (e) {
      debugPrint('リマインダーの更新に失敗しました: $e');
    }
  }

  // 初期化（アプリ起動時に呼び出す）
  Future<void> initialize() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
  }
}
