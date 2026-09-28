import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diaper_entry.dart';
import 'diaper_entry_form.dart';
import 'feeding_entry.dart';
import 'feeding_entry_form.dart';
import 'home_widget_sync.dart';
import 'notification_service.dart';
import 'sleep_entry.dart';
import 'sleep_entry_form.dart';

const _entriesKey = 'feeding_entries';
const _intervalKey = 'reminder_interval_minutes';
const _sleepEntriesKey = 'sleep_entries';
const _diaperEntriesKey = 'diaper_entries';
const _diaperReminderEnabledKey = 'diaper_reminder_enabled';
const _diaperIntervalKey = 'diaper_reminder_interval_minutes';
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

  final jsonString = prefs.getString(_entriesKey);
  final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
  final entries = rawEntries.map((raw) => FeedingEntry.fromJson(raw as Map<String, dynamic>)).toList()
    ..add(entry)
    ..sort((a, b) => a.time.compareTo(b.time));
  await prefs.setString(_entriesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));

  final reminderInterval = Duration(minutes: prefs.getInt(_intervalKey) ?? 180);

  await NotificationService.initialize();
  await NotificationService.cancelReminder();
  await NotificationService.scheduleFeedReminder(entry.time.add(reminderInterval));

  await syncHomeWidget(entries, reminderInterval);
}

Future<void> _persistQuickLogSleep(SleepEntry entry) async {
  final prefs = await SharedPreferences.getInstance();

  final jsonString = prefs.getString(_sleepEntriesKey);
  final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
  final entries = rawEntries.map((raw) => SleepEntry.fromJson(raw as Map<String, dynamic>)).toList()
    ..add(entry)
    ..sort((a, b) => a.start.compareTo(b.start));
  await prefs.setString(_sleepEntriesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
}

Future<void> _persistQuickLogDiaper(DiaperEntry entry) async {
  final prefs = await SharedPreferences.getInstance();

  final jsonString = prefs.getString(_diaperEntriesKey);
  final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
  final entries = rawEntries.map((raw) => DiaperEntry.fromJson(raw as Map<String, dynamic>)).toList()
    ..add(entry)
    ..sort((a, b) => a.time.compareTo(b.time));
  await prefs.setString(_diaperEntriesKey, jsonEncode(entries.map((e) => e.toJson()).toList()));

  final diaperReminderEnabled = prefs.getBool(_diaperReminderEnabledKey) ?? false;
  final diaperInterval = Duration(minutes: prefs.getInt(_diaperIntervalKey) ?? 180);

  await NotificationService.initialize();
  await NotificationService.cancelDiaperReminder();
  if (diaperReminderEnabled) {
    await NotificationService.scheduleDiaperReminder(entry.time.add(diaperInterval));
  }
}
