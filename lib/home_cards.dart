import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_store.dart';
import 'duration_format.dart';
import 'entry_actions.dart';
import 'feeding_filters.dart';
import 'section_title.dart';
import 'sleep_ticker.dart';

TextStyle? _bodyStyle(BuildContext context) => Theme.of(context).textTheme.bodyLarge;

TextStyle? _mutedStyle(BuildContext context) =>
    _bodyStyle(context)?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

/// Hours/minutes picker dialog shared by the feed and diaper reminder
/// intervals. Returns null if the user cancels or enters under a minute.
Future<Duration?> _pickInterval(BuildContext context, {required String title, required Duration current}) async {
  final hoursController = TextEditingController(text: current.inHours.toString());
  final minutesController = TextEditingController(text: (current.inMinutes % 60).toString());

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: hoursController,
              decoration: const InputDecoration(labelText: 'Hours'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minutesController,
              decoration: const InputDecoration(labelText: 'Minutes'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      );
    },
  );

  if (result != true) return null;
  final hours = int.tryParse(hoursController.text) ?? 0;
  final minutes = int.tryParse(minutesController.text) ?? 0;
  final newDuration = Duration(hours: hours, minutes: minutes);
  if (newDuration.inMinutes < 1) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interval must be at least 1 minute.')),
      );
    }
    return null;
  }
  return newDuration;
}

/// The "Remind me" switch, interval row and next-reminder time shared by the
/// feeding and diaper cards.
class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.title,
    required this.enabled,
    required this.interval,
    required this.next,
    required this.noNextMessage,
    required this.dialogTitle,
    required this.onChanged,
  });

  final String title;
  final bool enabled;
  final Duration interval;
  final DateTime? next;
  final String noNextMessage;
  final String dialogTitle;
  final Future<void> Function({bool? enabled, Duration? interval}) onChanged;

  @override
  Widget build(BuildContext context) {
    final next = this.next;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(Icons.schedule, title),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me'),
          value: enabled,
          onChanged: (enabled) => onChanged(enabled: enabled),
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(formatInterval(interval), style: _bodyStyle(context))),
              TextButton(
                onPressed: () async {
                  final picked = await _pickInterval(context, title: dialogTitle, current: interval);
                  if (picked != null) await onChanged(interval: picked);
                },
                child: const Text('Change'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const SectionTitle(Icons.notifications, 'Next reminder'),
          const SizedBox(height: 12),
          Text(next == null ? noNextMessage : formatDateTime(next), style: _mutedStyle(context)),
        ],
      ],
    );
  }
}

final _bigButtonStyle = ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18));

