import 'package:flutter/material.dart';

import 'app_store.dart';
import 'diaper_entry.dart';
import 'diaper_entry_form.dart';
import 'duration_format.dart';
import 'feeding_entry.dart';
import 'feeding_entry_form.dart';
import 'growth_entry.dart';
import 'growth_entry_form.dart';
import 'sleep_entry.dart';
import 'sleep_entry_form.dart';

// Form-then-save flows shared by the Home cards, the history tabs and the
// main scaffold's floating action buttons.

void _showSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

Future<void> recordFeeding(BuildContext context, AppStore store) async {
  final entry = await showFeedingEntryForm(context);
  if (entry == null) return;
  await store.addFeeding(entry);
  if (!context.mounted) return;
  _showSnackBar(
    context,
    store.feedReminderEnabled ? 'Feeding time recorded and reminder set.' : 'Feeding time recorded',
  );
}

Future<void> editFeeding(BuildContext context, AppStore store, FeedingEntry entry) async {
  final updated = await showFeedingEntryForm(context, existingEntry: entry);
  if (updated != null) await store.updateFeeding(updated);
}

Future<void> startSleep(BuildContext context, AppStore store) async {
  if (await store.startSleep() == null) return;
  if (!context.mounted) return;
  _showSnackBar(context, 'Sleep started');
}

Future<void> stopSleep(BuildContext context, AppStore store) async {
  final stopped = await store.stopSleep();
  if (stopped == null || !context.mounted) return;
  _showSnackBar(context, 'Slept for ${formatDuration(stopped.duration!)}');
}

/// Adds a sleep session via the form (start/end pickers) rather than the
/// live timer, for logging periods after the fact.
Future<void> addSleepManually(BuildContext context, AppStore store) async {
  final entry = await showSleepEntryForm(context);
  if (entry != null) await store.addSleep(entry);
}

Future<void> editSleep(BuildContext context, AppStore store, SleepEntry entry) async {
  final updated = await showSleepEntryForm(context, existingEntry: entry);
  if (updated != null) await store.updateSleep(updated);
}

Future<void> recordDiaper(BuildContext context, AppStore store) async {
  final entry = await showDiaperEntryForm(context);
  if (entry == null) return;
  await store.addDiaper(entry);
  if (!context.mounted) return;
  _showSnackBar(context, 'Diaper change recorded');
}

Future<void> editDiaper(BuildContext context, AppStore store, DiaperEntry entry) async {
  final updated = await showDiaperEntryForm(context, existingEntry: entry);
  if (updated != null) await store.updateDiaper(updated);
}

Future<void> addGrowth(BuildContext context, AppStore store) async {
  final entry = await showGrowthEntryForm(context);
  if (entry != null) await store.addGrowth(entry);
}

Future<void> editGrowth(BuildContext context, AppStore store, GrowthEntry entry) async {
  final updated = await showGrowthEntryForm(context, existingEntry: entry);
  if (updated != null) await store.updateGrowth(updated);
}
