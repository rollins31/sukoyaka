import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'feeding_filters.dart';

typedef FilterPreset = ({String label, DateTimeRange range});

/// The quick-filter presets offered above the history lists. Ranges are built
/// from bare dates because [filterEntriesForRange] widens them to whole days.
List<FilterPreset> filterPresets() {
  final today = startOfDay(DateTime.now());
  return [
    (label: 'Today', range: DateTimeRange(start: today, end: today)),
    (
      label: 'Last 7 days',
      range: DateTimeRange(
        start: DateTime(today.year, today.month, today.day - 6),
        end: today,
      ),
    ),
    (
      label: 'This month',
      range: DateTimeRange(
        start: DateTime(today.year, today.month, 1),
        end: today,
      ),
    ),
  ];
}

/// The default range for histories that are logged several times a day, so a
/// long-lived log doesn't dump months of entries on screen until asked.
DateTimeRange lastSevenDays() =>
    filterPresets().firstWhere((preset) => preset.label == 'Last 7 days').range;

/// Date-range picker for the filter bars and range exports. Returns null when
/// the user backs out, so callers leave their current range untouched.
Future<DateTimeRange?> pickDateRange(BuildContext context, DateTimeRange? initial) {
  return showDateRangePicker(
    context: context,
    firstDate: DateTime.now().subtract(const Duration(days: 365)),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    initialDateRange: initial,
    // Calendar-only: typing a range as raw mm/dd/yyyy text is fussier than
    // just tapping the two dates, and error-prone if the format's off.
    initialEntryMode: DatePickerEntryMode.calendarOnly,
  );
}

/// 'Aug 3, 2026' for a single day, otherwise 'Jul 28 – Aug 3, 2026'.
String formatFilterRange(DateTimeRange range) {
  if (startOfDay(range.start) == startOfDay(range.end)) {
    return DateFormat.yMMMd().format(range.start);
  }
  return '${DateFormat('MMM d').format(range.start)} – ${DateFormat.yMMMd().format(range.end)}';
}

/// The date-range button, quick-filter chips and clear button above the
/// Feedings, Diapers and Growth histories. [actions] are extra buttons placed
/// between the range button and the clear button.
class DateRangeFilterBar extends StatelessWidget {
  const DateRangeFilterBar({
    super.key,
    required this.range,
    required this.onChanged,
    this.actions = const [],
  });

  final DateTimeRange? range;
  final ValueChanged<DateTimeRange?> onChanged;
  final List<Widget> actions;

  static bool _isPresetActive(DateTimeRange preset, DateTimeRange? active) {
    if (active == null) return false;
    return startOfDay(active.start) == preset.start && startOfDay(active.end) == preset.end;
  }

  @override
  Widget build(BuildContext context) {
    final range = this.range;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await pickDateRange(context, range);
                    if (selected == null) return;
                    onChanged(selected);
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(range == null ? 'Filter by date range' : formatFilterRange(range)),
                ),
              ),
              for (final action in actions) ...[
                const SizedBox(width: 8),
                action,
              ],
              if (range != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear filter',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final preset in filterPresets())
                FilterChip(
                  label: Text(preset.label),
                  selected: _isPresetActive(preset.range, range),
                  onSelected: (selected) => onChanged(selected ? preset.range : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
