import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'feeding_entry.dart';
import 'feeding_entry_form.dart';
import 'home_widget_sync.dart';
import 'main.dart' show NotificationService;

const _entriesKey = 'feeding_entries';
const _intervalKey = 'reminder_interval_minutes';
const _closeChannel = MethodChannel('quick_log/close');

/// Root screen for the widget's "+ Log" popup. Reached via the `/quickLog`
/// route on the app's normal `main()` entrypoint — `QuickLogActivity` just
/// launches a second engine with that initial route, themed as a floating
/// dialog rather than the full app, so this never needs its own entrypoint.
class QuickLogScreen extends StatefulWidget {
  const QuickLogScreen({super.key});

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
    final entry = await showFeedingEntryForm(context);
    if (entry != null) {
      await _persistQuickLogEntry(entry);
    }
    await _closeChannel.invokeMethod('close');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}

Future<void> _persistQuickLogEntry(FeedingEntry entry) async {
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
