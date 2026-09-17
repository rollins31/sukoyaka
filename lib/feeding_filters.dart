import 'package:flutter/material.dart';

import 'feeding_entry.dart';
import 'timestamped_entry.dart';

/// Local midnight at the start of [date].
DateTime startOfDay(DateTime date) => DateTime(date.year, date.month, date.day);

/// The last representable second of [date], in local time.
DateTime endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59);

/// Entries whose time falls inside [range], inclusive of both whole days.
///
/// The range's own time components are ignored — only the calendar days matter,
/// so a range built from bare dates still matches entries recorded late at
/// night on the final day.
List<T> filterEntriesForRange<T extends TimestampedEntry>(
  List<T> entries,
  DateTimeRange range,
) {
  final start = startOfDay(range.start);
  final end = endOfDay(range.end);
  return entries.where((entry) {
    return !entry.time.isBefore(start) && !entry.time.isAfter(end);
  }).toList();
}

/// One calendar day's worth of entries, used to render date headers.
typedef EntryDay<T> = ({DateTime day, List<T> entries});

/// One calendar day's worth of feedings.
typedef FeedingDay = EntryDay<FeedingEntry>;

/// Buckets [entries] by local calendar day, newest day first, with each day's
/// entries ordered newest first.
List<EntryDay<T>> groupEntriesByDay<T extends TimestampedEntry>(
  List<T> entries,
) {
  final buckets = <DateTime, List<T>>{};
  for (final entry in entries) {
    buckets.putIfAbsent(startOfDay(entry.time), () => []).add(entry);
  }

  final days = buckets.keys.toList()..sort((a, b) => b.compareTo(a));
  return days.map((day) {
    final dayEntries = buckets[day]!..sort((a, b) => b.time.compareTo(a.time));
    return (day: day, entries: dayEntries);
  }).toList();
}
