import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'app_store.dart';
import 'app_theme.dart';
import 'backup_data.dart';
import 'diaper_entry.dart';
import 'diaper_entry_form.dart';
import 'duration_format.dart';
import 'empty_state.dart';
import 'feeding_entry.dart';
import 'feeding_entry_form.dart';
import 'feeding_filters.dart';
import 'growth_entry.dart';
import 'growth_entry_form.dart';
import 'growth_screen.dart';
import 'home_layout.dart';
import 'home_layout_screen.dart';
import 'notification_service.dart';
import 'pdf_export.dart';
import 'quick_log_screen.dart';
import 'settings_screen.dart';
import 'sleep_entry.dart';
import 'sleep_entry_form.dart';
import 'weekly_sleep_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled under assets/google_fonts/, so never fall back to
  // fetching them from Google at runtime.
  GoogleFonts.config.allowRuntimeFetching = false;
  registerFontLicenses();
  try {
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('NotificationService.initialize() error: $e');
  }
  await loadThemeMode();
  await loadHomeLayout();
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = buildLightTheme();
    final darkTheme = buildDarkTheme();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Sukoyaka',
          themeMode: mode,
          theme: lightTheme,
          darkTheme: darkTheme,
          routes: {
            '/': (context) => const FeedingHome(),
            '/quickLog/feeding': (context) => const QuickLogScreen(type: QuickLogType.feeding),
            '/quickLog/sleep': (context) => const QuickLogScreen(type: QuickLogType.sleep),
            '/quickLog/diaper': (context) => const QuickLogScreen(type: QuickLogType.diaper),
          },
        );
      },
    );
  }
}

class FeedingHome extends StatefulWidget {
  const FeedingHome({super.key});

  @override
  State<FeedingHome> createState() => _FeedingHomeState();
}

