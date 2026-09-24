import 'diaper_entry.dart';
import 'feeding_entry.dart';
import 'growth_entry.dart';
import 'sleep_entry.dart';

/// Snapshot of everything the app stores locally, for backup/restore.
/// Bumped whenever the shape of an entry changes in a way old imports would
/// misread.
const backupFormatVersion = 1;

class AppBackup {
  AppBackup({
    required this.exportedAt,
    required this.feedings,
    required this.sleepEntries,
    required this.diaperEntries,
    required this.growthEntries,
    required this.reminderIntervalMinutes,
    required this.diaperReminderEnabled,
    required this.diaperReminderIntervalMinutes,
  });

  final DateTime exportedAt;
  final List<FeedingEntry> feedings;
  final List<SleepEntry> sleepEntries;
  final List<DiaperEntry> diaperEntries;
  final List<GrowthEntry> growthEntries;
  final int reminderIntervalMinutes;
  final bool diaperReminderEnabled;
  final int diaperReminderIntervalMinutes;

  factory AppBackup.fromJson(Map<String, dynamic> json) {
    return AppBackup(
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      feedings: (json['feedings'] as List<dynamic>? ?? [])
          .map((raw) => FeedingEntry.fromJson(raw as Map<String, dynamic>))
          .toList(),
      sleepEntries: (json['sleepEntries'] as List<dynamic>? ?? [])
          .map((raw) => SleepEntry.fromJson(raw as Map<String, dynamic>))
          .toList(),
      diaperEntries: (json['diaperEntries'] as List<dynamic>? ?? [])
          .map((raw) => DiaperEntry.fromJson(raw as Map<String, dynamic>))
          .toList(),
      growthEntries: (json['growthEntries'] as List<dynamic>? ?? [])
          .map((raw) => GrowthEntry.fromJson(raw as Map<String, dynamic>))
          .toList(),
      reminderIntervalMinutes: json['reminderIntervalMinutes'] as int? ?? 180,
      diaperReminderEnabled: json['diaperReminderEnabled'] as bool? ?? false,
      diaperReminderIntervalMinutes: json['diaperReminderIntervalMinutes'] as int? ?? 180,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': backupFormatVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'feedings': feedings.map((e) => e.toJson()).toList(),
      'sleepEntries': sleepEntries.map((e) => e.toJson()).toList(),
      'diaperEntries': diaperEntries.map((e) => e.toJson()).toList(),
      'growthEntries': growthEntries.map((e) => e.toJson()).toList(),
      'reminderIntervalMinutes': reminderIntervalMinutes,
      'diaperReminderEnabled': diaperReminderEnabled,
      'diaperReminderIntervalMinutes': diaperReminderIntervalMinutes,
    };
  }

  /// Total record count, shown to the user before they overwrite local data.
  int get entryCount =>
      feedings.length + sleepEntries.length + diaperEntries.length + growthEntries.length;
}
