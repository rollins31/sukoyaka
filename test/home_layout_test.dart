import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sukoyaka/home_layout.dart';
import 'package:sukoyaka/home_layout_screen.dart';
import 'package:sukoyaka/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    homeLayoutNotifier.value = HomeLayout.defaultLayout;
  });

  group('loadHomeLayout', () {
    test('uses the default layout when nothing is saved', () async {
      await loadHomeLayout();
      expect(homeLayoutNotifier.value, HomeLayout.defaultLayout);
    });

    test('round-trips a saved layout', () async {
      const layout = HomeLayout(
        order: [HomeCard.diaper, HomeCard.feeding, HomeCard.growth, HomeCard.sleep],
        hidden: {HomeCard.growth},
      );
      await setHomeLayout(layout);
      homeLayoutNotifier.value = HomeLayout.defaultLayout;

      await loadHomeLayout();
      expect(homeLayoutNotifier.value, layout);
    });

    test('drops unknown cards and appends ones missing from the saved order', () async {
      SharedPreferences.setMockInitialValues({
        'home_card_order': ['sleep', 'bath', 'feeding'],
        'home_hidden_cards': ['bath', 'feeding'],
      });

      await loadHomeLayout();
      expect(homeLayoutNotifier.value.order, [HomeCard.sleep, HomeCard.feeding, HomeCard.diaper, HomeCard.growth]);
      expect(homeLayoutNotifier.value.hidden, {HomeCard.feeding});
    });
  });

  group('Home page', () {
    Future<void> pumpHome(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: FeedingHome()));
      await tester.pumpAndSettle();
    }

    testWidgets('shows cards in the saved order and skips hidden ones', (tester) async {
      homeLayoutNotifier.value = const HomeLayout(
        order: [HomeCard.growth, HomeCard.feeding, HomeCard.sleep, HomeCard.diaper],
        hidden: {HomeCard.sleep},
      );
      await pumpHome(tester);

      // "Sleep" alone would also match the bottom-nav tab.
      expect(find.text('Start sleep'), findsNothing);
      // Card-specific buttons, since "Growth" also matches the bottom-nav tab.
      final growthY = tester.getTopLeft(find.text('View growth chart')).dy;
      final feedingY = tester.getTopLeft(find.text('Mark feeding now')).dy;
      expect(growthY, lessThan(feedingY));
    });

    testWidgets('shows a message when every card is hidden', (tester) async {
      homeLayoutNotifier.value = HomeLayout(order: HomeCard.values, hidden: HomeCard.values.toSet());
      await pumpHome(tester);

      expect(find.text('All Home cards are hidden.'), findsOneWidget);
    });
  });

  testWidgets('layout screen toggles hide a card and persist', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeLayoutScreen()));

    await tester.tap(find.byType(Switch).at(HomeCard.growth.index));
    await tester.pumpAndSettle();

    expect(homeLayoutNotifier.value.hidden, {HomeCard.growth});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('home_hidden_cards'), ['growth']);

    await tester.tap(find.text('Reset to default'));
    await tester.pumpAndSettle();
    expect(homeLayoutNotifier.value, HomeLayout.defaultLayout);
  });
}
