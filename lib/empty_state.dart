import 'package:flutter/material.dart';

/// Shared empty-state layout used by the Feedings, Sleep, Diapers, and
/// Growth tabs, so a "no data yet" screen looks the same everywhere: a
/// muted domain icon over a centered message, both themed off
/// [ColorScheme.onSurfaceVariant] so they track light/dark mode and the
/// app's text-scaling settings.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
