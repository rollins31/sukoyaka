import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'web_notification_helper.dart';

class NotificationService {
  NotificationService._();

  static const int feedReminderId = 0;
  static const int diaperReminderId = 1;
  static const String _milkChannelId = 'milk_reminder_channel';
  static const String _milkChannelName = 'Milk reminders';
  static const String _diaperChannelId = 'diaper_reminder_channel';
  static const String _diaperChannelName = 'Diaper reminders';

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static final Map<int, Timer> _webTimers = {};

  static Future<void> initialize() async {
    if (kIsWeb) {
      try {
        WebNotificationHelper.requestPermission();
        debugPrint('NotificationService initialized successfully');
        debugPrint('Notification channel created');
      } catch (e) {
        debugPrint('NotificationService.initialize() error: $e');
      }
      return;
    }

    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.local);
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
        requestBadgePermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        macOS: iosSettings,
      );

      await _plugin.initialize(settings: initSettings);
      debugPrint('NotificationService initialized successfully');

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // Create notification channels for Android
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _milkChannelId,
            _milkChannelName,
            description: 'Notifications for baby feeding reminders',
            importance: Importance.high,
          ),
        );
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _diaperChannelId,
            _diaperChannelName,
            description: 'Notifications for diaper change reminders',
            importance: Importance.high,
          ),
        );
        debugPrint('Notification channel created');

        // Request notification permissions for Android 13+
        await androidPlugin.requestNotificationsPermission();
        debugPrint('Requested Android notification permission');

        // Request exact alarm permission for Android 13+ (needed for scheduled notifications)
        await androidPlugin.requestExactAlarmsPermission();
        debugPrint('Requested Android exact alarm permission');
      }
    } catch (e) {
      debugPrint('NotificationService.initialize() error: $e');
    }
  }

  static Future<void> _schedule({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (kIsWeb) {
      try {
        _webTimers.remove(id)?.cancel();
        final now = DateTime.now();
        final difference = scheduledTime.difference(now);
        debugPrint('Scheduling reminder $id for: $scheduledTime (local: $now)');
        if (difference.isNegative) {
          debugPrint('Scheduled time is in the past, not scheduling Web timer.');
          return;
        }
        _webTimers[id] = Timer(difference, () {
          debugPrint('Web timer fired! Triggering web notification.');
          WebNotificationHelper.showNotification(title, body);
        });
        debugPrint('Reminder scheduled successfully');
      } catch (e) {
        debugPrint('_schedule() error: $e');
      }
      return;
    }

    try {
      final tzDate = tz.TZDateTime.from(scheduledTime, tz.local);
      debugPrint('Scheduling reminder $id for: $tzDate (local: ${DateTime.now()})');

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzDate,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(),
          macOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint('Reminder scheduled successfully');
    } catch (e) {
      debugPrint('_schedule() error: $e');
    }
  }

  static Future<void> cancel(int id) async {
    if (kIsWeb) {
      _webTimers.remove(id)?.cancel();
      return;
    }
    await _plugin.cancel(id: id);
  }

  static Future<void> scheduleFeedReminder(DateTime scheduledTime) => _schedule(
        id: feedReminderId,
        channelId: _milkChannelId,
        channelName: _milkChannelName,
        title: '🍼 Baby feeding reminder',
        body: 'It might be time to feed your baby!',
        scheduledTime: scheduledTime,
      );

  static Future<void> cancelReminder() => cancel(feedReminderId);

  static Future<void> scheduleDiaperReminder(DateTime scheduledTime) => _schedule(
        id: diaperReminderId,
        channelId: _diaperChannelId,
        channelName: _diaperChannelName,
        title: '👶 Diaper change reminder',
        body: 'It might be time to change your baby!',
        scheduledTime: scheduledTime,
      );

  static Future<void> cancelDiaperReminder() => cancel(diaperReminderId);
}
