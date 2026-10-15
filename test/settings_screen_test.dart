import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukoyaka/app_store.dart';
import 'package:sukoyaka/feeding_entry.dart';
import 'package:sukoyaka/settings_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the record count follows the store while Settings is open', (tester) async {
    final store = AppStore();
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(store: store)));

    expect(find.textContaining('On this device: 0 records'), findsOneWidget);

    await tester.runAsync(() => store.addFeeding(FeedingEntry(
          id: 1,
          time: DateTime(2026, 10, 1),
          milkType: 'Bottle',
          amount: null,
          amountUnit: 'ml',
          notes: '',
        )));
    await tester.pump();

    expect(find.textContaining('On this device: 1 record (1 feedings'), findsOneWidget);
  });
}