class FeedingSummaryCard extends StatelessWidget {
  const FeedingSummaryCard({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final lastEntry = store.feedings.isEmpty ? null : store.feedings.last;
    final lastFeed = lastEntry?.time;

    return SectionCard(
      children: [
        const SectionTitle(Icons.local_drink, 'Feeding'),
        const SizedBox(height: 12),
        Text(
          lastFeed == null ? 'No feeding recorded yet' : 'Last feeding: ${formatDateTime(lastFeed)}',
          style: _mutedStyle(context),
        ),
        if (lastEntry != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Milk type: ${lastEntry.milkType}', style: _bodyStyle(context)),
                    if (lastEntry.amount != null)
                      Text('Amount: ${lastEntry.amount} ${lastEntry.amountUnit}', style: _bodyStyle(context)),
                    if (lastEntry.notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Notes:', style: _bodyStyle(context)?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(lastEntry.notes, style: _mutedStyle(context)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit last feeding',
                onPressed: () => editFeeding(context, store, lastEntry),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _ReminderSection(
          title: 'Feeding reminder',
          enabled: store.feedReminderEnabled,
          interval: store.feedReminderInterval,
          next: lastFeed?.add(store.feedReminderInterval),
          noNextMessage: 'Record a feeding to set the next reminder',
          dialogTitle: 'Set reminder interval',
          onChanged: store.setFeedReminder,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => recordFeeding(context, store),
          icon: const Icon(Icons.local_cafe),
          label: const Text('Mark feeding now'),
          style: _bigButtonStyle,
        ),
      ],
    );
  }
}

class SleepCard extends StatelessWidget {
  const SleepCard({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.activeSleep;
    final finished = store.sleeps.where((e) => !e.isInProgress).toList();
    final lastFinished = finished.isEmpty ? null : finished.last;

    return SectionCard(
      children: [
        const SectionTitle(Icons.bedtime, 'Sleep'),
        const SizedBox(height: 12),
        if (active != null) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sleeping since ${formatDateTime(active.start)}', style: _mutedStyle(context)),
                    const SizedBox(height: 8),
                    SleepTicker(
                      active: true,
                      builder: (context) => Text(
                        formatDuration(DateTime.now().difference(active.start)),
                        style: GoogleFonts.baloo2(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit current sleep',
                onPressed: () => editSleep(context, store, active),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => stopSleep(context, store),
            icon: const Icon(Icons.wb_sunny),
            label: const Text('Wake up'),
            style: _bigButtonStyle,
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  lastFinished == null
                      ? 'No sleep recorded yet'
                      : 'Last slept ${formatDuration(lastFinished.duration!)} '
                          '(ended ${formatDateTime(lastFinished.end!)})',
                  style: _mutedStyle(context),
                ),
              ),
              if (lastFinished != null)
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit last sleep',
                  onPressed: () => editSleep(context, store, lastFinished),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => startSleep(context, store),
            icon: const Icon(Icons.bedtime),
            label: const Text('Start sleep'),
            style: _bigButtonStyle,
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => addSleepManually(context, store),
          icon: const Icon(Icons.edit_calendar),
          label: const Text('Add sleep manually'),
        ),
      ],
    );
  }
}

class DiaperCard extends StatelessWidget {
  const DiaperCard({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final lastDiaper = store.diapers.isEmpty ? null : store.diapers.last;

    return SectionCard(
      children: [
        const SectionTitle(Icons.baby_changing_station, 'Diaper change'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lastDiaper == null
                        ? 'No diaper changes recorded yet'
                        : 'Last change: ${formatDateTime(lastDiaper.time)}',
                    style: _mutedStyle(context),
                  ),
                  if (lastDiaper != null) ...[
                    const SizedBox(height: 12),
                    Text('Contents: ${lastDiaper.contentsLabel}', style: _bodyStyle(context)),
                  ],
                  if (lastDiaper != null && lastDiaper.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(lastDiaper.notes, style: _mutedStyle(context)),
                  ],
                ],
              ),
            ),
            if (lastDiaper != null)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit last diaper change',
                onPressed: () => editDiaper(context, store, lastDiaper),
              ),
          ],
        ),
        const SizedBox(height: 20),
        _ReminderSection(
          title: 'Diaper reminder',
          enabled: store.diaperReminderEnabled,
          interval: store.diaperReminderInterval,
          next: lastDiaper?.time.add(store.diaperReminderInterval),
          noNextMessage: 'Record a diaper change to set the next reminder',
          dialogTitle: 'Set diaper reminder interval',
          onChanged: store.setDiaperReminder,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => recordDiaper(context, store),
          icon: const Icon(Icons.baby_changing_station),
          label: const Text('Record diaper change'),
          style: _bigButtonStyle,
        ),
      ],
    );
  }
}

class GrowthCard extends StatelessWidget {
  const GrowthCard({super.key, required this.store, required this.onViewChart});

  final AppStore store;
  final VoidCallback onViewChart;

  @override
  Widget build(BuildContext context) {
    final last = store.growth.isEmpty ? null : store.growth.last;

    return SectionCard(
      children: [
        const SectionTitle(Icons.monitor_weight, 'Growth'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    last == null ? 'No measurements recorded yet' : 'Last measured: ${formatDateTime(last.time)}',
                    style: _mutedStyle(context),
                  ),
                  if (last != null) ...[
                    const SizedBox(height: 12),
                    if (last.weight != null) Text('Weight: ${last.weight} ${last.weightUnit}', style: _bodyStyle(context)),
                    if (last.height != null) Text('Height: ${last.height} ${last.heightUnit}', style: _bodyStyle(context)),
                  ],
                ],
              ),
            ),
            if (last != null)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit last measurement',
                onPressed: () => editGrowth(context, store, last),
              ),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onViewChart,
          icon: const Icon(Icons.timeline),
          label: const Text('View growth chart'),
          style: _bigButtonStyle,
        ),
      ],
    );
  }
}
