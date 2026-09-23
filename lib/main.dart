import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup_data.dart';
import 'diaper_entry.dart';
import 'duration_format.dart';
import 'empty_state.dart';
import 'feeding_entry.dart';
import 'feeding_entry_form.dart';
import 'feeding_filters.dart';
import 'growth_entry.dart';
import 'growth_screen.dart';
import 'home_widget_sync.dart';
import 'notification_service.dart';
import 'pdf_export.dart';
import 'quick_log_screen.dart';
import 'settings_screen.dart';
import 'sleep_entry.dart';
import 'weekly_sleep_chart.dart';

const _entriesKey = 'feeding_entries';
const _sleepEntriesKey = 'sleep_entries';
const _diaperEntriesKey = 'diaper_entries';
const _growthEntriesKey = 'growth_entries';
const _intervalKey = 'reminder_interval_minutes';
const _diaperReminderEnabledKey = 'diaper_reminder_enabled';
const _diaperIntervalKey = 'diaper_reminder_interval_minutes';
const _themeModeKey = 'theme_mode';

/// Global so the Settings screen (pushed several routes below [MainApp]) can
/// change the app's theme without wiring a state-management dependency into
/// an app that otherwise just reads/writes SharedPreferences directly.
final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

Future<void> _loadThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final stored = prefs.getString(_themeModeKey);
  if (stored != null) {
    themeModeNotifier.value = ThemeMode.values.byName(stored);
  }
}

Future<void> setThemeMode(ThemeMode mode) async {
  themeModeNotifier.value = mode;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_themeModeKey, mode.name);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService.initialize() error: $e');
  }
  await _loadThemeMode();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A55C9),
      brightness: Brightness.light,
      secondary: const Color(0xFF7EC8BC),
      tertiary: const Color(0xFFD9A441),
      surface: const Color(0xFFFDF6F0),
    );
    // Soft rounded typeface for a warm, baby-friendly feel, with dark brown
    // body text tuned for the cream light background above.
    final lightTextTheme = GoogleFonts.nunitoTextTheme(
      ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF4A4038),
            displayColor: const Color(0xFF4A4038),
          ),
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A55C9),
      brightness: Brightness.dark,
      secondary: const Color(0xFF7EC8BC),
      tertiary: const Color(0xFFD9A441),
    );
    // Unlike light mode, dark mode keeps Material 3's generated on-surface
    // color instead of a fixed override, since a single hardcoded text color
    // can't stay legible against every dark surface tone.
    final darkTextTheme = GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Sukoyaka',
          themeMode: mode,
          theme: _buildTheme(lightColorScheme, lightTextTheme),
          darkTheme: _buildTheme(darkColorScheme, darkTextTheme),
          routes: {
            '/': (context) => const FeedingHome(),
            '/quickLog': (context) => const QuickLogScreen(),
          },
        );
      },
    );
  }
}

/// Shared between light and dark mode — only the [colorScheme] and
/// [textTheme] differ; every widget-specific style below derives its colors
/// from the scheme so it adapts automatically.
ThemeData _buildTheme(ColorScheme colorScheme, TextTheme textTheme) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.baloo2(
        color: colorScheme.onPrimaryContainer,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
      elevation: 2,
      shadowColor: colorScheme.primary.withValues(alpha: 0.25),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.baloo2(fontSize: 17, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.4), width: 1.5),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.primary,
        textStyle: GoogleFonts.baloo2(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.secondary,
      foregroundColor: colorScheme.onSecondary,
      extendedTextStyle: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      indicatorColor: colorScheme.primaryContainer,
      elevation: 3,
      labelTextStyle: WidgetStatePropertyAll(
        GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
  );
}

class FeedingHome extends StatefulWidget {
  const FeedingHome({super.key});

  @override
  State<FeedingHome> createState() => _FeedingHomeState();
}

