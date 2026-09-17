import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import 'feeding_entry.dart';

/// Pushes the latest feeding summary to the Android home-screen widget.
/// No-ops on platforms without a widget (e.g. web), which is fine since
/// `home_widget` simply isn't backed by a provider there.
Future<void> syncHomeWidget(List<FeedingEntry> entries, Duration reminderInterval) async {
  try {
    if (entries.isEmpty) {
      await HomeWidget.saveWidgetData<String>('last_fed_text', 'No feedings logged yet');
      await HomeWidget.saveWidgetData<String>('next_due_text', '');
    } else {
      final lastTime = entries.last.time;
      final nextDue = lastTime.add(reminderInterval);
      await HomeWidget.saveWidgetData<String>(
        'last_fed_text',
        'Last fed: ${DateFormat.jm().format(lastTime)}',
      );
      await HomeWidget.saveWidgetData<String>(
        'next_due_text',
        'Next feed: ${DateFormat.jm().format(nextDue)}',
      );
    }
    await HomeWidget.updateWidget(androidName: 'FeedingWidgetProvider');
  } catch (e) {
    debugPrint('syncHomeWidget() error: $e');
  }
}
