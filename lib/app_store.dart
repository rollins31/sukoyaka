import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_keys.dart';
import 'backup_data.dart';
import 'diaper_entry.dart';
import 'entry_storage.dart';
import 'feeding_entry.dart';
import 'growth_entry.dart';
import 'home_widget_sync.dart';
import 'notification_service.dart';
import 'sleep_entry.dart';
import 'timestamped_entry.dart';

/// Every log and reminder setting, plus their persistence.
///
/// Each mutation updates memory and notifies listeners first, so the UI
/// reacts immediately, then saves and refreshes whatever depends on that
/// data: the feed or diaper reminder, and the home-screen widget (which only
/// shows feedings). Lists are kept sorted oldest first.
///
/// Used both by the main app and by the widget's quick-log popup, which runs
/// in a separate engine, so the two always agree on storage and reminders.
class AppStore extends ChangeNotifier {
  final List<FeedingEntry> _feedings = [];
  final List<SleepEntry> _sleeps = [];
  final List<DiaperEntry> _diapers = [];
  final List<GrowthEntry> _growth = [];
  bool _feedReminderEnabled = true;
  Duration _feedReminderInterval = const Duration(hours: 3);
  bool _diaperReminderEnabled = false;
  Duration _diaperReminderInterval = const Duration(hours: 3);

  UnmodifiableListView<FeedingEntry> get feedings => UnmodifiableListView(_feedings);
  UnmodifiableListView<SleepEntry> get sleeps => UnmodifiableListView(_sleeps);
  UnmodifiableListView<DiaperEntry> get diapers => UnmodifiableListView(_diapers);
  UnmodifiableListView<GrowthEntry> get growth => UnmodifiableListView(_growth);
  bool get feedReminderEnabled => _feedReminderEnabled;
  Duration get feedReminderInterval => _feedReminderInterval;
  bool get diaperReminderEnabled => _diaperReminderEnabled;
  Duration get diaperReminderInterval => _diaperReminderInterval;

  /// The sleep session currently in progress, if any.
  SleepEntry? get activeSleep {
    for (final entry in _sleeps) {
      if (entry.isInProgress) return entry;
    }
    return null;
  }

