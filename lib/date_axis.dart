import 'package:intl/intl.dart';

/// Chart x-values for dates are "day numbers": whole days since 1970-01-01
/// in local calendar terms, plus the time of day as a fraction. Counting
/// calendar days (rather than milliseconds) keeps every local midnight on an
/// integer even across DST changes, so day ticks can be matched exactly.
double dayNumber(DateTime time) {
  final days = DateTime.utc(time.year, time.month, time.day).difference(DateTime.utc(1970)).inDays;
  final secondsIntoDay = time.hour * 3600 + time.minute * 60 + time.second;
  return days + secondsIntoDay / Duration.secondsPerDay;
}

/// The local midnight starting [day] (an integer day number).
DateTime dateForDayNumber(int day) {
  final utc = DateTime.utc(1970).add(Duration(days: day));
  return DateTime(utc.year, utc.month, utc.day);
}

/// Where a date axis starts and ends, and which midnights get a label.
class DateAxis {
  const DateAxis({required this.minX, required this.maxX, required this.ticks, required this.monthly});

  final double minX;
  final double maxX;

  /// Labelled positions, as local midnights in ascending order.
  final List<DateTime> ticks;

  /// Whether [ticks] fall on the 1st of a month (labelled by month name)
  /// rather than every N days (labelled as a date).
  final bool monthly;

  /// Whether the chart x-value [x] is one of [ticks].
  bool isTick(double x) {
    final day = x.round();
    if ((x - day).abs() > 1e-6) return false;
    return ticks.any((tick) => dayNumber(tick) == day);
  }

  /// "9/21" for day steps. For month steps, "Oct" — with the year added on
  /// the first tick and on each January, so a year change is never ambiguous.
  String label(DateTime tick) {
    if (!monthly) return DateFormat.Md().format(tick);
    final showYear = tick == ticks.first || tick.month == DateTime.january;
    return DateFormat(showYear ? "MMM ''yy" : 'MMM').format(tick);
  }
}

const _dayStepCandidates = [1, 2, 3, 7, 14];
const _monthStepCandidates = [1, 2, 3, 6, 12];

/// Picks the smallest readable tick step for measurements spanning [first]
/// to [last] on an axis [width] pixels wide, such that neighbouring labels
/// are never closer than their width plus [gap].
///
/// Day steps start at [first]'s midnight; month steps land on the 1st of
/// every Nth month (quarterly = Jan/Apr/Jul/Oct). The axis is padded by half
/// a step on each side so the outermost points don't sit on the chart border.
DateAxis computeDateAxis(
  DateTime first,
  DateTime last, {
  required double width,
  required double dayLabelWidth,
  required double monthLabelWidth,
  double gap = 12,
}) {
  final firstDay = dayNumber(first).floor();
  final lastValue = dayNumber(last);

  DateAxis? fallback;
  for (final step in _dayStepCandidates) {
    final pad = step / 2;
    final minX = firstDay - pad;
    final maxX = lastValue + pad;
    // Stop at the last measurement's day: anything later would only be
    // labelling the padding.
    final ticks = [
      for (var day = firstDay; day <= lastValue.floor(); day += step) dateForDayNumber(day),
    ];
    final axis = DateAxis(minX: minX, maxX: maxX, ticks: ticks, monthly: false);
    if (step * width / (maxX - minX) >= dayLabelWidth + gap) return axis;
    fallback = axis;
  }

  for (final months in _monthStepCandidates) {
    // Months are 28-31 days; size padding and spacing off the shortest.
    final pad = months * 28 / 2;
    final minX = dayNumber(first) - pad;
    final maxX = lastValue + pad;
    // Month index counted from year 0, aligned down to a multiple of
    // [months] so e.g. quarterly ticks always land on Jan/Apr/Jul/Oct.
    final startMonth = first.year * 12 + first.month - 1;
    final ticks = <DateTime>[];
    for (var m = startMonth - startMonth % months;; m += months) {
      final tick = DateTime(m ~/ 12, m % 12 + 1);
      final x = dayNumber(tick);
      if (x > maxX) break;
      if (x >= minX) ticks.add(tick);
    }
    final axis = DateAxis(minX: minX, maxX: maxX, ticks: ticks, monthly: true);
    if (months * 28 * width / (maxX - minX) >= monthLabelWidth + gap) return axis;
    fallback = axis;
  }
  return fallback!;
}
