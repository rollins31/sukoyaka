import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'sleep_entry.dart';

/// A single sleep bar to draw within one day row, expressed as fractions of the
/// day (0.0 = midnight, 1.0 = next midnight).
typedef _Segment = ({double startFrac, double endFrac, SleepEntry entry, bool inProgress});

/// A weekly sleep chart: one horizontal row per day, time running left → right
/// across 24 hours, with each sleep session drawn as a bar. Sessions that cross
/// midnight are split across the two days they touch. Tapping a bar invokes
/// [onTapEntry] (used to open the edit form).
class WeeklySleepChart extends StatelessWidget {
  const WeeklySleepChart({
    super.key,
    required this.weekStart,
    required this.entries,
    required this.now,
    required this.onTapEntry,
  });

  /// Local midnight of the first day of the displayed week (Monday).
  final DateTime weekStart;
  final List<SleepEntry> entries;
  final DateTime now;
  final void Function(SleepEntry entry) onTapEntry;

  static const double _labelWidth = 44;
  static const double _rowHeight = 22;

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
    );
    final today = DateTime(now.year, now.month, now.day);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAxis(context),
        const SizedBox(height: 6),
        for (final day in days) ...[
          _buildDayRow(context, day, today),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 4),
        _buildLegend(context),
      ],
    );
  }

  Widget _buildAxis(BuildContext context) {
    final style = TextStyle(
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      children: [
        const SizedBox(width: _labelWidth),
        Expanded(
          child: Row(
            children: [
              Expanded(child: Text('12a', style: style)),
              Expanded(child: Text('6a', style: style)),
              Expanded(child: Text('12p', style: style)),
              Expanded(child: Text('6p', style: style)),
              Text('12a', style: style),
            ],
          ),
        ),
      ],
    );
  }

  List<_Segment> _segmentsForDay(DateTime dayStart, DateTime dayEnd) {
    final segments = <_Segment>[];
    for (final entry in entries) {
      final effectiveEnd = entry.end ?? now;
      if (!effectiveEnd.isAfter(entry.start)) continue;

      // Clip the session to this day's [dayStart, dayEnd] window.
      final segStart = entry.start.isAfter(dayStart) ? entry.start : dayStart;
      final segEnd = effectiveEnd.isBefore(dayEnd) ? effectiveEnd : dayEnd;
      if (!segEnd.isAfter(segStart)) continue;

      segments.add((
        startFrac: segStart.difference(dayStart).inMinutes / 1440.0,
        endFrac: segEnd.difference(dayStart).inMinutes / 1440.0,
        entry: entry,
        inProgress: entry.end == null,
      ));
    }
    return segments;
  }

  Widget _buildDayRow(BuildContext context, DateTime day, DateTime today) {
    final scheme = Theme.of(context).colorScheme;
    final dayStart = day;
    final dayEnd = DateTime(day.year, day.month, day.day + 1);
    final isToday = day == today;
    final segments = _segmentsForDay(dayStart, dayEnd);

    return Row(
      children: [
        SizedBox(
          width: _labelWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('EEE').format(day),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isToday ? scheme.primary : scheme.onSurface,
                ),
              ),
              Text(
                DateFormat('d').format(day),
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return SizedBox(
                height: _rowHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    // Faint gridlines at 6a / 12p / 6p.
                    for (final fraction in const [0.25, 0.5, 0.75])
                      Positioned(
                        left: width * fraction,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    for (final seg in segments)
                      Positioned(
                        left: seg.startFrac * width,
                        width: ((seg.endFrac - seg.startFrac) * width).clamp(3.0, width),
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => onTapEntry(seg.entry),
                          child: Container(
                            decoration: BoxDecoration(
                              color: seg.inProgress ? scheme.tertiary : scheme.primary,
                              borderRadius: BorderRadius.circular(6),
                              border: seg.inProgress
                                  ? Border.all(color: scheme.onTertiaryContainer, width: 1)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    Widget swatch(Color color, {bool bordered = false}) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: bordered ? Border.all(color: scheme.onTertiaryContainer) : null,
          ),
        );
    return Row(
      children: [
        swatch(scheme.primary),
        const SizedBox(width: 4),
        Text('Asleep', style: style),
        const SizedBox(width: 16),
        swatch(scheme.tertiary, bordered: true),
        const SizedBox(width: 4),
        Text('In progress', style: style),
      ],
    );
  }
}
