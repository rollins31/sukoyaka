import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cardOrderKey = 'home_card_order';
const _hiddenCardsKey = 'home_hidden_cards';

/// The category cards shown on the Home page. Declaration order is the
/// default layout.
enum HomeCard {
  feeding('Feeding', Icons.local_drink),
  sleep('Sleep', Icons.bedtime),
  diaper('Diaper change', Icons.baby_changing_station),
  growth('Growth', Icons.monitor_weight);

  const HomeCard(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The user's chosen order of Home cards and which of them are hidden.
/// Hiding a card only affects the Home page — its tab, reminders, and data
/// are untouched.
class HomeLayout {
  const HomeLayout({required this.order, required this.hidden});

  static const defaultLayout = HomeLayout(order: HomeCard.values, hidden: {});

  final List<HomeCard> order;
  final Set<HomeCard> hidden;

  List<HomeCard> get visibleCards => order.where((card) => !hidden.contains(card)).toList();

  bool get isDefault => this == defaultLayout;

  HomeLayout copyWith({List<HomeCard>? order, Set<HomeCard>? hidden}) {
    return HomeLayout(order: order ?? this.order, hidden: hidden ?? this.hidden);
  }

  @override
  bool operator ==(Object other) =>
      other is HomeLayout &&
      listEquals(other.order, order) &&
      setEquals(other.hidden, hidden);

  @override
  int get hashCode => Object.hash(Object.hashAll(order), Object.hashAllUnordered(hidden));
}

/// Global for the same reason as `themeModeNotifier`: the layout screen is
/// pushed several routes away from the Home page, which rebuilds as soon as
/// this changes.
final ValueNotifier<HomeLayout> homeLayoutNotifier = ValueNotifier(HomeLayout.defaultLayout);

HomeCard? _cardByName(String name) {
  for (final card in HomeCard.values) {
    if (card.name == name) return card;
  }
  return null;
}

Future<void> loadHomeLayout() async {
  final prefs = await SharedPreferences.getInstance();
  final storedOrder = prefs.getStringList(_cardOrderKey) ?? const [];
  final storedHidden = prefs.getStringList(_hiddenCardsKey) ?? const [];

  // Drop names that no longer exist, and append any cards added since the
  // order was saved so new categories still show up for existing users.
  final order = {for (final name in storedOrder) ?_cardByName(name)}.toList();
  for (final card in HomeCard.values) {
    if (!order.contains(card)) order.add(card);
  }
  final hidden = {for (final name in storedHidden) ?_cardByName(name)};

  homeLayoutNotifier.value = HomeLayout(order: order, hidden: hidden);
}

Future<void> setHomeLayout(HomeLayout layout) async {
  homeLayoutNotifier.value = layout;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setStringList(_cardOrderKey, [for (final card in layout.order) card.name]);
  await prefs.setStringList(_hiddenCardsKey, [for (final card in layout.hidden) card.name]);
}
