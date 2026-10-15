import 'package:flutter/material.dart';

import 'app_store.dart';
import 'home_cards.dart';
import 'home_layout.dart';
import 'home_layout_screen.dart';

/// The Home tab: the user's chosen summary cards, in their chosen order.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store, required this.onViewGrowthChart});

  final AppStore store;
  final VoidCallback onViewGrowthChart;

  Widget _buildCard(HomeCard card) => switch (card) {
        HomeCard.feeding => FeedingSummaryCard(store: store),
        HomeCard.sleep => SleepCard(store: store),
        HomeCard.diaper => DiaperCard(store: store),
        HomeCard.growth => GrowthCard(store: store, onViewChart: onViewGrowthChart),
      };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HomeLayout>(
      valueListenable: homeLayoutNotifier,
      builder: (context, layout, _) {
        final cards = layout.visibleCards;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final card in cards) ...[
                _buildCard(card),
                const SizedBox(height: 16),
              ],
              if (cards.isEmpty) ...[
                Text(
                  'All Home cards are hidden.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Peek at the Feedings, Sleep, Diapers, or Growth tabs to review, edit, or delete past records.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const HomeLayoutScreen()),
                  ),
                  icon: const Icon(Icons.dashboard_customize),
                  label: const Text('Customize home page'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
