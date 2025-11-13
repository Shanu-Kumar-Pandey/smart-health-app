import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      print('[NotificationService] Already initialized');
      return;
    }

    print('[NotificationService] Starting initialization...');

    // Initialize timezone database
    tz.initializeTimeZones();
    
    // Force set to Asia/Kolkata (India timezone) to fix scheduling issues
    try {
      final location = tz.getLocation('Asia/Kolkata');
      tz.setLocalLocation(location);
      print('[NotificationService] Timezone set to: Asia/Kolkata');
    } catch (e) {
      print('[NotificationService] Failed to set Asia/Kolkata, using system default');
      final String timeZoneName = tz.local.name;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      print('[NotificationService] Timezone set to: $timeZoneName');
    }
    
    // Verify timezone is correct
    final nowTZ = tz.TZDateTime.now(tz.local);
    final nowLocal = DateTime.now();
    print('[NotificationService] Local time: $nowLocal');
    print('[NotificationService] TZ time: $nowTZ');
    print('[NotificationService] Offset: ${nowTZ.timeZoneOffset}');

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('[NotificationService] Notification tapped: ${response.payload}');
      },
    );
    print('[NotificationService] Plugin initialized');

    // Android 13+ notification permission
    if (Platform.isAndroid) {
      final granted = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      print('[NotificationService] Android notification permission granted: $granted');
    }

    // For good measure also use permission_handler
    final status = await Permission.notification.request();
    print('[NotificationService] Permission handler status: ${status.name}');
    if (!status.isGranted) {
      print('[NotificationService] WARNING: Notification permission not granted!');
    }

    // Request schedule exact alarm permission (Android 12+, critical for Realme/Oppo)
    if (Platform.isAndroid) {
      try {
        final scheduleStatus = await Permission.scheduleExactAlarm.request();
        print('[NotificationService] Schedule exact alarm permission: ${scheduleStatus.name}');
        if (!scheduleStatus.isGranted) {
          print('[NotificationService] WARNING: Exact alarm permission not granted! Notifications may not fire on time.');
          print('[NotificationService] Please enable "Alarms & reminders" permission in Settings > Apps > This App > Permissions');
        }
      } catch (e) {
        print('[NotificationService] Could not request exact alarm permission: $e');
      }
    }

    // Create a default channel for hydration reminders
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'hydration_channel',
      'Hydration Reminders',
      description: 'Reminders to drink water throughout the day',
      importance: Importance.high,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    print('[NotificationService] Notification channel created: hydration_channel');

    _initialized = true;
    print('[NotificationService] Initialization complete');
  }

  // Show an immediate local notification (useful for tests and FCM foreground)
  Future<void> showInstantNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    print('[NotificationService] Showing instant notification: $title');

    const androidDetails = AndroidNotificationDetails(
      'hydration_channel',
      'Hydration Reminders',
      channelDescription: 'Reminders to drink water throughout the day',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      9000, // fixed id for test/foreground notifications
      title,
      body,
      details,
    );
    print('[NotificationService] Instant notification shown (ID: 9000)');
  }

  // Get list of pending notifications for debugging
  Future<void> debugPendingNotifications() async {
    final pending = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
    print('[NotificationService] ===== PENDING NOTIFICATIONS =====');
    print('[NotificationService] Total pending: ${pending.length}');
    for (final notification in pending) {
      print('[NotificationService] - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}');
    }
    print('[NotificationService] ===================================');
  }

  // Cancel previously scheduled hydration reminders
  Future<void> cancelHydrationReminders() async {
    // Use a reserved id range for hydration reminders (e.g., 8000-8010)
    for (int id = 8000; id <= 8010; id++) {
      await _flutterLocalNotificationsPlugin.cancel(id);
    }
  }

  int _baseIdFor(String reminderId) {
    // Deterministic positive base id
    final h = reminderId.hashCode & 0x7FFFFFFF;
    return 4000 + (h % 3000); // 4000-6999 range
  }

  // Schedule reminders every 2 hours between 08:00 and 20:00 daily
  Future<void> scheduleDailyHydrationReminders() async {
    await initialize();
    await cancelHydrationReminders();

    final List<int> hours = [8, 10, 12, 14, 16, 18, 20];

    const androidDetails = AndroidNotificationDetails(
      'hydration_channel',
      'Hydration Reminders',
      channelDescription: 'Reminders to drink water throughout the day',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final now = tz.TZDateTime.now(tz.local);

    for (int i = 0; i < hours.length; i++) {
      final int hour = hours[i];
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        0,
      );

      // If time today already passed, schedule for tomorrow
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        8000 + i,
        'Hydration Reminder',
        'Drink water and stay hydrated.',
        scheduled,
        notificationDetails,
        // Use inexact mode to avoid requiring SCHEDULE_EXACT_ALARM permission
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Schedule hydration reminders within a custom time window at a fixed interval (minutes).
  // Times are local. If end time is before start time, the window wraps past midnight.
  Future<void> scheduleHydrationWindowed({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int intervalMinutes,
  }) async {
    await initialize();
    await cancelHydrationReminders();

    const androidDetails = AndroidNotificationDetails(
      'hydration_channel',
      'Hydration Reminders',
      channelDescription: 'Reminders to drink water throughout the day',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final now = tz.TZDateTime.now(tz.local);

    int startTotal = startHour * 60 + startMinute;
    int endTotal = endHour * 60 + endMinute;
    final int step = intervalMinutes.clamp(1, 24 * 60);

    // Build list of times (HH:mm) within the window, stepping by interval
    final List<int> minutesOfDay = [];
    if (startTotal == endTotal) {
      // Single time
      minutesOfDay.add(startTotal);
    } else if (endTotal > startTotal) {
      int m = startTotal;
      int guard = 0;
      while (m <= endTotal && guard < 2000) {
        minutesOfDay.add(m);
        m += step;
        guard++;
      }
    } else {
      // Wrap past midnight: start..1439, then 0..end
      int m = startTotal;
      int guard = 0;
      while (m < 24 * 60 && guard < 2000) {
        minutesOfDay.add(m);
        m += step;
        guard++;
      }
      m = m % (24 * 60); // continue from wrapped minute
      while (true) {
        if (minutesOfDay.contains(m)) break; // safety
        if (m > endTotal) break;
        minutesOfDay.add(m);
        m += step;
        if (minutesOfDay.length > 2000) break; // safety
      }
    }

    // Schedule each time daily
    for (int i = 0; i < minutesOfDay.length; i++) {
      final total = minutesOfDay[i];
      final h = total ~/ 60;
      final min = total % 60;
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        h,
        min,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        8000 + i,
        'Hydration Reminder',
        'Drink water and stay hydrated.',
        scheduled,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexact,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  // Generic: schedule a reminder by id and title within a window
  Future<void> scheduleReminderWindowed({
    required String reminderId,
    required String title,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int intervalMinutes,
  }) async {
    await initialize();
    await cancelReminder(reminderId);

    const androidDetails = AndroidNotificationDetails(
      'hydration_channel', // reuse same channel
      'Hydration Reminders',
      channelDescription: 'Reminders to drink water throughout the day',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    final base = _baseIdFor(reminderId);

    int startTotal = startHour * 60 + startMinute;
    int endTotal = endHour * 60 + endMinute;
    final int step = intervalMinutes.clamp(1, 24 * 60);

    final List<int> minutesOfDay = [];
    if (startTotal == endTotal) {
      minutesOfDay.add(startTotal);
    } else if (endTotal > startTotal) {
      int m = startTotal;
      int guard = 0;
      while (m <= endTotal && guard < 2000) {
        minutesOfDay.add(m);
        m += step;
        guard++;
      }
    } else {
      int m = startTotal;
      int guard = 0;
      while (m < 24 * 60 && guard < 2000) {
        minutesOfDay.add(m);
        m += step;
        guard++;
      }
      m = m % (24 * 60);
      while (true) {
        if (minutesOfDay.contains(m)) break;
        if (m > endTotal) break;
        minutesOfDay.add(m);
        m += step;
        if (minutesOfDay.length > 2000) break;
      }
    }

    final nowLocal = DateTime.now();
    print('[NotificationService] Current local time: $nowLocal');
    print('[NotificationService] Current TZ time: ${tz.TZDateTime.now(tz.local)}');
    print('[NotificationService] Scheduling ${minutesOfDay.length} notifications for reminder: $title');
    
    for (int i = 0; i < minutesOfDay.length; i++) {
      final total = minutesOfDay[i];
      final h = total ~/ 60;
      final min = total % 60;
      tz.TZDateTime scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        h,
        min,
      );
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
        print('[NotificationService]   -> Time already passed, scheduling for tomorrow');
      }

      // Use exactAllowWhileIdle for short intervals (testing) to ensure delivery
      final scheduleMode = (intervalMinutes <= 15) 
          ? AndroidScheduleMode.exactAllowWhileIdle 
          : AndroidScheduleMode.inexact;

      final timeUntil = scheduled.difference(now);
      print('[NotificationService] Scheduling notification ${i + 1}/${minutesOfDay.length} at ${scheduled.toString()} (ID: ${base + i}, mode: $scheduleMode, in ${timeUntil.inMinutes} minutes)');

      try {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          base + i,
          title,
          'It\'s time!',
          scheduled,
          notificationDetails,
          androidScheduleMode: scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
        print('[NotificationService]   -> Successfully scheduled notification ID: ${base + i}');
      } catch (e) {
        print('[NotificationService]   -> ERROR scheduling notification: $e');
      }
    }
    
    print('[NotificationService] Successfully scheduled all notifications for: $title');
    
    // Debug: Show pending notifications
    await debugPendingNotifications();
  }

  Future<void> cancelReminder(String reminderId) async {
    final base = _baseIdFor(reminderId);
    for (int i = 0; i < 500; i++) { // cancel a reasonable range
      await _flutterLocalNotificationsPlugin.cancel(base + i);
    }
  }
}
