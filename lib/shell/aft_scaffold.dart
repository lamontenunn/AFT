import 'package:flutter/material.dart';
import 'package:aft_firebase_app/state/app_state.dart';

/// App shell with a collapsing AppBar, segmented control, and overflow sheet.
/// - Title: "AFT Calculator"
/// - Right actions: SegmentedButton for General | Combat, overflow menu
/// - Collapses on scroll and keeps a small "Total" chip placeholder.
class AftScaffold extends StatelessWidget {
  const AftScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) {
          return [
            SliverAppBar.large(
              pinned: true,
              title: const Text('AFT Calculator'),
              actions: const [
                _DomainSegmentedControl(),
                SizedBox(width: 8),
                _OverflowButton(),
                SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Chip(
                      label: const Text('Total'),
                      visualDensity: VisualDensity.compact,
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
                      side: BorderSide(color: colorScheme.outline, width: 0.8),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: child,
      ),
    );
  }
}

class _DomainSegmentedControl extends StatelessWidget {
  const _DomainSegmentedControl();

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final selected = <Domain>{appState.domain};

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<Domain>(
        style: ButtonStyle(
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          side: WidgetStatePropertyAll(
            BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
          ),
        ),
        segments: const [
          ButtonSegment(
            value: Domain.general,
            label: Text('General'),
          ),
          ButtonSegment(
            value: Domain.combat,
            label: Text('Combat'),
          ),
        ],
        selected: selected,
        onSelectionChanged: (newSelection) {
          if (newSelection.isEmpty) return;
          final value = newSelection.first;
          AppStateScope.read(context).setDomain(value);
        },
      ),
    );
  }
}

class _OverflowButton extends StatelessWidget {
  const _OverflowButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More',
      onPressed: () => _showOverflowSheet(context),
    );
  }

  void _showOverflowSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Standards'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed('/standards');
                },
              ),
              ListTile(
                leading: const Icon(Icons.timeline_outlined),
                title: const Text('Timeline'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Timeline (coming soon)')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings (coming soon)')),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
