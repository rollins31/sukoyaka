/// Anything that can be filtered and grouped by when it happened.
///
/// Implemented by the log models so the date helpers in `feeding_filters.dart`
/// work for feedings, diapers and anything added later.
abstract interface class TimestampedEntry {
  DateTime get time;
}
