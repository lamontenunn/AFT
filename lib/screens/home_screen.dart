import 'package:flutter/material.dart';
import 'package:aft_firebase_app/state/app_state.dart';

/// Home (calculator) screen stub that reflects the current Domain selection.
/// Requirement: selection in the app bar segmented control should persist
/// and be visible on this page.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Establish dependency so this widget rebuilds when AppState changes.
    final appState = AppStateScope.of(context);
    final domain = appState.domain;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Current domain',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Chip(
              label: Text(
                domain.label,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'This selection persists across routes.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Calculator content goes here.\n\n'
              'Scroll to see the app bar condense and keep the small "Total" chip.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 600), // just to allow scroll for demo
      ],
    );
  }
}
