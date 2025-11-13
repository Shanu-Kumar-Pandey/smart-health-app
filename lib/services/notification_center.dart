import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool read;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.read = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
      };

  static AppNotificationItem fromMap(Map<String, dynamic> map) => AppNotificationItem(
        id: map['id'] as String,
        title: map['title'] as String? ?? 'Notification',
        body: map['body'] as String? ?? '',
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
        read: map['read'] as bool? ?? false,
      );
}

class NotificationCenter {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  final ValueNotifier<List<AppNotificationItem>> notifications = ValueNotifier<List<AppNotificationItem>>([]);
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static const _storeKey = 'app_notifications_v1';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storeKey);
    if (jsonStr != null) {
      try {
        final list = (json.decode(jsonStr) as List)
            .cast<Map<String, dynamic>>()
            .map(AppNotificationItem.fromMap)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifications.value = list;
        _recalcUnread();
      } catch (_) {
        // ignore corrupted cache
      }
    }
  }

  Future<void> add({required String title, required String body, bool markUnread = true}) async {
    final item = AppNotificationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      timestamp: DateTime.now(),
      read: !markUnread,
    );
    final list = [item, ...notifications.value];
    notifications.value = list;
    _recalcUnread();
    await _persist();
  }

  Future<void> markAllRead() async {
    final list = notifications.value.map((n) => AppNotificationItem(
          id: n.id,
          title: n.title,
          body: n.body,
          timestamp: n.timestamp,
          read: true,
        )).toList();
    notifications.value = list;
    _recalcUnread();
    await _persist();
  }

  Future<void> clearAll() async {
    notifications.value = [];
    unreadCount.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storeKey);
  }

  void _recalcUnread() {
    unreadCount.value = notifications.value.where((n) => !n.read).length;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = json.encode(notifications.value.map((e) => e.toMap()).toList());
    await prefs.setString(_storeKey, jsonStr);
  }
}
