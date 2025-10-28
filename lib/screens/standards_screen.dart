import 'package:flutter/material.dart';

/// Stub screen for "Standards".
class StandardsScreen extends StatelessWidget {
  const StandardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Body-only content; AftScaffold provides the global AppBar/NavigationBar.
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Text(
          'Standards screen (stub)',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
