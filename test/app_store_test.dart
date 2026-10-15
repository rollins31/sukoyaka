import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukoyaka/app_storage_keys.dart';
import 'package:sukoyaka/app_store.dart';
import 'package:sukoyaka/backup_data.dart';
import 'package:sukoyaka/diaper_entry.dart';
import 'package:sukoyaka/feeding_entry.dart';
import 'package:sukoyaka/growth_entry.dart';
import 'package:sukoyaka/sleep_entry.dart';

FeedingEntry feedingAt(int id, DateTime time) =>
    FeedingEntry(id: id, time: time, milkType: 'Bottle', amount: null, amountUnit: 'ml', notes: '');

/// The ids saved under [key], in storage order.
Future<List<int>> storedIds(String key) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = jsonDecode(prefs.getString(key) ?? '[]') as List<dynamic>;
  return [for (final e in raw) (e as Map<String, dynamic>)['id'] as int];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('load reads saved logs and settings, sorted oldest first', () async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.feedings: jsonEncode([
        feedingAt(2, DateTime(2026, 10, 2)).toJson(),
        feedingAt(1, DateTime(2026, 10, 1)).toJson(),
      ]),
      StorageKeys.feedReminderEnabled: false,
      StorageKeys.feedReminderInterval: 150,
      StorageKeys.diaperReminderEnabled: true,
    });

    final store = AppStore();
    await store.load();

    expect(store.feedings.map((e) => e.id), [1, 2]);
    expect(store.feedReminderEnabled, isFalse);
    expect(store.feedReminderInterval, const Duration(minutes: 150));
    expect(store.diaperReminderEnabled, isTrue);
    expect(store.diaperReminderInterval, const Duration(hours: 3));
  });

  test('defaults when nothing is saved', () async {
    final store = AppStore();
    await store.load();

    expect(store.feedings, isEmpty);
    expect(store.feedReminderEnabled, isTrue);
    expect(store.diaperReminderEnabled, isFalse);
  });

  test('add, update and delete persist and keep the list sorted', () async {
    final store = AppStore();
    var notifications = 0;
    store.addListener(() => notifications++);

    await store.addFeeding(feedingAt(1, DateTime(2026, 10, 3)));
    await store.addFeeding(feedingAt(2, DateTime(2026, 10, 1)));
    expect(await storedIds(StorageKeys.feedings), [2, 1]);

    // Moving entry 2 later reorders it.
    await store.updateFeeding(feedingAt(2, DateTime(2026, 10, 5)));
    expect(store.feedings.map((e) => e.id), [1, 2]);
    expect(store.feedings.last.time, DateTime(2026, 10, 5));
    expect(await storedIds(StorageKeys.feedings), [1, 2]);

    await store.deleteFeeding(store.feedings.first);
    expect(await storedIds(StorageKeys.feedings), [2]);
    expect(notifications, 4);
  });

  test('diaper and growth changes persist under their own keys', () async {
    final store = AppStore();
    await store.addDiaper(DiaperEntry(id: 7, time: DateTime(2026, 10, 1), pee: true, poo: false));
    await store.addGrowth(GrowthEntry(
      id: 8,
      time: DateTime(2026, 10, 1),
      weight: 6.5,
      weightUnit: 'kg',
      height: null,
      heightUnit: 'cm',
      notes: '',
    ));

    expect(await storedIds(StorageKeys.diapers), [7]);
    expect(await storedIds(StorageKeys.growth), [8]);
  });

  test('only one live sleep runs at a time, and stopping ends it', () async {
    final store = AppStore();

    final started = await store.startSleep();
    expect(started, isNotNull);
    expect(await store.startSleep(), isNull);
    expect(store.activeSleep, same(started));

    final stopped = await store.stopSleep();
    expect(stopped?.end, isNotNull);
    expect(store.activeSleep, isNull);
    expect(await store.stopSleep(), isNull);
    expect(await storedIds(StorageKeys.sleeps), [started!.id]);
  });

  test('reminder settings persist, keeping whichever value was not passed', () async {
    final store = AppStore();

    await store.setFeedReminder(interval: const Duration(minutes: 90));
    await store.setDiaperReminder(enabled: true);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(StorageKeys.feedReminderInterval), 90);
    expect(prefs.getBool(StorageKeys.feedReminderEnabled), isTrue);
    expect(prefs.getBool(StorageKeys.diaperReminderEnabled), isTrue);
    expect(prefs.getInt(StorageKeys.diaperReminderInterval), 180);
  });

  test('restore replaces everything and saves it', () async {
    final store = AppStore();
    await store.addFeeding(feedingAt(1, DateTime(2026, 10, 1)));

    await store.restore(AppBackup(
      exportedAt: DateTime(2026, 10, 10),
      feedings: [feedingAt(4, DateTime(2026, 9, 2)), feedingAt(3, DateTime(2026, 9, 1))],
      sleepEntries: [SleepEntry(id: 5, start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 1, 2))],
      diaperEntries: const [],
      growthEntries: const [],
      feedReminderEnabled: false,
      reminderIntervalMinutes: 120,
      diaperReminderEnabled: true,
      diaperReminderIntervalMinutes: 60,
    ));

    expect(store.feedings.map((e) => e.id), [3, 4]);
    expect(store.feedReminderEnabled, isFalse);
    expect(store.diaperReminderInterval, const Duration(hours: 1));

    final reloaded = AppStore();
    await reloaded.load();
    expect(reloaded.feedings.map((e) => e.id), [3, 4]);
    expect(reloaded.sleeps.map((e) => e.id), [5]);
    expect(reloaded.feedReminderInterval, const Duration(hours: 2));
  });

  test('toBackup captures everything restore needs', () async {
    final store = AppStore();
    await store.addFeeding(feedingAt(1, DateTime(2026, 10, 1)));
    await store.setDiaperReminder(enabled: true, interval: const Duration(minutes: 45));

    final backup = store.toBackup();
    await store.deleteFeeding(store.feedings.single);

    // The backup is a snapshot, unaffected by later changes.
    expect(backup.feedings.map((e) => e.id), [1]);
    expect(backup.diaperReminderEnabled, isTrue);
    expect(backup.diaperReminderIntervalMinutes, 45);

    await store.restore(backup);
    expect(store.feedings.map((e) => e.id), [1]);
  });
}
