import 'package:flutter/material.dart';

import 'home_layout.dart';

/// Lets the user reorder the Home page's category cards (drag the handle)
/// and hide the ones they don't use. Changes apply immediately.
class HomeLayoutScreen extends StatelessWidget {
  const HomeLayoutScreen({super.key});

  void _reorder(HomeLayout layout, int oldIndex, int newIndex) {
    final order = List.of(layout.order);
    order.insert(newIndex, order.removeAt(oldIndex));
    setHomeLayout(layout.copyWith(order: order));
  }

  void _setVisible(HomeLayout layout, HomeCard card, bool visible) {
    final hidden = Set.of(layout.hidden);
    visible ? hidden.remove(card) : hidden.add(card);
    setHomeLayout(layout.copyWith(hidden: hidden));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home page layout')),
      body: ValueListenableBuilder<HomeLayout>(
        valueListenable: homeLayoutNotifier,
        builder: (context, layout, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Drag to change the order of the cards on the Home page, '
                'and turn off any you don\'t need. Hidden cards keep their '
                'reminders and history.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Card(
                clipBehavior: Clip.antiAlias,
                child: ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  onReorderItem: (oldIndex, newIndex) => _reorder(layout, oldIndex, newIndex),
                  children: [
                    for (final (index, card) in layout.order.indexed)
                      _buildRow(context, layout, card, index),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: layout.isDefault ? null : () => setHomeLayout(HomeLayout.defaultLayout),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Reset to default'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRow(BuildContext context, HomeLayout layout, HomeCard card, int index) {
    final visible = !layout.hidden.contains(card);
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey(card),
      color: Colors.transparent,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Icon(Icons.drag_handle),
          ),
        ),
        title: Row(
          children: [
            Icon(card.icon, size: 20, color: visible ? colorScheme.primary : colorScheme.outline),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                card.label,
                style: TextStyle(color: visible ? null : colorScheme.outline),
              ),
            ),
          ],
        ),
        trailing: Switch(
          value: visible,
          onChanged: (value) => _setVisible(layout, card, value),
        ),
      ),
    );
  }
}