  /// Replaces everything in memory with what's saved. Doesn't touch
  /// reminders or the widget; see [syncReminders].
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    // getInstance() memoizes its cache for the isolate's lifetime, so
    // without this, data written by the widget's separate engine (while
    // this app sat backgrounded, never killed) would stay invisible until
    // the process actually restarted.
    await prefs.reload();
    _replace(_feedings, readEntries(prefs, StorageKeys.feedings, FeedingEntry.fromJson));
    _replace(_sleeps, readEntries(prefs, StorageKeys.sleeps, SleepEntry.fromJson));
    _replace(_diapers, readEntries(prefs, StorageKeys.diapers, DiaperEntry.fromJson));
    _replace(_growth, readEntries(prefs, StorageKeys.growth, GrowthEntry.fromJson));
    _sortAll();
    _feedReminderEnabled = prefs.getBool(StorageKeys.feedReminderEnabled) ?? true;
    _feedReminderInterval = Duration(minutes: prefs.getInt(StorageKeys.feedReminderInterval) ?? 180);
    _diaperReminderEnabled = prefs.getBool(StorageKeys.diaperReminderEnabled) ?? false;
    _diaperReminderInterval = Duration(minutes: prefs.getInt(StorageKeys.diaperReminderInterval) ?? 180);
    notifyListeners();
  }

  /// Reschedules both reminders and refreshes the widget from current data.
  Future<void> syncReminders() async {
    await _rescheduleFeedReminder();
    await _rescheduleDiaperReminder();
    await _syncWidget();
  }

  /// Everything [restore] would need to bring this data back.
  AppBackup toBackup() => AppBackup(
        exportedAt: DateTime.now(),
        feedings: List.of(_feedings),
        sleepEntries: List.of(_sleeps),
        diaperEntries: List.of(_diapers),
        growthEntries: List.of(_growth),
        feedReminderEnabled: _feedReminderEnabled,
        reminderIntervalMinutes: _feedReminderInterval.inMinutes,
        diaperReminderEnabled: _diaperReminderEnabled,
        diaperReminderIntervalMinutes: _diaperReminderInterval.inMinutes,
      );

  /// Replaces all data with the contents of [backup] and persists it.
  Future<void> restore(AppBackup backup) async {
    _replace(_feedings, backup.feedings);
    _replace(_sleeps, backup.sleepEntries);
    _replace(_diapers, backup.diaperEntries);
    _replace(_growth, backup.growthEntries);
    _sortAll();
    _feedReminderEnabled = backup.feedReminderEnabled;
    _feedReminderInterval = Duration(minutes: backup.reminderIntervalMinutes);
    _diaperReminderEnabled = backup.diaperReminderEnabled;
    _diaperReminderInterval = Duration(minutes: backup.diaperReminderIntervalMinutes);
    notifyListeners();
    await _saveFeedings();
    await _saveSleeps();
    await _saveDiapers();
    await _saveGrowth();
    await _saveFeedReminderSettings();
    await _saveDiaperReminderSettings();
    await syncReminders();
  }

  // Feedings

  Future<void> addFeeding(FeedingEntry entry) => _feedingsChanged(() => _feedings.add(entry));

  /// Replaces the feeding with [entry]'s id.
  Future<void> updateFeeding(FeedingEntry entry) =>
      _feedingsChanged(() => _swap(_feedings, entry, (e) => e.id));

  Future<void> deleteFeeding(FeedingEntry entry) =>
      _feedingsChanged(() => _feedings.removeWhere((e) => e.id == entry.id));

  /// Updates the feed reminder; arguments left null keep their value.
  Future<void> setFeedReminder({bool? enabled, Duration? interval}) async {
    _feedReminderEnabled = enabled ?? _feedReminderEnabled;
    _feedReminderInterval = interval ?? _feedReminderInterval;
    notifyListeners();
    await _saveFeedReminderSettings();
    await _rescheduleFeedReminder();
    await _syncWidget();
  }

  Future<void> _feedingsChanged(void Function() change) async {
    change();
    _sortByTime(_feedings);
    notifyListeners();
    await _saveFeedings();
    await _rescheduleFeedReminder();
    await _syncWidget();
  }

  // Sleep

  /// Starts a live sleep session now. Returns null, changing nothing, if one
  /// is already running.
  Future<SleepEntry?> startSleep() async {
    if (activeSleep != null) return null;
    final now = DateTime.now();
    final entry = SleepEntry(id: now.millisecondsSinceEpoch, start: now);
    await addSleep(entry);
    return entry;
  }

  /// Ends the running sleep session now and returns it, or null if none was
  /// running.
  Future<SleepEntry?> stopSleep() async {
    final active = activeSleep;
    if (active == null) return null;
    await _sleepsChanged(() => active.end = DateTime.now());
    return active;
  }

  Future<void> addSleep(SleepEntry entry) => _sleepsChanged(() => _sleeps.add(entry));

  /// Replaces the sleep session with [entry]'s id.
  Future<void> updateSleep(SleepEntry entry) => _sleepsChanged(() => _swap(_sleeps, entry, (e) => e.id));

  Future<void> deleteSleep(SleepEntry entry) =>
      _sleepsChanged(() => _sleeps.removeWhere((e) => e.id == entry.id));

  Future<void> _sleepsChanged(void Function() change) async {
    change();
    _sortSleeps(_sleeps);
    notifyListeners();
    await _saveSleeps();
  }

  // Diapers

  Future<void> addDiaper(DiaperEntry entry) => _diapersChanged(() => _diapers.add(entry));

  /// Replaces the diaper change with [entry]'s id.
  Future<void> updateDiaper(DiaperEntry entry) => _diapersChanged(() => _swap(_diapers, entry, (e) => e.id));

  Future<void> deleteDiaper(DiaperEntry entry) =>
      _diapersChanged(() => _diapers.removeWhere((e) => e.id == entry.id));

  /// Updates the diaper reminder; arguments left null keep their value.
  Future<void> setDiaperReminder({bool? enabled, Duration? interval}) async {
    _diaperReminderEnabled = enabled ?? _diaperReminderEnabled;
    _diaperReminderInterval = interval ?? _diaperReminderInterval;
    notifyListeners();
    await _saveDiaperReminderSettings();
    await _rescheduleDiaperReminder();
  }

  Future<void> _diapersChanged(void Function() change) async {
    change();
    _sortByTime(_diapers);
    notifyListeners();
    await _saveDiapers();
    await _rescheduleDiaperReminder();
  }

  // Growth

  Future<void> addGrowth(GrowthEntry entry) => _growthChanged(() => _growth.add(entry));

  /// Replaces the measurement with [entry]'s id.
  Future<void> updateGrowth(GrowthEntry entry) => _growthChanged(() => _swap(_growth, entry, (e) => e.id));

  Future<void> deleteGrowth(GrowthEntry entry) =>
      _growthChanged(() => _growth.removeWhere((e) => e.id == entry.id));

  Future<void> _growthChanged(void Function() change) async {
    change();
    _sortByTime(_growth);
    notifyListeners();
    await _saveGrowth();
  }

  // Persistence and side effects

  void _sortAll() {
    _sortByTime(_feedings);
    _sortSleeps(_sleeps);
    _sortByTime(_diapers);
    _sortByTime(_growth);
  }

  Future<void> _saveFeedings() async =>
      writeEntries(await SharedPreferences.getInstance(), StorageKeys.feedings, _feedings.map((e) => e.toJson()));

  Future<void> _saveSleeps() async =>
      writeEntries(await SharedPreferences.getInstance(), StorageKeys.sleeps, _sleeps.map((e) => e.toJson()));

  Future<void> _saveDiapers() async =>
      writeEntries(await SharedPreferences.getInstance(), StorageKeys.diapers, _diapers.map((e) => e.toJson()));

  Future<void> _saveGrowth() async =>
      writeEntries(await SharedPreferences.getInstance(), StorageKeys.growth, _growth.map((e) => e.toJson()));

  Future<void> _saveFeedReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.feedReminderEnabled, _feedReminderEnabled);
    await prefs.setInt(StorageKeys.feedReminderInterval, _feedReminderInterval.inMinutes);
  }

  Future<void> _saveDiaperReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.diaperReminderEnabled, _diaperReminderEnabled);
    await prefs.setInt(StorageKeys.diaperReminderInterval, _diaperReminderInterval.inMinutes);
  }

  /// Cancels any pending feed reminder, then reschedules it from the last
  /// feeding's time — but only if the user has turned the reminder on.
  Future<void> _rescheduleFeedReminder() async {
    await NotificationService.cancelReminder();
    if (_feedReminderEnabled && _feedings.isNotEmpty) {
      await NotificationService.scheduleFeedReminder(_feedings.last.time.add(_feedReminderInterval));
    }
  }

  /// Cancels any pending diaper reminder, then reschedules it from the last
  /// diaper change's time — but only if the user has turned the reminder on.
  Future<void> _rescheduleDiaperReminder() async {
    await NotificationService.cancelDiaperReminder();
    if (_diaperReminderEnabled && _diapers.isNotEmpty) {
      await NotificationService.scheduleDiaperReminder(_diapers.last.time.add(_diaperReminderInterval));
    }
  }

  Future<void> _syncWidget() =>
      syncHomeWidget(_feedings, _feedReminderInterval, reminderEnabled: _feedReminderEnabled);
}

void _replace<T>(List<T> list, Iterable<T> contents) => list
  ..clear()
  ..addAll(contents);

void _sortByTime(List<TimestampedEntry> entries) => entries.sort((a, b) => a.time.compareTo(b.time));

void _sortSleeps(List<SleepEntry> sleeps) => sleeps.sort((a, b) => a.start.compareTo(b.start));

void _swap<T>(List<T> list, T entry, int Function(T) idOf) {
  final index = list.indexWhere((e) => idOf(e) == idOf(entry));
  if (index != -1) list[index] = entry;
}
