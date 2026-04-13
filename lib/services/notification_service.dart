import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Notification IDs (keep them fixed)
  static const int weeklyId = 1001;
  static const int monthlyId = 1002;
  static const int streakId = 1003;
  static const int coinId = 1004;

  /// Channel (Android)
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'expenso_reminders',
    'Expenso Reminders',
    description: 'Weekly/monthly/streak reminders for Expenso',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    // Timezone init
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation("Asia/Kolkata")); // you can change later

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(initSettings);

    // Create notification channel
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await requestPermission();
  }

  Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  AndroidNotificationDetails _androidDetails() {
    return AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'expenso_channel',
        'Expenso Notifications',
        icon: '@drawable/ic_notification',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
  }

  /// Show instant notification
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _plugin.show(id, title, body, _details(), payload: payload);
  }

  /// Cancel one
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ----------------------------
  // SCHEDULERS
  // ----------------------------

  /// Weekly summary reminder (example: Sunday 8:00 PM)
  Future<void> scheduleWeeklySummary({
    int weekday = DateTime.sunday,
    int hour = 20,
    int minute = 0,
  }) async {
    final scheduled = _nextWeekdayTime(weekday, hour, minute);

    await _plugin.zonedSchedule(
      weeklyId,
      "EXPENSO WEEKLY SUMMARY",
      "Your weekly spending summary is ready",
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    debugPrint("Weekly scheduled: $scheduled");
  }

  /// Monthly summary reminder (example: 1st day 10:00 AM)
  Future<void> scheduleMonthlySummary({
    int day = 1,
    int hour = 10,
    int minute = 0,
  }) async {
    final scheduled = _nextMonthDayTime(day, hour, minute);

    await _plugin.zonedSchedule(
      monthlyId,
      "EXPENSO MONTHLY SUMMARY",
      "Your monthly spending summary is ready",
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
    );

    debugPrint("Monthly scheduled: $scheduled");
  }

  /// Daily streak reminder (example: every day 9:00 PM)
  Future<void> scheduleDailyStreakReminder({
    int hour = 21,
    int minute = 0,
  }) async {
    final scheduled = _nextTimeTodayOrTomorrow(hour, minute);

    await _plugin.zonedSchedule(
      streakId,
      "Keep your streak",
      "Add today’s expense now to keep your streak going!",
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("Streak scheduled: $scheduled");
  }

  /// Daily coin reminder (example: 7:30 PM)
  Future<void> scheduleDailyCoinsReminder({
    int hour = 19,
    int minute = 30,
  }) async {
    final scheduled = _nextTimeTodayOrTomorrow(hour, minute);

    await _plugin.zonedSchedule(
      coinId,
      "Daily reward",
      "Claim your daily coins in EXPENSO!",
      scheduled,
      _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );

    debugPrint("Coins scheduled: $scheduled");
  }

  // ----------------------------
  // TIME HELPERS
  // ----------------------------

  tz.TZDateTime _nextTimeTodayOrTomorrow(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextWeekdayTime(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    // Start from today
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // Move forward until correct weekday
    while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  tz.TZDateTime _nextMonthDayTime(int day, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);

    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, day, hour, minute);

    if (scheduled.isBefore(now)) {
      // next month
      final nextMonth = (now.month == 12) ? 1 : now.month + 1;
      final nextYear = (now.month == 12) ? now.year + 1 : now.year;

      scheduled =
          tz.TZDateTime(tz.local, nextYear, nextMonth, day, hour, minute);
    }

    return scheduled;
  }
}
