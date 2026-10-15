import 'package:flutter_test/flutter_test.dart';
import 'package:sukoyaka/date_axis.dart';

void main() {
  // Roughly the Growth tab on a 360dp phone at default text size.
  const width = 300.0;
  const dayLabel = 24.0;
  const monthLabel = 34.0;

  DateAxis axisFor(DateTime first, DateTime last, {double width = width}) => computeDateAxis(
        first,
        last,
        width: width,
        dayLabelWidth: dayLabel,
        monthLabelWidth: monthLabel,
      );

  /// Pixel distance between neighbouring ticks on [axis].
  List<double> tickSpacings(DateAxis axis, double width) {
    final pxPerDay = width / (axis.maxX - axis.minX);
    return [
      for (var i = 1; i < axis.ticks.length; i++)
        (dayNumber(axis.ticks[i]) - dayNumber(axis.ticks[i - 1])) * pxPerDay,
    ];
  }

  group('dayNumber', () {
    test('local midnights are whole numbers, even across a DST change', () {
      // US DST ended 2026-11-01; the day is 25 hours long in local time.
      final before = dayNumber(DateTime(2026, 10, 31));
      final after = dayNumber(DateTime(2026, 11, 2));
      expect(after - before, 2);
      expect(before, before.roundToDouble());
    });

    test('round-trips through dateForDayNumber', () {
      final day = dayNumber(DateTime(2026, 9, 20, 15, 30)).floor();
      expect(dateForDayNumber(day), DateTime(2026, 9, 20));
    });
  });

  group('computeDateAxis', () {
    test('a few weeks of data gets day ticks on midnights, starting at the first day', () {
      final axis = axisFor(DateTime(2026, 9, 20, 9), DateTime(2026, 10, 8, 16, 25));

      expect(axis.monthly, isFalse);
      expect(axis.ticks.first, DateTime(2026, 9, 20));
      for (final tick in axis.ticks) {
        expect(tick, DateTime(tick.year, tick.month, tick.day), reason: 'tick not at midnight');
      }
    });

    test('neighbouring labels never overlap', () {
      for (final days in [0, 1, 5, 18, 40, 120, 400, 1100]) {
        final first = DateTime(2026, 1, 15, 10);
        final axis = axisFor(first, first.add(Duration(days: days)));
        final labelWidth = axis.monthly ? monthLabel : dayLabel;
        for (final spacing in tickSpacings(axis, width)) {
          expect(spacing, greaterThanOrEqualTo(labelWidth + 12), reason: '$days-day range');
        }
      }
    });

    test('pads both ends so the outermost points are inside the axis', () {
      final first = DateTime(2026, 9, 20, 9);
      final last = DateTime(2026, 10, 8, 16);
      final axis = axisFor(first, last);
      expect(axis.minX, lessThan(dayNumber(first)));
      expect(axis.maxX, greaterThan(dayNumber(last)));
    });

    test('a single measurement still gets a labelled, non-empty axis', () {
      final only = DateTime(2026, 9, 20, 23, 30);
      final axis = axisFor(only, only);
      expect(axis.maxX, greaterThan(axis.minX));
      expect(axis.ticks, [DateTime(2026, 9, 20)]);
    });

    test('a long range switches to month ticks on the 1st, aligned to the step', () {
      final axis = axisFor(DateTime(2025, 2, 10), DateTime(2026, 9, 20));
      expect(axis.monthly, isTrue);
      final step = axis.ticks[1].month - axis.ticks[0].month + 12 * (axis.ticks[1].year - axis.ticks[0].year);
      for (final tick in axis.ticks) {
        expect(tick.day, 1);
        expect((tick.month - 1) % step, 0, reason: '$tick not aligned to a $step-month step');
      }
    });

    test('a narrower chart uses a coarser step', () {
      final first = DateTime(2026, 9, 1);
      final last = DateTime(2026, 10, 15);
      final wide = axisFor(first, last, width: 600);
      final narrow = axisFor(first, last, width: 200);
      expect(narrow.ticks.length, lessThan(wide.ticks.length));
    });
  });

  group('DateAxis', () {
    test('isTick matches tick midnights only', () {
      final axis = axisFor(DateTime(2026, 9, 20), DateTime(2026, 10, 8));
      final tickX = dayNumber(axis.ticks.first);
      expect(axis.isTick(tickX), isTrue);
      expect(axis.isTick(tickX + 0.5), isFalse);
    });

    test('month labels show the year on the first tick and on January', () {
      final axis = axisFor(DateTime(2025, 10, 5), DateTime(2026, 9, 20));
      expect(axis.monthly, isTrue);
      expect(axis.label(axis.ticks.first), contains("'"));
      final january = axis.ticks.where((t) => t.month == DateTime.january);
      for (final tick in january) {
        expect(axis.label(tick), "Jan '26");
      }
      final others = axis.ticks.skip(1).where((t) => t.month != DateTime.january);
      for (final tick in others) {
        expect(axis.label(tick), isNot(contains("'")));
      }
    });

    test('day labels are month/day', () {
      final axis = axisFor(DateTime(2026, 9, 20), DateTime(2026, 9, 25));
      expect(axis.label(DateTime(2026, 9, 21)), '9/21');
    });
  });
}
