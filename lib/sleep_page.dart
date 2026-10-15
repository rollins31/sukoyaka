import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'app_store.dart';
import 'duration_format.dart';
import 'empty_state.dart';
import 'entry_actions.dart';
import 'export_result_snackbar.dart';
import 'feeding_filters.dart';
import 'pdf_export.dart';
import 'sleep_ticker.dart';
import 'weekly_sleep_chart.dart';

/// Local midnight of the Monday that begins the week containing [date].
DateTime _startOfWeek(DateTime date) => DateTime(date.year, date.month, date.day - (date.weekday - 1));

/// 'Jul 28 – Aug 3' for the Monday-starting week beginning on [weekStart].
String _formatWeekRange(DateTime weekStart) {
  final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  return '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(weekEnd)}';
}

/// The Sleep tab: one week at a time, as a chart plus the sessions in it.
/// The "Add Sleep" button is the main scaffold's FAB.
class SleepPage extends StatefulWidget {
  const SleepPage({super.key, required this.store});

  final AppStore store;

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  DateTime _weekStart = _startOfWeek(DateTime.now());

  AppStore get _store => widget.store;

  void _shiftWeek(int days) =>
      setState(() => _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + days));

  /// Jumps straight to the week containing a picked date, instead of stepping
  /// there one week at a time with the arrows.
  Future<void> _pickWeek() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (selected == null || !mounted) return;
    setState(() => _weekStart = _startOfWeek(selected));
  }

  /// Exports the sleep sessions for the week on screen — this page browses by
  /// week rather than an arbitrary range, so the export follows the same
  /// concept instead of adding a second range picker.
  Future<void> _exportWeek() async {
    if (_store.sleeps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no sleep data to export.')),
      );
      return;
    }

    final weekStart = _weekStart;
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    await exportWithFeedback(
      context,
      export: () => exportReportToPdf(
        sections: {ReportSection.sleep},
        range: DateTimeRange(start: weekStart, end: weekEnd),
        sleepEntries: _store.sleeps,
      ),
      noDataMessage: 'No sleep sessions found for ${_formatWeekRange(weekStart)}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SleepTicker(
      active: _store.activeSleep != null,
      builder: _buildPage,
    );
  }

  Widget _buildPage(BuildContext context) {
    final weekStart = _weekStart;
    final weekEndExclusive = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final now = DateTime.now();
    final canGoNext = weekStart.isBefore(_startOfWeek(now));
    final sleeps = _store.sleeps;

    // Sessions overlapping the selected week, most recent first. A session is
    // "in" the week if it started before the week ends and (for finished
    // sessions) ended after the week began, matching how WeeklySleepChart
    // clips sessions to each day's bar.
    final entries = sleeps.where((entry) {
      final effectiveEnd = entry.end ?? now;
      return entry.start.isBefore(weekEndExclusive) && effectiveEnd.isAfter(weekStart);
    }).toList().reversed.toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildWeekHeader(canGoNext),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: WeeklySleepChart(
                  weekStart: weekStart,
                  entries: sleeps,
                  now: now,
                  onTapEntry: (entry) => editSleep(context, _store, entry),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.bedtime,
              message: sleeps.isEmpty
                  ? 'No sleep sessions yet!\nTap Start sleep on the Home tab, or Add Sleep here.'
                  : 'No sleep sessions for ${_formatWeekRange(weekStart)}.',
            ),
          )
        else
          SliverPadding(
            // Extra bottom padding keeps the last card clear of the floating
            // "Add Sleep" button, which would otherwise sit on top of it.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final inProgress = entry.isInProgress;
                final durationLabel = inProgress
                    ? '${formatDuration(DateTime.now().difference(entry.start))} (ongoing)'
                    : formatDuration(entry.duration!);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                      child: Icon(inProgress ? Icons.nightlight : Icons.bedtime),
                    ),
                    title: Text(
                      durationLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inProgress
                            ? 'Started ${formatDateTime(entry.start)}'
                            : '${formatDateTime(entry.start)} → ${formatDateTime(entry.end!)}'),
                        if (entry.notes.isNotEmpty) Text(entry.notes),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => editSleep(context, _store, entry),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _store.deleteSleep(entry),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildWeekHeader(bool canGoNext) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftWeek(-7),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous week',
          ),
          Expanded(
            child: InkWell(
              onTap: _pickWeek,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Text(
                      _formatWeekRange(_weekStart),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (!canGoNext)
                      Text(
                        'This week',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext ? () => _shiftWeek(7) : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next week',
          ),
          IconButton(
            onPressed: _exportWeek,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export this week to PDF',
          ),
        ],
      ),
    );
  }
}
