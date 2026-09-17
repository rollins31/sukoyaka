# Sukoyaka

Baby feeding reminder app with core timing, reminders, and home-screen widget support.

## Widget Setup

- Android home-screen widget support is implemented via the `home_widget` package:
  - `android/app/src/main/res/layout/feeding_widget_layout.xml`
  - `android/app/src/main/res/xml/feeding_widget_info.xml`
  - `android/app/src/main/kotlin/com/rollins/sukoyaka/FeedingWidgetProvider.kt`
  - manifest receiver registration in `android/app/src/main/AndroidManifest.xml`
  - The widget shows the last feeding time and when the next feeding is due, refreshing whenever a feeding is logged, edited, or deleted (`syncHomeWidget()` in `lib/home_widget_sync.dart`), and tapping the info area opens the app.
  - A "+ Log" button on the widget opens a small floating popup (`QuickLogActivity` in Kotlin, routing to `QuickLogScreen` in `lib/quick_log_screen.dart` via the `/quickLog` route on the app's normal entrypoint) with the same feeding-entry form used in the app, so a feed can be recorded without opening the full app. The popup saves straight to shared preferences and updates the widget itself; the main app picks up anything logged this way as soon as it's resumed (`didChangeAppLifecycleState` in `lib/main.dart`).
  - This uses a per-`Activity` initial route (`QuickLogActivity.getInitialRoute()` → `/quickLog`) on the app's one normal Dart entrypoint, deliberately *not* Flutter's custom-named-entrypoint mechanism (`getDartEntrypointFunctionName`) — that API reliably fails with "Could not resolve main entrypoint function" in a plain single-module `flutter build apk` project (it's really meant for add-to-app/AAR builds with a separately compiled module), so don't reach for it here.
- iOS is not implemented yet. A native iOS home-screen widget requires adding a Widget Extension target in Xcode, which can't be scaffolded from Dart/CLI alone — this would be a follow-up.
