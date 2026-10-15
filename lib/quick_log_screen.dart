import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_store.dart';
import 'diaper_entry_form.dart';
import 'feeding_entry_form.dart';
import 'notification_service.dart';
import 'sleep_entry_form.dart';

const _closeChannel = MethodChannel('quick_log/close');

/// Which kind of entry the widget's quick-log popup was launched to record.
enum QuickLogType { feeding, sleep, diaper }

/// Root screen for the widget's quick-log popup. Reached via the
/// `/quickLog/<type>` routes on the app's normal `main()` entrypoint —
/// `QuickLogActivity` just launches a second engine with that initial route,
/// themed as a floating dialog rather than the full app, so this never needs
/// its own entrypoint.
class QuickLogScreen extends StatefulWidget {
  const QuickLogScreen({super.key, required this.type});

  final QuickLogType type;

  @override
  State<QuickLogScreen> createState() => _QuickLogScreenState();
}

class _QuickLogScreenState extends State<QuickLogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    switch (widget.type) {
      case QuickLogType.feeding:
        final entry = await showFeedingEntryForm(context);
        if (entry != null) await (await _loadStore()).addFeeding(entry);
      case QuickLogType.sleep:
        final entry = await showSleepEntryForm(context);
        if (entry != null) await (await _loadStore()).addSleep(entry);
      case QuickLogType.diaper:
        final entry = await showDiaperEntryForm(context);
        if (entry != null) await (await _loadStore()).addDiaper(entry);
    }
    await _closeChannel.invokeMethod('close');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(backgroundColor: Colors.transparent);
  }
}

/// The app's saved data, ready for one more entry. Saving through [AppStore]
/// keeps the popup's storage and reminder rules identical to the app's.
Future<AppStore> _loadStore() async {
  await NotificationService.initialize();
  final store = AppStore();
  await store.load();
  return store;
}
