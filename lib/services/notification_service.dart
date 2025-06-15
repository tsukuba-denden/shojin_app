
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// import '../models/contest.dart'; // 必要に応じて Contest モデルをインポート
// import '../models/reminder_setting.dart'; // 必要に応じて ReminderSetting モデルをインポート

class NotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // TODO: アプリアイコンを確認・設定

    // iOS の初期化設定 (macOS も同様)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // onDidReceiveLocalNotification: onDidReceiveLocalNotification, // 古いiOSバージョン用
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
      macOS: initializationSettingsIOS, // macOS も DarwinInitializationSettings を使用
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // onDidReceiveNotificationResponse: onDidReceiveNotificationResponse, // 通知タップ時の処理
    );

    // タイムゾーンの初期化
    tz.initializeTimeZones();
    // tz.setLocalLocation(tz.getLocation('Asia/Tokyo')); // 必要に応じてデフォルトのタイムゾーンを設定
  }

  // 通知タップ時のコールバック (例)
  // void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
  //   final String? payload = notificationResponse.payload;
  //   if (notificationResponse.payload != null) {
  //     debugPrint('notification payload: $payload');
  //   }
  //   // ペイロードに基づいて特定の画面に遷移するなどの処理
  // }

  // 古いiOSバージョン用の通知受信コールバック (例)
  // void onDidReceiveLocalNotification(
  //     int id, String? title, String? body, String? payload) async {
  //   // display a dialog with the notification details, tap ok to go to another page
  // }  Future<void> requestPermissions() async {
    // Android の通知許可は通常、初期化時に自動的に処理されるか、
    // アプリがフォアグラウンドで通知を送信しようとしたときに処理される
    
    // iOS の通知許可
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    // macOS の通知許可
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local), // デバイスのローカルタイムゾーンを使用
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'shojin_app_channel_id', // チャンネルID
          'Shojin App Notifications', // チャンネル名
          channelDescription: 'Notifications for Shojin App contests', // チャンネルの説明
          importance: Importance.max,
          priority: Priority.high,
          // sound: RawResourceAndroidNotificationSound('notification_sound'), // カスタムサウンド (res/raw に配置)
          // styleInformation: BigTextStyleInformation(''), // 長いテキスト用
        ),
        iOS: DarwinNotificationDetails(
          // sound: 'notification_sound.aiff', // カスタムサウンド (Runner/Resources に配置)
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
        macOS: DarwinNotificationDetails(
          // sound: 'notification_sound.aiff', // カスタムサウンド
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidAllowWhileIdle: true, // アイドル時でも通知を許可
      payload: payload,
      // matchDateTimeComponents: DateTimeComponents.time, // 毎日同じ時間に繰り返す場合など
    );
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
