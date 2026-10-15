/// SharedPreferences keys for the logs and reminder settings.
///
/// Shared by the main app and the widget's quick-log popup, which runs in a
/// separate engine but reads and writes the same preferences. Renaming any of
/// these orphans data already saved on users' devices.
abstract final class StorageKeys {
  static const feedings = 'feeding_entries';
  static const sleeps = 'sleep_entries';
  static const diapers = 'diaper_entries';
  static const growth = 'growth_entries';
  static const feedReminderInterval = 'reminder_interval_minutes';
  static const feedReminderEnabled = 'feed_reminder_enabled';
  static const diaperReminderEnabled = 'diaper_reminder_enabled';
  static const diaperReminderInterval = 'diaper_reminder_interval_minutes';
  static const themeMode = 'theme_mode';
}
