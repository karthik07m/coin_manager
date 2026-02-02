import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as fln;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final fln.FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      fln.FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    // Safety check: handle if getLocalTimezone returns String or Object
    final dynamic timeZoneResult = await FlutterTimezone.getLocalTimezone();
    String timeZoneName;
    if (timeZoneResult is String) {
      timeZoneName = timeZoneResult;
    } else {
      // Assuming it's TimezoneInfo or similar object with identifier
      timeZoneName = (timeZoneResult as dynamic).identifier;
    }
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const fln.AndroidInitializationSettings initializationSettingsAndroid =
        fln.AndroidInitializationSettings('@mipmap/ic_launcher');

    final fln.DarwinInitializationSettings initializationSettingsDarwin =
        fln.DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final fln.InitializationSettings initializationSettings =
        fln.InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (fln.NotificationResponse notificationResponse) async {
        // Handle notification tap
      },
    );

    // Create Android notification channel for daily reminders
    const androidChannel = fln.AndroidNotificationChannel(
      'daily_reminder_channel', // id
      'Daily Reminder', // name
      description: 'Daily reminder to log your transactions',
      importance: fln.Importance.max,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> requestPermissions() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            fln.IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            fln.MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    final fln.AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();

    // Request exact alarm permission for Android 12+ (API 31+)
    // This will open system settings if not already granted
    final bool? hasExactPermission =
        await androidImplementation?.requestExactAlarmsPermission();
    debugPrint('Exact alarm permission status: $hasExactPermission');
  }

  /// Request exact alarm permission explicitly and return the result
  /// Returns true if permission is granted, false if denied or not available
  Future<bool> requestExactAlarmPermission() async {
    final fln.AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) {
      return true; // Not Android, assume granted
    }

    try {
      // First check if we already have permission
      final bool? canSchedule =
          await androidImplementation.canScheduleExactNotifications();

      if (canSchedule == true) {
        debugPrint('Exact alarm permission already granted');
        return true;
      }

      // Request permission - this opens system settings
      debugPrint('Requesting exact alarm permission...');
      final bool? granted =
          await androidImplementation.requestExactAlarmsPermission();
      debugPrint('Exact alarm permission request result: $granted');

      return granted ?? false;
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
      return false;
    }
  }

  /// Check if exact alarms are permitted (for Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    final fln.AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            fln.AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) {
      return true; // Not Android, assume permission granted
    }

    try {
      final bool? canSchedule =
          await androidImplementation.canScheduleExactNotifications();
      return canSchedule ?? false;
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return false;
    }
  }

  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      // Check if we can schedule exact alarms
      final bool canScheduleExact = await canScheduleExactAlarms();

      // Use exact mode if permitted, otherwise fall back to inexact
      final fln.AndroidScheduleMode scheduleMode = canScheduleExact
          ? fln.AndroidScheduleMode.exactAllowWhileIdle
          : fln.AndroidScheduleMode.inexactAllowWhileIdle;

      final scheduledTime = _nextInstanceOfTime(hour, minute);
      debugPrint('Scheduling notification with mode: $scheduleMode');
      debugPrint(
          'Scheduled for: $scheduledTime (${scheduledTime.timeZoneName})');

      await flutterLocalNotificationsPlugin.zonedSchedule(
        0, // ID
        'Daily Reminder',
        'Don\'t forget to log your transactions for today!',
        scheduledTime,
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'daily_reminder_channel',
            'Daily Reminder',
            channelDescription: 'Daily reminder to log transactions',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
          ),
          iOS: fln.DarwinNotificationDetails(),
          macOS: fln.DarwinNotificationDetails(),
        ),
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: fln.DateTimeComponents.time,
      );

      debugPrint(
          'Notification scheduled successfully for ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}');
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Show an immediate test notification to verify notifications are working
  Future<void> showTestNotification() async {
    try {
      debugPrint('Showing test notification...');
      await flutterLocalNotificationsPlugin.show(
        9999,
        '✅ Test Notification',
        'If you see this, notifications are working correctly!',
        const fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'daily_reminder_channel', // Use the same channel we already created
            'Daily Reminder',
            channelDescription: 'Daily reminder to log transactions',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: fln.DarwinNotificationDetails(),
          macOS: fln.DarwinNotificationDetails(),
        ),
      );
      debugPrint('Test notification shown successfully');
    } catch (e) {
      debugPrint('Error showing test notification: $e');
    }
  }

  /// Get details about the next scheduled notification
  Future<String> getNextScheduledNotificationInfo() async {
    try {
      final pendingNotifications =
          await flutterLocalNotificationsPlugin.pendingNotificationRequests();

      if (pendingNotifications.isEmpty) {
        return 'No notifications scheduled';
      }

      return 'You have ${pendingNotifications.length} notification(s) scheduled';
    } catch (e) {
      debugPrint('Error getting pending notifications: $e');
      return 'Unable to check scheduled notifications';
    }
  }

  Future<void> cancelDailyReminder() async {
    await flutterLocalNotificationsPlugin.cancel(0);
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
