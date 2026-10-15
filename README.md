# Sukoyaka

A baby tracker for feedings, sleep, diaper changes and growth, with reminders and an Android home-screen widget. Everything is stored on the device; there's no account or server.

## Features

- **Feedings:** milk type, amount (ml/oz) and notes, with a repeating feed reminder at an interval you choose.
- **Sleep:** a live timer started from the Home tab, or sessions added afterwards, shown as a weekly chart.
- **Diapers:** pee/poo/dry changes, with their own optional reminder.
- **Growth:** weight and height measurements with a chart (kg/lb, cm/in).
- **Home tab:** a summary card per category, which you can reorder and hide.
- **History tabs:** entries grouped by day, filtered by date range, each exportable as a PDF report.
- **Backup and restore:** export everything to a `.json` file and restore it on any device.
- **Home-screen widget (Android):** shows the last feeding and when the next is due, with quick-log buttons for a feeding, sleep or diaper change.
- **Light, dark and system themes**, with bundled fonts (no network fetch).

## Getting started

Requires the Flutter SDK with Dart `^3.12.0`.

```sh
flutter pub get
flutter run            # on a connected device or emulator
flutter test
flutter analyze
```

Android is the main target and the only platform with the home-screen widget (see below).

## How the code is organized

All code is in `lib/`, as flat files:

| Area | Files |
|---|---|
| App entry, theme | `main.dart` (app shell, tabs, FABs), `app_theme.dart` |
| Data and persistence | `app_store.dart`, `entry_storage.dart`, `app_storage_keys.dart`, the models (`feeding_entry.dart`, `sleep_entry.dart`, `diaper_entry.dart`, `growth_entry.dart`) |
| Home tab | `home_page.dart`, `home_cards.dart`, `home_layout.dart`, `home_layout_screen.dart` |
| History tabs | `feedings_page.dart`, `sleep_page.dart` (+ `weekly_sleep_chart.dart`), `diapers_page.dart`, `growth_screen.dart` (+ `growth_chart.dart`, `date_axis.dart`) |
| Entry forms | `*_entry_form.dart`, with the shared form-then-save flows in `entry_actions.dart` |
| Shared UI and helpers | `date_range_filter_bar.dart`, `section_title.dart`, `empty_state.dart`, `sleep_ticker.dart`, `feeding_filters.dart` (date filtering, grouping, formatting), `duration_format.dart` |
| Reminders and widget | `notification_service.dart`, `home_widget_sync.dart`, `quick_log_screen.dart` |
| Settings, reports, backup | `settings_screen.dart`, `pdf_export.dart`, `export_result_snackbar.dart`, `backup_data.dart`, `backup_service.dart`, `privacy_policy_screen.dart` |

### Data flow

`AppStore` (a plain `ChangeNotifier`) owns all four logs and both reminder settings. Every change goes through it, and it:

1. updates the list in memory, keeps it sorted oldest first, and notifies listeners so the UI updates immediately;
2. saves the list to SharedPreferences as JSON, under the keys in `app_storage_keys.dart`;
3. reschedules the affected reminder (feed or diaper), always from the *latest* entry;
4. refreshes the home-screen widget after feeding changes.

`FeedingHome` in `main.dart` creates the store and passes it to each tab. The store is deliberately not a global, so widget tests start from a fresh one.

The storage keys are what's saved on users' devices. Renaming one orphans existing data.

## Home-screen widget (Android)

Built with the [`home_widget`](https://pub.dev/packages/home_widget) package:

- `android/app/src/main/res/layout/feeding_widget_layout.xml` and `res/xml/feeding_widget_info.xml`: the widget layout. Its colors come from `res/values/colors.xml`, with dark-mode overrides in `res/values-night/colors.xml`.
- `android/app/src/main/kotlin/com/rollins/sukoyaka/FeedingWidgetProvider.kt`: renders it and wires the buttons. It's registered as a receiver in `AndroidManifest.xml`.
- `syncHomeWidget()` in `lib/home_widget_sync.dart` pushes the last feeding and next-due time. `AppStore` calls it whenever feedings or the feed reminder change.

Tapping the info area opens the app. Each quick-log button (Feed, Sleep, Diaper) opens `QuickLogActivity`, a small floating popup. It shows the same entry form as the app, on the route `/quickLog/<feeding|sleep|diaper>`. The popup runs in its own Flutter engine. It loads an `AppStore`, adds the entry and closes, so it follows the same storage and reminder rules as the app. When the main app resumes, it reloads from SharedPreferences (`didChangeAppLifecycleState` in `lib/main.dart`) to pick up anything logged this way.

The popup is a per-`Activity` initial route (`QuickLogActivity.getInitialRoute()`) on the app's one normal Dart entrypoint. It deliberately does *not* use Flutter's custom named-entrypoint mechanism (`getDartEntrypointFunctionName`). That API reliably fails with "Could not resolve main entrypoint function" in a plain single-module `flutter build apk` project, because it's meant for add-to-app/AAR builds with a separately compiled module. Don't reach for it here.

**iOS** has no widget yet. A native iOS widget needs a Widget Extension target added in Xcode, which can't be scaffolded from Dart or the CLI alone.

## Privacy policy

The canonical text is in `lib/privacy_policy_screen.dart` (shown under Settings). It's also published from `docs/index.html` at <https://rollins31.github.io/sukoyaka/> for the store listings. Keep the two in sync.
