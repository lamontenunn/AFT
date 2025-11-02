import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/auth/auth_state.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/router/app_router.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:aft_firebase_app/state/settings_state.dart';

/// App shell with a collapsing AppBar, segmented control, and overflow sheet.
/// - Title: "AFT Calculator"
/// - Right actions: SegmentedButton for General | Combat, overflow menu
/// - Collapses on scroll and keeps a small "Total" chip placeholder.
class AftScaffold extends ConsumerWidget {
  const AftScaffold({super.key, required this.child, this.showHeader = false});

  final Widget child;

  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine current tab index based on the active route (Material 3 NavigationBar)
    final routeName = ModalRoute.of(context)?.settings.name ?? Routes.home;
    final int currentIndex = switch (routeName) {
      Routes.home => 0,
      Routes.savedSets => 1,
      Routes.standards => 2,
      Routes.settings => 3,
      _ => 0,
    };

    final settings = ref.watch(settingsProvider);
    final navLabelBehavior =
        settings.navBehavior == NavLabelBehavior.always
            ? NavigationDestinationLabelBehavior.alwaysShow
            : NavigationDestinationLabelBehavior.onlyShowSelected;

    return Scaffold(
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: ArmyColors.gold,
          indicatorColor: Colors.black12,
          height: 44,
          iconTheme: MaterialStateProperty.resolveWith((states) {
            return IconThemeData(
              size: 18,
              color: states.contains(MaterialState.selected) ? Colors.black : Colors.black87,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          onDestinationSelected: (int i) {
            if (i == currentIndex) return;
            HapticFeedback.selectionClick();
            final nextRoute = switch (i) {
              0 => Routes.home,
              1 => Routes.savedSets,
              2 => Routes.standards,
              3 => Routes.settings,
              _ => Routes.home,
            };
            Navigator.of(context).pushReplacementNamed(nextRoute);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'Calculator',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Saved Sets',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Standards',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) {
          return showHeader ? [
            SliverAppBar(
              pinned: false,
              centerTitle: true,
              title: const Text(
                'AFT Calculator',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                const _ProfileButton(),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Center(child: _DomainSegmentedControl()),
                ),
              ),
            ),
          ] : [];
        },
        body: SafeArea(
          // When there is no header (e.g., Saved Sets, Standards), respect top safe area
          top: !showHeader,
          bottom: true,
          child: child,
        ),
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
          side: WidgetStateProperty.resolveWith((states) {
            final outline = Theme.of(context).colorScheme.outline;
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: ArmyColors.gold, width: 1.2);
            }
            return BorderSide(color: outline, width: 1);
          }),
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

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: IconButton(
      tooltip: auth.isSignedIn ? 'Account' : 'Sign in to save scores',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      alignment: Alignment.center,
      splashRadius: 20,
      icon: (auth.displayName != null && auth.displayName!.trim().isNotEmpty)
          ? CircleAvatar(
              radius: 12,
              child: Text(
                _initialsFor(auth),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            )
          : const Icon(Icons.person_outline),
      onPressed: () => _showProfileSheet(context, ref, auth),
    ),
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
                    Navigator.of(context).pushNamed(Routes.signIn);
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
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  onTap: () async {
                    final asyncUser = ref.read(firebaseUserProvider);
                    final user = asyncUser.asData?.value;
                    final isAnon = user?.isAnonymous ?? true;
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign out?'),
                        content: Text(
                          isAnon
                              ? 'Guest data stays on this device and can be merged when you sign in later.'
                              : 'You can sign back in at any time.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sign out')),
                        ],
                      ),
                    );
                    if (ok != true) return;

                    Navigator.of(context).pop();
                    await ref.read(authActionsProvider).signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out')),
                      );
                    }
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
