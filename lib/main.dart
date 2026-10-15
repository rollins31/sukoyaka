import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_store.dart';
import 'app_theme.dart';
import 'diapers_page.dart';
import 'entry_actions.dart';
import 'feedings_page.dart';
import 'growth_screen.dart';
import 'home_layout.dart';
import 'home_page.dart';
import 'notification_service.dart';
import 'quick_log_screen.dart';
import 'settings_screen.dart';
import 'sleep_page.dart';

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
  static const _growthTab = 4;

  final _store = AppStore();
  int _selectedIndex = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_onStoreChanged);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store
      ..removeListener(_onStoreChanged)
      ..dispose();
    super.dispose();
  }

  /// Picks up entries logged from the widget's quick-log popup (a separate
  /// process) while this app was backgrounded.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
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

  Future<void> _openSettings() => Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => SettingsScreen(store: _store)),
      );

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
                HomePage(
                  store: _store,
                  onViewGrowthChart: () => setState(() => _selectedIndex = _growthTab),
                ),
                FeedingsPage(store: _store),
                SleepPage(store: _store),
                DiapersPage(store: _store),
                GrowthPage(
                  entries: _store.growth,
                  onEdit: (entry) => editGrowth(context, _store, entry),
                  onDelete: _store.deleteGrowth,
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
    final (icon, label, onPressed) = switch (_selectedIndex) {
      1 => (Icons.local_cafe, 'Record Feeding', () => recordFeeding(context, _store)),
      2 => (Icons.add, 'Add Sleep', () => addSleepManually(context, _store)),
      3 => (Icons.add, 'Record Change', () => recordDiaper(context, _store)),
      _growthTab => (Icons.add, 'Add Measurement', () => addGrowth(context, _store)),
      _ => (null, null, null),
    };
    if (onPressed == null) return null;
    return FloatingActionButton.extended(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label!),
    );
  }
}
