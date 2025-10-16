import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/auth/auth_state.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';

/// App shell with a collapsing AppBar, segmented control, and overflow sheet.
/// - Title: "AFT Calculator"
/// - Right actions: SegmentedButton for General | Combat, overflow menu
/// - Collapses on scroll and keeps a small "Total" chip placeholder.
class AftScaffold extends ConsumerWidget {
  const AftScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) {
          return [
            SliverAppBar.large(
              pinned: true,
              title: const Text('AFT Calculator'),
              actions: [
                const _DomainSegmentedControl(),
                const SizedBox(width: 8),
                const _ProfileButton(),
                const SizedBox(width: 8),
                const _OverflowButton(),
                const SizedBox(width: 8),
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
                      backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
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

class _DomainSegmentedControl extends ConsumerWidget {
  const _DomainSegmentedControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(aftProfileProvider);
    final selected = <AftStandard>{profile.standard};

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SegmentedButton<AftStandard>(
        style: ButtonStyle(
          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          side: WidgetStatePropertyAll(
            BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
          ),
        ),
        segments: const [
          ButtonSegment(
            value: AftStandard.general,
            label: Text('General'),
          ),
          ButtonSegment(
            value: AftStandard.combat,
            label: Text('Combat'),
          ),
        ],
        selected: selected,
        onSelectionChanged: (newSelection) {
          if (newSelection.isEmpty) return;
          final value = newSelection.first;
          ref.read(aftProfileProvider.notifier).setStandard(value);
        },
      ),
    );
  }
}

class _ProfileButton extends ConsumerWidget {
  const _ProfileButton();

  String _initialsFor(AuthState state) {
    final name = state.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(' ').where((e) => e.isNotEmpty).toList();
      final first = parts.isNotEmpty ? parts.first[0] : '';
      final last = parts.length > 1 ? parts.last[0] : '';
      final init = (first + last).toUpperCase();
      return init.isEmpty ? 'U' : init;
    }
    final id = state.userId ?? '';
    return id.isNotEmpty ? id[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return IconButton(
      tooltip: auth.isSignedIn ? 'Account' : 'Sign in to save scores',
      icon: auth.isSignedIn
          ? CircleAvatar(
              radius: 12,
              child: Text(
                _initialsFor(auth),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            )
          : const Icon(Icons.person_outline),
      onPressed: () => _showProfileSheet(context, ref, auth),
    );
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref, AuthState auth) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        if (!auth.isSignedIn) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('Sign in to save scores'),
                ),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Sign in'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref.read(authActionsProvider).signIn();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed in as Demo User')),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        } else {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: const Text('Saved sets'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed('/saved-sets');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await ref.read(authActionsProvider).signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signed out')),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        }
      },
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
