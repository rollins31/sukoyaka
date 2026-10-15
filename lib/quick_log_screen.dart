import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_keys.dart';
import 'diaper_entry.dart';
import 'diaper_entry_form.dart';
import 'feeding_entry.dart';
import 'feeding_entry_form.dart';
import 'home_widget_sync.dart';
import 'notification_service.dart';
import 'sleep_entry.dart';
import 'sleep_entry_form.dart';

const _closeChannel = MethodChannel('quick_log/close');

/// Which kind of entry the widget's quick-log popup was launched to record.
enum QuickLogType { feeding, sleep, diaper }

/// Root screen for the widget's quick-log popup. Reached via the
/// `/quickLog/<type>` routes on the app's normal `main()` entrypoint —
/// `QuickLogActivity` just launches a second engine with that initial route,
/// themed as a floating dialog rather than the full app, so this never needs
/// its own entrypoint.
class QuickLogScreen extends StatefulWidget {
  const QuickLogScreen({super.key, required this.type});

  final QuickLogType type;

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    switch (widget.type) {
      case QuickLogType.feeding:
        final entry = await showFeedingEntryForm(context);
        if (entry != null) await _persistQuickLogFeeding(entry);
      case QuickLogType.sleep:
        final entry = await showSleepEntryForm(context);
        if (entry != null) await _persistQuickLogSleep(entry);
      case QuickLogType.diaper:
        final entry = await showDiaperEntryForm(context);
        if (entry != null) await _persistQuickLogDiaper(entry);
    }
    await _closeChannel.invokeMethod('close');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}

Future<void> _persistQuickLogFeeding(FeedingEntry entry) async {
  final prefs = await SharedPreferences.getInstance();

  final jsonString = prefs.getString(StorageKeys.feedings);
  final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
  final entries = rawEntries.map((raw) => FeedingEntry.fromJson(raw as Map<String, dynamic>)).toList()
    ..add(entry)
    ..sort((a, b) => a.time.compareTo(b.time));
  await prefs.setString(StorageKeys.feedings, jsonEncode(entries.map((e) => e.toJson()).toList()));

  final feedReminderEnabled = prefs.getBool(StorageKeys.feedReminderEnabled) ?? true;
  final reminderInterval = Duration(minutes: prefs.getInt(StorageKeys.feedReminderInterval) ?? 180);

  await NotificationService.initialize();
  await NotificationService.cancelReminder();
  if (feedReminderEnabled) {
    await NotificationService.scheduleFeedReminder(entries.last.time.add(reminderInterval));
  }

  await syncHomeWidget(entries, reminderInterval, reminderEnabled: feedReminderEnabled);
}

Future<void> _persistQuickLogSleep(SleepEntry entry) async {
  final prefs = await SharedPreferences.getInstance();

  final jsonString = prefs.getString(StorageKeys.sleeps);
  final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
  final entries = rawEntries.map((raw) => SleepEntry.fromJson(raw as Map<String, dynamic>)).toList()
    ..add(entry)
    ..sort((a, b) => a.start.compareTo(b.start));
  await prefs.setString(StorageKeys.sleeps, jsonEncode(entries.map((e) => e.toJson()).toList()));
}

Future<void> _persistQuickLogDiaper(DiaperEntry entry) async {
  final prefs = await SharedPreferences.getInstance();

  final jsonString = prefs.getString(StorageKeys.diapers);
  final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
  final entries = rawEntries.map((raw) => DiaperEntry.fromJson(raw as Map<String, dynamic>)).toList()
    ..add(entry)
    ..sort((a, b) => a.time.compareTo(b.time));
  await prefs.setString(StorageKeys.diapers, jsonEncode(entries.map((e) => e.toJson()).toList()));

  final diaperReminderEnabled = prefs.getBool(StorageKeys.diaperReminderEnabled) ?? false;
  final diaperInterval = Duration(minutes: prefs.getInt(StorageKeys.diaperReminderInterval) ?? 180);

  await NotificationService.initialize();
  await NotificationService.cancelDiaperReminder();
  if (diaperReminderEnabled) {
    await NotificationService.scheduleDiaperReminder(entry.time.add(diaperInterval));
  }
}
