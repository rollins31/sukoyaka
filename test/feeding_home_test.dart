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
}