class _FeedingHomeState extends State<FeedingHome> with WidgetsBindingObserver {
  final _store = AppStore();
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
    _store.addListener(_onStoreChanged);
    _sleepWeekStart = _startOfWeek(DateTime.now());
    // Default both histories to a recent window so a long-lived log doesn't
    // dump months of entries on screen until the user asks for more.
    final defaultRange = _filterPresets()
        .firstWhere((preset) => preset.label == 'Last 7 days')
        .range;
    _filterRange = defaultRange;
    _diaperFilterRange = defaultRange;
    _loadData();
  }

  /// Local midnight of the Monday that begins the week containing [date].
  DateTime _startOfWeek(DateTime date) {
    return DateTime(date.year, date.month, date.day - (date.weekday - 1));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store
      ..removeListener(_onStoreChanged)
      ..dispose();
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

  void _onStoreChanged() {
    if (!mounted) return;
    setState(() {});
    _updateSleepTicker();
  }

  /// Keeps a 1-second ticker running only while a sleep session is active, so
  /// the live elapsed duration on the Home tab stays current.
  void _updateSleepTicker() {
    if (_store.activeSleep != null) {
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
      await _store.load();
    } catch (e) {
      debugPrint('_loadData() error: $e');
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = false);
    await _store.syncReminders();
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          feedings: List.of(_store.feedings),
          sleepEntries: List.of(_store.sleeps),
          diaperEntries: List.of(_store.diapers),
          feedReminderEnabled: _store.feedReminderEnabled,
          reminderInterval: _store.feedReminderInterval,
          diaperReminderEnabled: _store.diaperReminderEnabled,
          diaperReminderInterval: _store.diaperReminderInterval,
          growthEntries: List.of(_store.growth),
          onRestore: _restoreFromBackup,
        ),
      ),
    );
  }

  Future<void> _addGrowth() async {
    final entry = await showGrowthEntryForm(context);
    if (entry == null) return;
    await _store.addGrowth(entry);
  }

  Future<void> _editGrowth(GrowthEntry entry) async {
    final updated = await showGrowthEntryForm(context, existingEntry: entry);
    if (updated == null) return;
    await _store.updateGrowth(updated);
  }

  Future<void> _deleteGrowth(GrowthEntry entry) => _store.deleteGrowth(entry);

  Future<void> _openHomeLayout() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const HomeLayoutScreen()),
    );
  }

  /// Replaces all locally stored data with the contents of [backup],
  /// persists it, and reschedules reminders to match.
  Future<void> _restoreFromBackup(AppBackup backup) async {
    await _store.restore(backup);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup restored.')),
    );
  }

  Future<void> _recordDiaper() async {
    final entry = await showDiaperEntryForm(context);
    if (entry == null) return;
    await _store.addDiaper(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diaper change recorded')),
    );
  }

  Future<void> _editDiaper(DiaperEntry entry) async {
    final updated = await showDiaperEntryForm(context, existingEntry: entry);
    if (updated == null) return;
    await _store.updateDiaper(updated);
  }

  Future<void> _deleteDiaper(DiaperEntry entry) => _store.deleteDiaper(entry);

  Future<void> _startSleep() async {
    if (await _store.startSleep() == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sleep started')),
    );
  }

  /// Adds a sleep session via the form (start/end pickers) rather than the
  /// live timer, for logging periods after the fact.
  Future<void> _addSleepManually() async {
    final entry = await showSleepEntryForm(context);
    if (entry == null) return;
    await _store.addSleep(entry);
  }

  Future<void> _stopSleep() async {
    final stopped = await _store.stopSleep();
    if (stopped == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Slept for ${formatDuration(stopped.duration!)}')),
    );
  }

  Future<void> _editSleep(SleepEntry entry) async {
    final updated = await showSleepEntryForm(context, existingEntry: entry);
    if (updated == null) return;
    await _store.updateSleep(updated);
  }

  Future<void> _deleteSleep(SleepEntry entry) => _store.deleteSleep(entry);

  Future<void> _recordFeed() async {
    final entry = await showFeedingEntryForm(context);
    if (entry == null) return;
    await _store.addFeeding(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_store.feedReminderEnabled ? 'Feeding time recorded and reminder set.' : 'Feeding time recorded'),
      ),
    );
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
        current: _store.feedReminderInterval,
        onSave: (interval) => _store.setFeedReminder(interval: interval),
      );

  Future<void> _pickDiaperReminderInterval() => _pickInterval(
        dialogTitle: 'Set diaper reminder interval',
        current: _store.diaperReminderInterval,
        onSave: (interval) => _store.setDiaperReminder(interval: interval),
      );

  /// Shared date-range picker for the filter bars. Returns null when the user
  /// backs out, so callers leave their current range untouched.
  Future<DateTimeRange?> _pickDateRange(DateTimeRange? initial) {
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

  /// Jumps the Sleep tab straight to the week containing a picked date,
  /// instead of stepping there one week at a time with the arrows.
  Future<void> _pickSleepWeek() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _sleepWeekStart,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
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
    if (_store.feedings.isEmpty) {
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
        feedings: _store.feedings,
      );
      _handleExportResult(result, 'No feedings were found for the selected range.');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t export PDF. Please try again.')),
      );
    }
  }

  Future<void> _exportDiaperSelectedRange() async {
    if (_store.diapers.isEmpty) {
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
        diaperEntries: _store.diapers,
      );
      _handleExportResult(result, 'No diaper changes were found for the selected range.');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t export PDF. Please try again.')),
      );
    }
  }

  /// Exports the sleep sessions for the week currently shown on the Sleep
  /// tab — that page browses by week rather than an arbitrary range, so the
  /// export follows the same concept instead of adding a second range picker.
  Future<void> _exportSleepWeek() async {
    if (_store.sleeps.isEmpty) {
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
        sleepEntries: _store.sleeps,
      );
      _handleExportResult(result, 'No sleep sessions found for ${_formatWeekRange(weekStart)}.');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\'t export PDF. Please try again.')),
      );
    }
  }

  Future<void> _editEntry(FeedingEntry entry) async {
    final updatedEntry = await showFeedingEntryForm(context, existingEntry: entry);
    if (updatedEntry == null) return;
    await _store.updateFeeding(updatedEntry);
  }

  Future<void> _deleteEntry(FeedingEntry entry) => _store.deleteFeeding(entry);

  List<FeedingEntry> get _filteredEntries {
    final range = _filterRange;
    if (range == null) return List.of(_store.feedings);
    return filterEntriesForRange(_store.feedings, range);
  }

  List<DiaperEntry> get _filteredDiaperEntries {
    final range = _diaperFilterRange;
    if (range == null) return List.of(_store.diapers);
    return filterEntriesForRange(_store.diapers, range);
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
                GrowthPage(
                  entries: _store.growth,
                  onEdit: _editGrowth,
                  onDelete: _deleteGrowth,
                ),
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
          NavigationDestination(icon: Icon(Icons.monitor_weight), label: 'Growth'),
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
    if (_selectedIndex == 4) {
      return FloatingActionButton.extended(
        onPressed: _addGrowth,
        icon: const Icon(Icons.add),
        label: const Text('Add Measurement'),
      );
    }
    return null;
  }

  Widget _buildHomePage() {
    return ValueListenableBuilder<HomeLayout>(
      valueListenable: homeLayoutNotifier,
      builder: (context, layout, _) {
        final cards = layout.visibleCards;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) ...[
                _buildHomeCard(card),
                const SizedBox(height: 16),
              ],
              if (cards.isEmpty) ...[
                Text(
                  'All Home cards are hidden.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Peek at the Feedings, Sleep, Diapers, or Growth tabs to review, edit, or delete past records.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _openHomeLayout,
                  icon: const Icon(Icons.dashboard_customize),
                  label: const Text('Customize home page'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeCard(HomeCard card) => switch (card) {
        HomeCard.feeding => _buildFeedingSummaryCard(),
        HomeCard.sleep => _buildSleepCard(),
        HomeCard.diaper => _buildDiaperCard(),
        HomeCard.growth => _buildGrowthCard(),
      };

  Widget _buildFeedingSummaryCard() {
    final lastEntry = _store.feedings.isEmpty ? null : _store.feedings.last;
    final lastFeed = lastEntry?.time;
    final nextReminder = lastFeed?.add(_store.feedReminderInterval);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(Icons.local_drink, 'Feeding'),
            const SizedBox(height: 12),
            Text(
              lastFeed == null ? 'No feeding recorded yet' : 'Last feeding: ${_formatFeedTime(lastFeed)}',
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
            _sectionTitle(Icons.schedule, 'Feeding reminder'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              value: _store.feedReminderEnabled,
              onChanged: (enabled) => _store.setFeedReminder(enabled: enabled),
            ),
            if (_store.feedReminderEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text(formatInterval(_store.feedReminderInterval), style: Theme.of(context).textTheme.bodyLarge)),
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
            ],
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
    );
  }

  Widget _buildSleepCard() {
    final active = _store.activeSleep;
    final finished = _store.sleeps.where((e) => !e.isInProgress).toList();
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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit current sleep',
                    onPressed: () => _editSleep(active),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _stopSleep,
                icon: const Icon(Icons.wb_sunny),
                label: const Text('Wake up'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18)),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lastFinished == null
                          ? 'No sleep recorded yet'
                          : 'Last slept ${formatDuration(lastFinished.duration!)} '
                              '(ended ${_formatFeedTime(lastFinished.end!)})',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                  if (lastFinished != null)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit last sleep',
                      onPressed: () => _editSleep(lastFinished),
                    ),
                ],
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
    final entries = _store.sleeps.where((entry) {
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
                  entries: _store.sleeps,
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
              message: _store.sleeps.isEmpty
                  ? 'No sleep sessions yet!\nTap Start sleep on the Home tab, or Add Sleep here.'
                  : 'No sleep sessions for ${_formatWeekRange(weekStart)}.',
            ),
          )
        else
          SliverPadding(
            // Extra bottom padding keeps the last card clear of the floating
            // "Add Sleep" button, which would otherwise sit on top of it.
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
    final lastDiaper = _store.diapers.isEmpty ? null : _store.diapers.last;
    final nextDiaperReminder = lastDiaper?.time.add(_store.diaperReminderInterval);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(Icons.baby_changing_station, 'Diaper change'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lastDiaper == null
                            ? 'No diaper changes recorded yet'
                            : 'Last change: ${_formatFeedTime(lastDiaper.time)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      if (lastDiaper != null) ...[
                        const SizedBox(height: 12),
                        Text('Contents: ${lastDiaper.contentsLabel}', style: Theme.of(context).textTheme.bodyLarge),
                      ],
                      if (lastDiaper != null && lastDiaper.notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(lastDiaper.notes, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                if (lastDiaper != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit last diaper change',
                    onPressed: () => _editDiaper(lastDiaper),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle(Icons.schedule, 'Diaper reminder'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Remind me'),
              value: _store.diaperReminderEnabled,
              onChanged: (enabled) => _store.setDiaperReminder(enabled: enabled),
            ),
            if (_store.diaperReminderEnabled) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(formatInterval(_store.diaperReminderInterval), style: Theme.of(context).textTheme.bodyLarge),
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
    final last = _store.growth.isEmpty ? null : _store.growth.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(Icons.monitor_weight, 'Growth'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        last == null ? 'No measurements recorded yet' : 'Last measured: ${_formatFeedTime(last.time)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      if (last != null) ...[
                        const SizedBox(height: 12),
                        if (last.weight != null)
                          Text('Weight: ${last.weight} ${last.weightUnit}', style: Theme.of(context).textTheme.bodyLarge),
                        if (last.height != null)
                          Text('Height: ${last.height} ${last.heightUnit}', style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ],
                  ),
                ),
                if (last != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit last measurement',
                    onPressed: () => _editGrowth(last),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => setState(() => _selectedIndex = 4),
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
      // Extra bottom padding keeps the last card clear of the floating
      // "Record Change" button, which would otherwise sit on top of it.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
      // Extra bottom padding keeps the last card clear of the floating
      // "Record Feeding" button, which would otherwise sit on top of it.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
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
