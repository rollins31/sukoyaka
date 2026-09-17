import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sukoyaka/feeding_entry.dart';
import 'package:sukoyaka/pdf_export.dart';

void main() {
  test('filters entries that fall within the selected date range', () {
    final entries = [
      FeedingEntry(
        id: 1,
        time: DateTime(2026, 7, 1, 8),
        milkType: 'Bottle',
        amount: 120,
        amountUnit: 'ml',
        notes: '',
      ),
      FeedingEntry(
        id: 2,
        time: DateTime(2026, 7, 2, 8),
        milkType: 'Breastfeeding',
        amount: null,
        amountUnit: 'ml',
        notes: '',
      ),
      FeedingEntry(
        id: 3,
        time: DateTime(2026, 7, 3, 8),
        milkType: 'Other',
        amount: 5,
        amountUnit: 'oz',
        notes: 'Test',
      ),
    ];

    final range = DateTimeRange(
      start: DateTime(2026, 7, 2),
      end: DateTime(2026, 7, 2),
    );

    final filtered = filterEntriesForRange(entries, range);

    expect(filtered, hasLength(1));
    expect(filtered.single.id, 2);
  });
}
