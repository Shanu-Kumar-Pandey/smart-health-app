import 'package:flutter/services.dart';

class NativeAlarmService {
  static const platform = MethodChannel('com.example.healthhub/native_alarm');

  /// Schedule an exact alarm using native Android AlarmManager
  /// This bypasses flutter_local_notifications and uses AlarmManager directly
  Future<bool> scheduleExactAlarm({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      final triggerAtMillis = scheduledTime.millisecondsSinceEpoch;
      print('[NativeAlarm] Scheduling alarm ID=$id at $scheduledTime (millis: $triggerAtMillis)');
      print('[NativeAlarm] Title: $title, Body: $body');
      
      final result = await platform.invokeMethod('scheduleExactAlarm', {
        'id': id,
        'title': title,
        'body': body,
        'triggerAtMillis': triggerAtMillis,
      });
      
      print('[NativeAlarm] Alarm scheduled successfully: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[NativeAlarm] Failed to schedule alarm: ${e.message}');
      return false;
    } catch (e) {
      print('[NativeAlarm] Unexpected error: $e');
      return false;
    }
  }

  /// Cancel a scheduled alarm
  Future<bool> cancelAlarm(int id) async {
    try {
      print('[NativeAlarm] Cancelling alarm ID=$id');
      final result = await platform.invokeMethod('cancelAlarm', {'id': id});
      print('[NativeAlarm] Alarm cancelled: $result');
      return result == true;
    } on PlatformException catch (e) {
      print('[NativeAlarm] Failed to cancel alarm: ${e.message}');
      return false;
    } catch (e) {
      print('[NativeAlarm] Unexpected error: $e');
      return false;
    }
  }

  /// Schedule multiple alarms for a reminder window
  Future<void> scheduleReminderAlarms({
    required String reminderId,
    required String title,
    required String message,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    required int intervalMinutes,
  }) async {
    print('[NativeAlarm] Scheduling reminder: $title');
    print('[NativeAlarm] Window: $startHour:$startMinute to $endHour:$endMinute, interval: $intervalMinutes min');
    
    final now = DateTime.now();
    final baseId = reminderId.hashCode.abs() % 100000 + 50000; // IDs 50000-150000
    
    // Calculate all times within the window
    int startTotal = startHour * 60 + startMinute;
    int endTotal = endHour * 60 + endMinute;
    
    final List<DateTime> scheduledTimes = [];
    
    if (endTotal > startTotal) {
      int m = startTotal;
      while (m <= endTotal) {
        final h = m ~/ 60;
        final min = m % 60;
        DateTime scheduled = DateTime(now.year, now.month, now.day, h, min);
        if (scheduled.isBefore(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }
        scheduledTimes.add(scheduled);
        m += intervalMinutes;
      }
    }
    
    print('[NativeAlarm] Will schedule ${scheduledTimes.length} alarms');
    
    // Schedule each alarm
    for (int i = 0; i < scheduledTimes.length; i++) {
      final alarmId = baseId + i;
      final time = scheduledTimes[i];
      final timeUntil = time.difference(now);
      
      print('[NativeAlarm] Alarm ${i + 1}/${scheduledTimes.length}: ID=$alarmId, time=$time (in ${timeUntil.inMinutes} min)');
      
      await scheduleExactAlarm(
        id: alarmId,
        title: title,
        body: message,
        scheduledTime: time,
      );
    }
    
    print('[NativeAlarm] All alarms scheduled for: $title');
  }

  /// Cancel previously scheduled native alarms for a reminder
  Future<void> cancelReminderAlarms(String reminderId) async {
    final baseId = reminderId.hashCode.abs() % 100000 + 50000;
    // Cancel a reasonable range of possible IDs
    for (int i = 0; i < 300; i++) {
      await cancelAlarm(baseId + i);
    }
    print('[NativeAlarm] Cancelled native alarms for reminder: $reminderId');
  }
}