class _FeedingHomeState extends State<FeedingHome> with WidgetsBindingObserver {
  final List<FeedingEntry> _entries = [];
  final List<SleepEntry> _sleepEntries = [];
  final List<DiaperEntry> _diaperEntries = [];
  /// Read-only cache for the Home card's "latest measurement" summary —
  /// growth's actual data lives entirely in GrowthScreen (see growth_screen.dart).
  final List<GrowthEntry> _growthEntries = [];
  Duration _reminderInterval = const Duration(hours: 3);
  bool _diaperReminderEnabled = false;
  Duration _diaperReminderInterval = const Duration(hours: 3);
  DateTimeRange? _filterRange;
  DateTimeRange? _diaperFilterRange;
  int _selectedIndex = 0;
  bool _loading = true;
  Timer? _sleepTicker;
  late DateTime _sleepWeekStart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sleepWeekStart = _startOfWeek(DateTime.now());
    // Default both histories to a recent window so a long-lived log doesn't
    // dump months of entries on screen until the user asks for more.
    final defaultRange = _filterPresets()
        .firstWhere((preset) => preset.label == 'Last 7 days')
        .range;
    _filterRange = defaultRange;
    _diaperFilterRange = defaultRange;
    _loadData();
    _loadGrowthEntries();
  }

  /// Reads just the growth-entries prefs key, for the Home card summary.
  /// Kept separate from [_loadData] since that method also does
  /// feed-reminder rescheduling and a home-widget sync that have nothing to
  /// do with growth and would otherwise re-run pointlessly on every return
  /// from [GrowthScreen].
  Future<void> _loadGrowthEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_growthEntriesKey);
    final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
    final loadedEntries = rawEntries
        .map((raw) => GrowthEntry.fromJson(raw as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (!mounted) return;
    setState(() {
      _growthEntries
        ..clear()
        ..addAll(loadedEntries);
    });
  }

  /// Local midnight of the Monday that begins the week containing [date].
  DateTime _startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sleepTicker?.cancel();
    super.dispose();
  }

  /// Picks up feedings logged from the widget's quick-log popup (a separate
  /// process) while this app was backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  /// The sleep session currently in progress, if any.
  SleepEntry? get _activeSleep {
    for (final entry in _sleepEntries) {
      if (entry.isInProgress) return entry;
    }
    return null;
  }

  /// Keeps a 1-second ticker running only while a sleep session is active, so
  /// the live elapsed duration on the Home tab stays current.
  void _updateSleepTicker() {
    if (_activeSleep != null) {
      _sleepTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _sleepTicker?.cancel();
      _sleepTicker = null;
    }
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_entriesKey);
      final rawEntries = jsonString == null ? [] : jsonDecode(jsonString) as List<dynamic>;
      final loadedEntries = rawEntries
          .map((raw) => FeedingEntry.fromJson(raw as Map<String, dynamic>))
          .toList();
      loadedEntries.sort((a, b) => a.time.compareTo(b.time));

      final sleepJsonString = prefs.getString(_sleepEntriesKey);
      final rawSleepEntries =
          sleepJsonString == null ? [] : jsonDecode(sleepJsonString) as List<dynamic>;
      final loadedSleepEntries = rawSleepEntries
          .map((raw) => SleepEntry.fromJson(raw as Map<String, dynamic>))
          .toList();
      loadedSleepEntries.sort((a, b) => a.start.compareTo(b.start));

      final diaperJsonString = prefs.getString(_diaperEntriesKey);
      final rawDiaperEntries =
          diaperJsonString == null ? [] : jsonDecode(diaperJsonString) as List<dynamic>;
      final loadedDiaperEntries = rawDiaperEntries
          .map((raw) => DiaperEntry.fromJson(raw as Map<String, dynamic>))
          .toList();
      loadedDiaperEntries.sort((a, b) => a.time.compareTo(b.time));

      final intervalMinutes = prefs.getInt(_intervalKey) ?? 180;
      final diaperReminderEnabled = prefs.getBool(_diaperReminderEnabledKey) ?? false;
      final diaperIntervalMinutes = prefs.getInt(_diaperIntervalKey) ?? 180;
      setState(() {
        _entries
          ..clear()
          ..addAll(loadedEntries);
        _sleepEntries
          ..clear()
          ..addAll(loadedSleepEntries);
        _diaperEntries
          ..clear()
          ..addAll(loadedDiaperEntries);
        _reminderInterval = Duration(minutes: intervalMinutes);
        _diaperReminderEnabled = diaperReminderEnabled;
        _diaperReminderInterval = Duration(minutes: diaperIntervalMinutes);
        _loading = false;
      });
      _updateSleepTicker();

      if (_entries.isNotEmpty) {
        final nextReminder = _entries.last.time.add(_reminderInterval);
        await NotificationService.scheduleFeedReminder(nextReminder);
      }
      await _rescheduleDiaperReminder();
      await _updateHomeWidget();
    } catch (e) {
      debugPrint('_loadData() error: $e');
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, encoded);
  }

  Future<void> _saveInterval() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_intervalKey, _reminderInterval.inMinutes);
  }

  Future<void> _saveDiaperReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_diaperReminderEnabledKey, _diaperReminderEnabled);
    await prefs.setInt(_diaperIntervalKey, _diaperReminderInterval.inMinutes);
  }

  /// Cancels any pending diaper reminder, then reschedules it from the last
  /// diaper entry's time — but only if the user has turned the reminder on.
  /// Safe to call unconditionally after any diaper-entries or
  /// diaper-reminder-settings change.
  Future<void> _rescheduleDiaperReminder() async {
    await NotificationService.cancelDiaperReminder();
    if (_diaperReminderEnabled && _diaperEntries.isNotEmpty) {
      await NotificationService.scheduleDiaperReminder(
        _diaperEntries.last.time.add(_diaperReminderInterval),
      );
    }
  }

  Future<void> _updateHomeWidget() => syncHomeWidget(_entries, _reminderInterval);

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          feedings: List.of(_entries),
          sleepEntries: List.of(_sleepEntries),
          diaperEntries: List.of(_diaperEntries),
          reminderInterval: _reminderInterval,
          diaperReminderEnabled: _diaperReminderEnabled,
          diaperReminderInterval: _diaperReminderInterval,
          growthEntries: List.of(_growthEntries),
          onRestore: _restoreFromBackup,
        ),
      ),
    );
  }

  Future<void> _openGrowthScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const GrowthScreen()),
    );
    await _loadGrowthEntries();
  }

  /// Replaces all locally stored data with the contents of [backup],
  /// persists it, and reschedules the feed reminder to match.
  Future<void> _restoreFromBackup(AppBackup backup) async {
    setState(() {
      _entries
        ..clear()
        ..addAll(backup.feedings)
        ..sort((a, b) => a.time.compareTo(b.time));
      _sleepEntries
        ..clear()
        ..addAll(backup.sleepEntries)
        ..sort((a, b) => a.start.compareTo(b.start));
      _diaperEntries
        ..clear()
        ..addAll(backup.diaperEntries)
        ..sort((a, b) => a.time.compareTo(b.time));
      _growthEntries
        ..clear()
        ..addAll(backup.growthEntries)
        ..sort((a, b) => a.time.compareTo(b.time));
      _reminderInterval = Duration(minutes: backup.reminderIntervalMinutes);
      _diaperReminderEnabled = backup.diaperReminderEnabled;
      _diaperReminderInterval = Duration(minutes: backup.diaperReminderIntervalMinutes);
    });
    _updateSleepTicker();
    await _saveEntries();
    await _saveSleepEntries();
    await _saveDiaperEntries();
    await _saveGrowthEntries();
    await _saveInterval();
    await _saveDiaperReminderSettings();
    await NotificationService.cancelReminder();
    if (_entries.isNotEmpty) {
      await NotificationService.scheduleFeedReminder(_entries.last.time.add(_reminderInterval));
    }
    await _rescheduleDiaperReminder();
    await _updateHomeWidget();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restored.')),
    );
  }

  Future<void> _saveSleepEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_sleepEntries.map((e) => e.toJson()).toList());
    await prefs.setString(_sleepEntriesKey, encoded);
  }

  Future<void> _saveDiaperEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_diaperEntries.map((e) => e.toJson()).toList());
    await prefs.setString(_diaperEntriesKey, encoded);
  }

  /// Writes the growth-entries prefs key directly — used only during backup
  /// restore. Day-to-day, GrowthScreen owns this key entirely itself.
  Future<void> _saveGrowthEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_growthEntries.map((e) => e.toJson()).toList());
    await prefs.setString(_growthEntriesKey, encoded);
  }

  Future<void> _recordDiaper() async {
    final entry = await _showDiaperForm();
    if (entry == null) return;
    setState(() {
      _diaperEntries.add(entry);
      _diaperEntries.sort((a, b) => a.time.compareTo(b.time));
    });
    await _saveDiaperEntries();
    await _rescheduleDiaperReminder();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diaper change recorded')),
    );
  }

  Future<void> _editDiaper(DiaperEntry entry) async {
    final updated = await _showDiaperForm(existingEntry: entry);
    if (updated == null) return;
    setState(() {
      entry.time = updated.time;
      entry.pee = updated.pee;
      entry.poo = updated.poo;
      entry.notes = updated.notes;
      _diaperEntries.sort((a, b) => a.time.compareTo(b.time));
    });
    await _saveDiaperEntries();
    await _rescheduleDiaperReminder();
  }

  Future<void> _deleteDiaper(DiaperEntry entry) async {
    setState(() {
      _diaperEntries.removeWhere((e) => e.id == entry.id);
    });
    await _saveDiaperEntries();
    await _rescheduleDiaperReminder();
  }

  Future<void> _updateDiaperReminderInterval(Duration interval) async {
    setState(() {
      _diaperReminderInterval = interval;
    });
    await _saveDiaperReminderSettings();
    await _rescheduleDiaperReminder();
  }

  Future<void> _setDiaperReminderEnabled(bool enabled) async {
    setState(() {
      _diaperReminderEnabled = enabled;
    });
    await _saveDiaperReminderSettings();
    await _rescheduleDiaperReminder();
  }

  Future<void> _startSleep() async {
    if (_activeSleep != null) return;
    final entry = SleepEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      start: DateTime.now(),
    );
    setState(() {
      _sleepEntries.add(entry);
      _sleepEntries.sort((a, b) => a.start.compareTo(b.start));
    });
    _updateSleepTicker();
    await _saveSleepEntries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sleep started')),
    );
  }

  /// Adds a sleep session via the form (start/end pickers) rather than the
  /// live timer, for logging periods after the fact.
  Future<void> _addSleepManually() async {
    final entry = await _showSleepForm();
    if (entry == null) return;
    setState(() {
      _sleepEntries.add(entry);
      _sleepEntries.sort((a, b) => a.start.compareTo(b.start));
    });
    _updateSleepTicker();
    await _saveSleepEntries();
  }

  Future<void> _stopSleep() async {
    final active = _activeSleep;
    if (active == null) return;
    setState(() {
      active.end = DateTime.now();
    });
    _updateSleepTicker();
    await _saveSleepEntries();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Slept for ${formatDuration(active.duration!)}')),
    );
  }

  Future<void> _editSleep(SleepEntry entry) async {
    final updated = await _showSleepForm(existingEntry: entry);
    if (updated == null) return;
    setState(() {
      entry.start = updated.start;
      entry.end = updated.end;
      entry.notes = updated.notes;
      _sleepEntries.sort((a, b) => a.start.compareTo(b.start));
    });
    _updateSleepTicker();
    await _saveSleepEntries();
  }

  Future<void> _deleteSleep(SleepEntry entry) async {
    setState(() {
      _sleepEntries.removeWhere((e) => e.id == entry.id);
    });
    _updateSleepTicker();
    await _saveSleepEntries();
  }

  Future<void> _recordFeed() async {
    final entry = await showFeedingEntryForm(context);
    if (entry == null) return;

    setState(() {
      _entries.add(entry);
      _entries.sort((a, b) => a.time.compareTo(b.time));
    });
    await _saveEntries();
    final nextReminder = entry.time.add(_reminderInterval);
    await NotificationService.cancelReminder();
    await NotificationService.scheduleFeedReminder(nextReminder);
    await _updateHomeWidget();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feeding time recorded and reminder set.')),
    );
  }

  Future<void> _updateReminderInterval(Duration interval) async {
    setState(() {
      _reminderInterval = interval;
    });
    await _saveInterval();
    if (_entries.isNotEmpty) {
      final lastTime = _entries.last.time;
      await NotificationService.cancelReminder();
      await NotificationService.scheduleFeedReminder(lastTime.add(_reminderInterval));
    }
    await _updateHomeWidget();
  }

  /// Shared hours/minutes picker dialog used for both the feed and diaper
  /// reminder intervals; [onSave] is only invoked once the entered duration
  /// validates.
  Future<void> _pickInterval({
    required String dialogTitle,
    required Duration current,
    required Future<void> Function(Duration) onSave,
  }) async {
    final hoursController = TextEditingController(text: current.inHours.toString());
    final minutesController = TextEditingController(text: (current.inMinutes % 60).toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(dialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hoursController,
                decoration: const InputDecoration(labelText: 'Hours'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minutesController,
                decoration: const InputDecoration(labelText: 'Minutes'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
          ],
        );
      },
    );

    if (result != true) return;
    final hours = int.tryParse(hoursController.text) ?? 0;
    final minutes = int.tryParse(minutesController.text) ?? 0;
    final newDuration = Duration(hours: hours, minutes: minutes);
    if (newDuration.inMinutes < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interval must be at least 1 minute.')),
      );
      return;
    }
    await onSave(newDuration);
  }

  Future<void> _pickReminderInterval() => _pickInterval(
        dialogTitle: 'Set reminder interval',
        current: _reminderInterval,
        onSave: _updateReminderInterval,
      );

  Future<void> _pickDiaperReminderInterval() => _pickInterval(
        dialogTitle: 'Set diaper reminder interval',
        current: _diaperReminderInterval,
        onSave: _updateDiaperReminderInterval,
      );

  /// Shared date-range picker for the filter bars. Returns null when the user
  /// backs out, so callers leave their current range untouched.
  Future<DateTimeRange?> _pickDateRange(DateTimeRange? initial) {
    return showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: initial,
    );
  }

  /// Jumps the Sleep tab straight to the week containing a picked date,
  /// instead of stepping there one week at a time with the arrows.
  Future<void> _pickSleepWeek() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _sleepWeekStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    if (!mounted) return;
    setState(() => _sleepWeekStart = _startOfWeek(selected));
  }

  /// The quick-filter presets offered above the feedings and diapers lists.
  /// Ranges are built from bare dates because [filterEntriesForRange] widens
  /// them to whole days.
  List<({String label, DateTimeRange range})> _filterPresets() {
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

  bool _isPresetActive(DateTimeRange preset, DateTimeRange? active) {
    if (active == null) return false;
    return startOfDay(active.start) == preset.start &&
        startOfDay(active.end) == preset.end;
  }

  /// Shows a snackbar for the outcomes of [exportReportToPdf] that need one.
  /// A successful share or a share sheet the user backed out of already got
  /// their own feedback from the OS, so only the empty-data and failure
  /// cases need a message from us.
  void _handleExportResult(ReportExportResult result, String noDataMessage) {
    if (!mounted) return;
    switch (result) {
      case ReportExportResult.noData:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(noDataMessage)));
      case ReportExportResult.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sharing isn\'t available on this device.')),
        );
      case ReportExportResult.shared:
      case ReportExportResult.cancelled:
        break;
    }
  }

  Future<void> _exportSelectedRange() async {
    if (_entries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no feedings to export.')),
      );
      return;
    }

    // When a range is already on screen, export exactly that instead of asking
    // the user to pick the same dates a second time.
    final selectedRange = _filterRange ?? await _pickDateRange(null);
    if (selectedRange == null) return;
    if (!mounted) return;

    try {
      final result = await exportReportToPdf(
        sections: {ReportSection.feedings},
        range: selectedRange,
        feedings: _entries,
      );
      _handleExportResult(result, 'No feedings were found for the selected range.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t export PDF: $e')),
      );
    }
  }

  Future<void> _exportDiaperSelectedRange() async {
    if (_diaperEntries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are no diaper changes to export.')),
      );
      return;
    }

    final selectedRange = _diaperFilterRange ?? await _pickDateRange(null);
    if (selectedRange == null) return;
    if (!mounted) return;

    try {
      final result = await exportReportToPdf(
        sections: {ReportSection.diapers},
        range: selectedRange,
        diaperEntries: _diaperEntries,
      );
      _handleExportResult(result, 'No diaper changes were found for the selected range.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t export PDF: $e')),
      );
    }
  }

  /// Exports the sleep sessions for the week currently shown on the Sleep
  /// tab — that page browses by week rather than an arbitrary range, so the
  /// export follows the same concept instead of adding a second range picker.
  Future<void> _exportSleepWeek() async {
    if (_sleepEntries.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There is no sleep data to export.')),
      );
      return;
    }

    final weekStart = _sleepWeekStart;
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    try {
      final result = await exportReportToPdf(
        sections: {ReportSection.sleep},
        range: DateTimeRange(start: weekStart, end: weekEnd),
        sleepEntries: _sleepEntries,
      );
      _handleExportResult(result, 'No sleep sessions found for ${_formatWeekRange(weekStart)}.');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t export PDF: $e')),
      );
    }
  }

  Future<void> _editEntry(FeedingEntry entry) async {
    final updatedEntry = await showFeedingEntryForm(context, existingEntry: entry);
    if (updatedEntry == null) return;

    setState(() {
      entry.time = updatedEntry.time;
      entry.milkType = updatedEntry.milkType;
      entry.amount = updatedEntry.amount;
      entry.amountUnit = updatedEntry.amountUnit;
      entry.notes = updatedEntry.notes;
      _entries.sort((a, b) => a.time.compareTo(b.time));
    });
    await _saveEntries();
    if (_entries.isNotEmpty) {
      final lastTime = _entries.last.time;
      await NotificationService.cancelReminder();
      await NotificationService.scheduleFeedReminder(lastTime.add(_reminderInterval));
    }
    await _updateHomeWidget();
  }

  Future<void> _deleteEntry(FeedingEntry entry) async {
    setState(() {
      _entries.removeWhere((e) => e.id == entry.id);
    });
    await _saveEntries();
    if (_entries.isNotEmpty) {
      final lastTime = _entries.last.time;
      await NotificationService.cancelReminder();
      await NotificationService.scheduleFeedReminder(lastTime.add(_reminderInterval));
    } else {
      await NotificationService.cancelReminder();
    }
    await _updateHomeWidget();
  }

  List<FeedingEntry> get _filteredEntries {
    final range = _filterRange;
    if (range == null) return List.of(_entries);
    return filterEntriesForRange(_entries, range);
  }

  List<DiaperEntry> get _filteredDiaperEntries {
    final range = _diaperFilterRange;
    if (range == null) return List.of(_diaperEntries);
    return filterEntriesForRange(_diaperEntries, range);
  }

  String _formatFeedTime(DateTime time) {
    return DateFormat.yMMMd().add_jm().format(time);
  }

  /// 'Aug 3, 2026' for a single day, otherwise 'Jul 28 – Aug 3, 2026'.
  String _formatFilterRange(DateTimeRange range) {
    if (startOfDay(range.start) == startOfDay(range.end)) {
      return DateFormat.yMMMd().format(range.start);
    }
    return '${DateFormat('MMM d').format(range.start)} – ${DateFormat.yMMMd().format(range.end)}';
  }

  Future<SleepEntry?> _showSleepForm({SleepEntry? existingEntry}) async {
    final notesController = TextEditingController(text: existingEntry?.notes ?? '');
    DateTime start = existingEntry?.start ?? DateTime.now();
    DateTime? end = existingEntry?.end;

    final result = await showDialog<SleepEntry>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String? errorText;
            if (end != null && !end!.isAfter(start)) {
              errorText = 'End must be after start.';
            }
            return AlertDialog(
              title: Text(existingEntry == null ? 'Add Sleep' : 'Edit Sleep'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.bedtime),
                      onPressed: () async {
                        final picked = await pickDateTime(context, start);
                        if (picked == null) return;
                        setDialogState(() => start = picked);
                      },
                      label: Text('Start: ${DateFormat.yMMMd().add_jm().format(start)}'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.wb_sunny),
                      onPressed: () async {
                        final picked = await pickDateTime(context, end ?? start);
                        if (picked == null) return;
                        setDialogState(() => end = picked);
                      },
                      label: Text(end == null
                          ? 'End: still sleeping'
                          : 'End: ${DateFormat.yMMMd().add_jm().format(end!)}'),
                    ),
                    if (end != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setDialogState(() => end = null),
                          child: const Text('Clear end (mark ongoing)'),
                        ),
                      ),
                    if (errorText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        errorText,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Extra notes',
                        hintText: 'Optional details',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: errorText != null
                      ? null
                      : () {
                          final entry = SleepEntry(
                            id: existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch,
                            start: start,
                            end: end,
                            notes: notesController.text.trim(),
                          );
                          Navigator.of(context).pop(entry);
                        },
                  child: Text(existingEntry == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Future<DiaperEntry?> _showDiaperForm({DiaperEntry? existingEntry}) async {
    final notesController = TextEditingController(text: existingEntry?.notes ?? '');
    bool pee = existingEntry?.pee ?? false;
    bool poo = existingEntry?.poo ?? false;
    DateTime time = existingEntry?.time ?? DateTime.now();

    final result = await showDialog<DiaperEntry>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existingEntry == null ? 'Record Diaper Change' : 'Edit Diaper Change'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Pee'),
                      value: pee,
                      onChanged: (value) => setDialogState(() => pee = value ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Poo'),
                      value: poo,
                      onChanged: (value) => setDialogState(() => poo = value ?? false),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Leave both unchecked for a dry diaper change.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Extra notes',
                        hintText: 'Optional details',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () async {
                        final picked = await pickDateTime(context, time);
                        if (picked == null) return;
                        setDialogState(() => time = picked);
                      },
                      child: Text('Set date/time: ${DateFormat.yMMMd().add_jm().format(time)}'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final entry = DiaperEntry(
                      id: existingEntry?.id ?? DateTime.now().millisecondsSinceEpoch,
                      time: time,
                      pee: pee,
                      poo: poo,
                      notes: notesController.text.trim(),
                    );
                    Navigator.of(context).pop(entry);
                  },
                  child: Text(existingEntry == null ? 'Save' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );

    return result;
  }

  Widget _sectionTitle(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.baloo2(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sukoyaka'),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildHomePage(),
                _buildHistoryPage(),
                _buildSleepPage(),
                _buildDiaperPage(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Feedings'),
          NavigationDestination(icon: Icon(Icons.bedtime), label: 'Sleep'),
          NavigationDestination(icon: Icon(Icons.baby_changing_station), label: 'Diapers'),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_selectedIndex == 1) {
      return FloatingActionButton.extended(
        onPressed: _recordFeed,
        icon: const Icon(Icons.local_cafe),
        label: const Text('Record Feeding'),
      );
    }
    if (_selectedIndex == 2) {
      return FloatingActionButton.extended(
        onPressed: _addSleepManually,
        icon: const Icon(Icons.add),
        label: const Text('Add Sleep'),
      );
    }
    if (_selectedIndex == 3) {
      return FloatingActionButton.extended(
        onPressed: _recordDiaper,
        icon: const Icon(Icons.add),
        label: const Text('Record Change'),
      );
    }
    return null;
  }

  Widget _buildHomePage() {
    final lastEntry = _entries.isEmpty ? null : _entries.last;
    final lastFeed = lastEntry?.time;
    final nextReminder = lastFeed?.add(_reminderInterval);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle(Icons.local_drink, 'Last feeding'),
                  const SizedBox(height: 12),
                  Text(
                    lastFeed == null ? 'No feeding recorded yet' : _formatFeedTime(lastFeed),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (lastEntry != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Milk type: ${lastEntry.milkType}', style: Theme.of(context).textTheme.bodyLarge),
                              if (lastEntry.amount != null)
                                Text('Amount: ${lastEntry.amount} ${lastEntry.amountUnit}', style: Theme.of(context).textTheme.bodyLarge),
                              if (lastEntry.notes.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text('Notes:', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(lastEntry.notes, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit last feeding',
                          onPressed: () => _editEntry(lastEntry),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  _sectionTitle(Icons.schedule, 'Reminder interval'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: Text(formatInterval(_reminderInterval), style: Theme.of(context).textTheme.bodyLarge)),
                      TextButton(onPressed: _pickReminderInterval, child: const Text('Change')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle(Icons.notifications, 'Next reminder'),
                  const SizedBox(height: 12),
                  Text(
                    nextReminder == null ? 'Record a feeding to set the next reminder' : _formatFeedTime(nextReminder),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _recordFeed,
                    icon: const Icon(Icons.local_cafe),
                    label: const Text('Mark feeding now'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildSleepCard(),
          const SizedBox(height: 16),
          _buildDiaperCard(),
          const SizedBox(height: 16),
          _buildGrowthCard(),
          const SizedBox(height: 16),
          Text(
            'Peek at the Feedings, Sleep, or Diapers tabs to review, edit, or delete past records.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSleepCard() {
    final active = _activeSleep;
    final finished = _sleepEntries.where((e) => !e.isInProgress).toList();
    final lastFinished = finished.isEmpty ? null : finished.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(Icons.bedtime, 'Sleep'),
            const SizedBox(height: 12),
            if (active != null) ...[
              Text(
                'Sleeping since ${_formatFeedTime(active.start)}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                formatDuration(DateTime.now().difference(active.start)),
                style: GoogleFonts.baloo2(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _stopSleep,
                icon: const Icon(Icons.wb_sunny),
                label: const Text('Wake up'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
            ] else ...[
              Text(
                lastFinished == null
                    ? 'No sleep recorded yet'
                    : 'Last slept ${formatDuration(lastFinished.duration!)} '
                        '(ended ${_formatFeedTime(lastFinished.end!)})',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _startSleep,
                icon: const Icon(Icons.bedtime),
                label: const Text('Start sleep'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addSleepManually,
              icon: const Icon(Icons.edit_calendar),
              label: const Text('Add sleep manually'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepPage() {
    final weekStart = _sleepWeekStart;
    final weekEndExclusive = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final now = DateTime.now();
    final canGoNext = weekStart.isBefore(_startOfWeek(now));

    // Sessions overlapping the selected week, most recent first. A session is
    // "in" the week if it started before the week ends and (for finished
    // sessions) ended after the week began, matching how WeeklySleepChart
    // clips sessions to each day's bar.
    final entries = _sleepEntries.where((entry) {
      final effectiveEnd = entry.end ?? now;
      return entry.start.isBefore(weekEndExclusive) && effectiveEnd.isAfter(weekStart);
    }).toList().reversed.toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildSleepWeekHeader(canGoNext),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: WeeklySleepChart(
                  weekStart: _sleepWeekStart,
                  entries: _sleepEntries,
                  now: now,
                  onTapEntry: _editSleep,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
            ],
          ),
        ),
        if (entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.bedtime,
              message: _sleepEntries.isEmpty
                  ? 'No sleep sessions yet!\nTap Start sleep on the Home tab, or Add Sleep here.'
                  : 'No sleep sessions for ${_formatWeekRange(weekStart)}.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: entries.length,
              separatorBuilder: (context, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final inProgress = entry.isInProgress;
                final durationLabel = inProgress
                    ? '${formatDuration(DateTime.now().difference(entry.start))} (ongoing)'
                    : formatDuration(entry.duration!);
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                      child: Icon(inProgress ? Icons.nightlight : Icons.bedtime),
                    ),
                    title: Text(
                      durationLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inProgress
                            ? 'Started ${_formatFeedTime(entry.start)}'
                            : '${_formatFeedTime(entry.start)} → ${_formatFeedTime(entry.end!)}'),
                        if (entry.notes.isNotEmpty) Text(entry.notes),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editSleep(entry),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteSleep(entry),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  /// 'Jul 28 – Aug 3' for the Monday-starting week beginning on [weekStart].
  String _formatWeekRange(DateTime weekStart) {
    final weekEnd = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
    return '${DateFormat('MMM d').format(weekStart)} – ${DateFormat('MMM d').format(weekEnd)}';
  }

  Widget _buildSleepWeekHeader(bool canGoNext) {
    final rangeLabel = _formatWeekRange(_sleepWeekStart);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => setState(() {
              _sleepWeekStart = DateTime(
                _sleepWeekStart.year,
                _sleepWeekStart.month,
                _sleepWeekStart.day - 7,
              );
            }),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous week',
          ),
          Expanded(
            child: InkWell(
              onTap: _pickSleepWeek,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Text(
                      rangeLabel,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (!canGoNext)
                      Text(
                        'This week',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext
                ? () => setState(() {
                      _sleepWeekStart = DateTime(
                        _sleepWeekStart.year,
                        _sleepWeekStart.month,
                        _sleepWeekStart.day + 7,
                      );
                    })
                : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next week',
          ),
          IconButton(
            onPressed: _exportSleepWeek,
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export this week to PDF',
          ),
        ],
      ),
    );
  }

  Widget _buildDiaperCard() {
    final lastDiaper = _diaperEntries.isEmpty ? null : _diaperEntries.last;
    final nextDiaperReminder = lastDiaper?.time.add(_diaperReminderInterval);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(Icons.baby_changing_station, 'Diaper change'),
            const SizedBox(height: 12),
            Text(
              lastDiaper == null
                  ? 'No diaper changes recorded yet'
                  : '${lastDiaper.contentsLabel} • ${_formatFeedTime(lastDiaper.time)}',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            if (lastDiaper != null && lastDiaper.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(lastDiaper.notes, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 20),
            _sectionTitle(Icons.schedule, 'Diaper reminder'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              value: _diaperReminderEnabled,
              onChanged: _setDiaperReminderEnabled,
            ),
            if (_diaperReminderEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(formatInterval(_diaperReminderInterval), style: Theme.of(context).textTheme.bodyLarge),
                  ),
                  TextButton(onPressed: _pickDiaperReminderInterval, child: const Text('Change')),
                ],
              ),
              const SizedBox(height: 20),
              _sectionTitle(Icons.notifications, 'Next reminder'),
              const SizedBox(height: 12),
              Text(
                nextDiaperReminder == null
                    ? 'Record a diaper change to set the next reminder'
                    : _formatFeedTime(nextDiaperReminder),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _recordDiaper,
              icon: const Icon(Icons.baby_changing_station),
              label: const Text('Record diaper change'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthCard() {
    final last = _growthEntries.isEmpty ? null : _growthEntries.last;
    final summary = last == null
        ? 'No measurements recorded yet'
        : '${[
            if (last.weight != null) 'Weight: ${last.weight} ${last.weightUnit}',
            if (last.height != null) 'Height: ${last.height} ${last.heightUnit}',
          ].join(' • ')} • ${_formatFeedTime(last.time)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(Icons.monitor_weight, 'Growth'),
            const SizedBox(height: 12),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openGrowthScreen,
              icon: const Icon(Icons.timeline),
              label: const Text('View growth chart'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiaperPage() {
    final entries = _filteredDiaperEntries;
    return Column(
      children: [
        _buildRangeFilterBar(
          range: _diaperFilterRange,
          onChanged: (range) => setState(() => _diaperFilterRange = range),
          actions: [
            IconButton(
              onPressed: _exportDiaperSelectedRange,
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export selected range to PDF',
            ),
          ],
        ),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: _diaperFilterRange == null ? Icons.baby_changing_station : Icons.search,
                  message: _diaperFilterRange == null
                      ? 'No diaper changes yet!\nTap Record Change to add one.'
                      : 'No records found for ${_formatFilterRange(_diaperFilterRange!)}.',
                )
              : _buildGroupedDiaperList(entries),
        ),
      ],
    );
  }

  /// Diaper changes bucketed under a header per calendar day, newest day first.
  /// Rows show only the time of day because the header carries the date.
  Widget _buildGroupedDiaperList(List<DiaperEntry> entries) {
    // Flattened so the list stays lazily built: each item is either an
    // EntryDay header or one of that day's entries.
    final items = <Object>[];
    for (final day in groupEntriesByDay(entries)) {
      items.add(day);
      items.addAll(day.entries);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is DiaperEntry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildDiaperTile(item),
          );
        }
        return _buildDiaperDayHeader(
          item as EntryDay<DiaperEntry>,
          isFirst: index == 0,
        );
      },
    );
  }

  Widget _buildDiaperDayHeader(EntryDay<DiaperEntry> group, {required bool isFirst}) {
    final count = group.entries.length;
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 8, bottom: 8, left: 4),
      child: Text(
        '${DateFormat.yMMMd().format(group.day)} · $count ${count == 1 ? 'change' : 'changes'}',
        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDiaperTile(DiaperEntry entry) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
          child: const Icon(Icons.baby_changing_station),
        ),
        title: Text(
          entry.contentsLabel,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat.jm().format(entry.time)),
            if (entry.notes.isNotEmpty) Text(entry.notes),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editDiaper(entry),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteDiaper(entry),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }

  /// The date-range button, quick-filter chips and clear button shared by the
  /// feedings and diapers histories. [actions] are extra buttons placed between
  /// the range button and the clear button.
  Widget _buildRangeFilterBar({
    required DateTimeRange? range,
    required ValueChanged<DateTimeRange?> onChanged,
    List<Widget> actions = const [],
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await _pickDateRange(range);
                    if (selected == null) return;
                    onChanged(selected);
                  },
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    range == null
                        ? 'Filter by date range'
                        : _formatFilterRange(range),
                  ),
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
              for (final preset in _filterPresets())
                FilterChip(
                  label: Text(preset.label),
                  selected: _isPresetActive(preset.range, range),
                  onSelected: (selected) =>
                      onChanged(selected ? preset.range : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryPage() {
    final entries = _filteredEntries;
    return Column(
      children: [
        _buildRangeFilterBar(
          range: _filterRange,
          onChanged: (range) => setState(() => _filterRange = range),
          actions: [
            IconButton(
              onPressed: _exportSelectedRange,
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export selected range to PDF',
            ),
          ],
        ),
        Expanded(
          child: entries.isEmpty
              ? EmptyState(
                  icon: _filterRange == null ? Icons.local_drink : Icons.search,
                  message: _filterRange == null
                      ? 'No feedings yet!\nTap Record Feeding to add one.'
                      : 'No records found for ${_formatFilterRange(_filterRange!)}.',
                )
              : _buildGroupedFeedingList(entries),
        ),
      ],
    );
  }

  /// Feedings bucketed under a header per calendar day, newest day first. Rows
  /// show only the time of day because the header carries the date.
  Widget _buildGroupedFeedingList(List<FeedingEntry> entries) {
    // Flattened so the list stays lazily built: each item is either a
    // FeedingDay header or one of that day's entries.
    final items = <Object>[];
    for (final day in groupEntriesByDay(entries)) {
      items.add(day);
      items.addAll(day.entries);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item is FeedingEntry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFeedingCard(item),
          );
        }
        return _buildFeedingDayHeader(item as FeedingDay, isFirst: index == 0);
      },
    );
  }

  Widget _buildFeedingDayHeader(FeedingDay group, {required bool isFirst}) {
    final count = group.entries.length;
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 8, bottom: 8, left: 4),
      child: Text(
        '${DateFormat.yMMMd().format(group.day)} · $count ${count == 1 ? 'feeding' : 'feedings'}',
        style: GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildFeedingCard(FeedingEntry entry) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
          child: const Icon(Icons.local_drink),
        ),
        title: Text(
          DateFormat.jm().format(entry.time),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.milkType}${entry.amount != null ? ' • ${entry.amount} ${entry.amountUnit}' : ''}'),
            if (entry.notes.isNotEmpty) Text(entry.notes),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editEntry(entry),
              tooltip: 'Edit',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deleteEntry(entry),
              tooltip: 'Delete',
            ),
          ],
        ),
      ),
    );
  }
}
