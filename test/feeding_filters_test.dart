import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukoyaka/diaper_entry.dart';
import 'package:sukoyaka/feeding_entry.dart';
import 'package:sukoyaka/feeding_filters.dart';

FeedingEntry entryAt(int id, DateTime time) => FeedingEntry(
      id: id,
      time: time,
      milkType: 'Bottle',
      amount: 120,
      amountUnit: 'ml',
      notes: '',
    );

DiaperEntry diaperAt(int id, DateTime time) =>
    DiaperEntry(id: id, time: time, pee: true);

void main() {
  group('filterEntriesForRange', () {
    test('includes both day boundaries of a multi-day range', () {
      final entries = [
        entryAt(1, DateTime(2026, 7, 27, 23, 59)), // day before start
        entryAt(2, DateTime(2026, 7, 28)), // 00:00 on start
        entryAt(3, DateTime(2026, 7, 30, 12)),
        entryAt(4, DateTime(2026, 8, 3, 23, 59)), // 23:59 on end
        entryAt(5, DateTime(2026, 8, 4)), // 00:00 the day after end
      ];

      final filtered = filterEntriesForRange(
        entries,
        DateTimeRange(start: DateTime(2026, 7, 28), end: DateTime(2026, 8, 3)),
      );

      expect(filtered.map((e) => e.id), [2, 3, 4]);
    });

    test('ignores time components on the range itself', () {
      final entries = [entryAt(1, DateTime(2026, 7, 28, 6))];

      // A range whose start is late in the day still matches a morning entry.
      final filtered = filterEntriesForRange(
        entries,
        DateTimeRange(
          start: DateTime(2026, 7, 28, 22),
          end: DateTime(2026, 7, 28, 22),
        ),
      );

      expect(filtered, hasLength(1));
    });

    test('returns nothing when no entry falls in the range', () {
      final entries = [entryAt(1, DateTime(2026, 7, 28, 6))];

      final filtered = filterEntriesForRange(
        entries,
        DateTimeRange(start: DateTime(2026, 8, 1), end: DateTime(2026, 8, 5)),
      );

      expect(filtered, isEmpty);
    });
  });

  group('groupEntriesByDay', () {
    test('buckets by calendar day, newest day and entry first', () {
      final entries = [
        entryAt(1, DateTime(2026, 8, 1, 8)),
        entryAt(2, DateTime(2026, 8, 3, 8, 15)),
        entryAt(3, DateTime(2026, 8, 3, 23, 40)),
        entryAt(4, DateTime(2026, 8, 2, 18)),
      ];

      final grouped = groupEntriesByDay(entries);

      expect(grouped.map((g) => g.day), [
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 2),
        DateTime(2026, 8, 1),
      ]);
      expect(grouped.map((g) => g.entries.length), [2, 1, 1]);
      // Within Aug 3, the 23:40 entry comes before the 8:15 one.
      expect(grouped.first.entries.map((e) => e.id), [3, 2]);
    });

    test('returns an empty list for no entries', () {
      expect(groupEntriesByDay(<FeedingEntry>[]), isEmpty);
    });
  });

  group('diaper entries', () {
    test('filterEntriesForRange includes both day boundaries', () {
      final entries = [
        diaperAt(1, DateTime(2026, 7, 27, 23, 59)), // day before start
        diaperAt(2, DateTime(2026, 7, 28)), // 00:00 on start
        diaperAt(3, DateTime(2026, 8, 3, 23, 59)), // 23:59 on end
        diaperAt(4, DateTime(2026, 8, 4)), // 00:00 the day after end
      ];

      final filtered = filterEntriesForRange(
        entries,
        DateTimeRange(start: DateTime(2026, 7, 28), end: DateTime(2026, 8, 3)),
      );

      expect(filtered, isA<List<DiaperEntry>>());
      expect(filtered.map((e) => e.id), [2, 3]);
    });

    test('groupEntriesByDay buckets newest day and entry first', () {
      final entries = [
        diaperAt(1, DateTime(2026, 8, 1, 8)),
        diaperAt(2, DateTime(2026, 8, 3, 8, 15)),
        diaperAt(3, DateTime(2026, 8, 3, 23, 40)),
      ];

      final grouped = groupEntriesByDay(entries);

      expect(grouped.map((g) => g.day), [
        DateTime(2026, 8, 3),
        DateTime(2026, 8, 1),
      ]);
      expect(grouped.first.entries.map((e) => e.id), [3, 2]);
    });
  });

  group('startOfDay / endOfDay', () {
    test('clamp to the surrounding local day', () {
      final time = DateTime(2026, 8, 3, 14, 22, 33);

      expect(startOfDay(time), DateTime(2026, 8, 3));
      expect(endOfDay(time), DateTime(2026, 8, 3, 23, 59, 59));
    });
  });
}
