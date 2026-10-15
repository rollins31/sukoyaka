import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukoyaka/main.dart';

Future<void> _pumpHome(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: FeedingHome()));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows empty states and the default reminder interval when there is no data', (tester) async {
    await _pumpHome(tester);

    expect(find.text('No feeding recorded yet'), findsOneWidget);
    expect(find.text('3 hours'), findsOneWidget);
  });

  testWidgets('canceling Record Feeding leaves the home summary unchanged', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Mark feeding now'));
    await tester.pumpAndSettle();
    expect(find.text('Record Feeding'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('No feeding recorded yet'), findsOneWidget);
  });

  testWidgets('recording a feeding updates the home summary and persists it', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Mark feeding now'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('No feeding recorded yet'), findsNothing);
    expect(find.text('Milk type: Bottle'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('feeding_entries'), contains('Bottle'));
  });

  testWidgets('changing the reminder interval persists with no feedings logged', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(find.text('Set reminder interval'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.first, '5');
    await tester.enterText(fields.at(1), '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('5 hours'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('reminder_interval_minutes'), 300);
  });

  testWidgets('turning off the feeding reminder hides its interval and persists', (tester) async {
    await _pumpHome(tester);

    // The diaper card has its own "Remind me" switch further down the page.
    await tester.tap(find.widgetWithText(SwitchListTile, 'Remind me').first);
    await tester.pumpAndSettle();

    expect(find.text('3 hours'), findsNothing);
    expect(find.text('Change'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('feed_reminder_enabled'), isFalse);
  });

  // "Growth" alone also matches the Home card's heading.
  final growthTab = find.descendant(of: find.byType(NavigationBar), matching: find.text('Growth'));

  testWidgets('the Growth tab shows its empty state and Add Measurement button', (tester) async {
    await _pumpHome(tester);

    await tester.tap(growthTab);
    await tester.pumpAndSettle();

    expect(find.text('No measurements yet!\nTap Add Measurement to record one.'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Add Measurement'), findsOneWidget);
  });

  testWidgets('View growth chart on the Home card switches to the Growth tab', (tester) async {
    await _pumpHome(tester);

    await tester.scrollUntilVisible(find.text('View growth chart'), 200);
    await tester.tap(find.text('View growth chart'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FloatingActionButton, 'Add Measurement'), findsOneWidget);
  });

  testWidgets('deleting a measurement in the Growth tab updates the Home card', (tester) async {
    SharedPreferences.setMockInitialValues({
      'growth_entries': '[{"id": 1, "time": "2026-10-01T09:00:00.000", "weight": 6.5, "weightUnit": "kg"}]',
    });
    await _pumpHome(tester);
    await tester.scrollUntilVisible(find.textContaining('Last measured'), 200);

    await tester.tap(growthTab);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byTooltip('Delete'), 200);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('No measurements recorded yet'), 200);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('growth_entries'), '[]');
  });

  testWidgets('switching to the Feedings tab shows its own empty state', (tester) async {
    await _pumpHome(tester);

    await tester.tap(find.text('Feedings'));
    await tester.pumpAndSettle();

    // Feedings defaults to a "Last 7 days" filter, so with no entries at all
    // it shows the filtered-empty message rather than the true empty state.
    expect(find.textContaining('No records found for'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear filter'));
    await tester.pumpAndSettle();

    expect(find.text('No feedings yet!\nTap Record Feeding to add one.'), findsOneWidget);
  });

  testWidgets('a live sleep ticks on the Home card and stops on wake up', (tester) async {
    await _pumpHome(tester);

    await tester.scrollUntilVisible(find.text('Start sleep'), 200);
    await tester.tap(find.text('Start sleep'));
    // pumpAndSettle would never settle while the once-a-second ticker runs.
    await tester.pump();
    expect(find.text('Wake up'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^0m \d\ds$')), findsOneWidget);

    // The ticker keeps scheduling frames; it must stop once the sleep ends,
    // or this pumpAndSettle times out.
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Wake up'));
    await tester.pumpAndSettle();
    expect(find.text('Start sleep'), findsOneWidget);
    expect(find.textContaining('Last slept'), findsOneWidget);
  });
}
