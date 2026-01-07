import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/auth/auth_state.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/features/saves/editing.dart';
import 'package:aft_firebase_app/features/saves/da705_export.dart';
import 'package:aft_firebase_app/features/saves/saved_test_dialog.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/router/app_router.dart';
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
    // Determine current tab index based on the active route (Material 3 NavigationBar)
    final routeName = ModalRoute.of(context)?.settings.name ?? Routes.home;
    final int currentIndex = switch (routeName) {
      Routes.home => 0,
      Routes.savedSets => 1,
      Routes.standards => 2,
      Routes.proctor => 3,
      Routes.settings => 4,
      _ => 0,
    };

    // Only used to force rebuild when nav behavior changes.
    // (NavigationBar labelBehavior is currently hard-coded to alwaysHide.)
    ref.watch(settingsProvider);

    return Scaffold(
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: ArmyColors.gold,
          indicatorColor: Colors.black12,
          height: 30,
          iconTheme: MaterialStateProperty.resolveWith((states) {
            return IconThemeData(
              size: 16,
              color: states.contains(MaterialState.selected)
                  ? Colors.black
                  : Colors.black87,
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
              3 => Routes.proctor,
              4 => Routes.settings,
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
              label: 'Saved Tests',
            ),
            NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag),
              label: 'Standards',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer),
              label: 'Proctor',
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
          // Route-based top app bar:
          // - Standards: no top app bar
          // - Others (Home, Saved Sets, Settings): small top app bar
          if (routeName == Routes.standards) {
            return [];
          }
          return [
            SliverAppBar(
              pinned: true,
              toolbarHeight: 30,
              backgroundColor: ArmyColors.gold,
              foregroundColor: Colors.black,
              elevation: 0,
              centerTitle: true,
              bottom: routeName == Routes.home ? const _HomeTotalBar() : null,
              title: Text(
                switch (routeName) {
                  Routes.home => 'Home',
                  Routes.savedSets => 'Saved Sets',
                  Routes.proctor => 'Proctor',
                  Routes.settings => 'Settings',
                  _ => 'AFT',
                },
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              actions: [
                if (routeName == Routes.home) ...[
                  _TopBarSaveCancelActions(routeName: routeName),
                  const SizedBox(width: 4),
                ],
                const _ProfileButton(),
                const SizedBox(width: 8),
              ],
            ),
          ];
        },
        body: SafeArea(
          // Add top inset for pages without a header sliver (e.g., Standards)
          top: routeName == Routes.standards,
          bottom: true,
          child: child,
        ),
      ),
    );
  }
}

class _HomeTotalBar extends ConsumerWidget implements PreferredSizeWidget {
  const _HomeTotalBar();

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final computed = ref.watch(aftComputedProvider);
    final bool isFail = [
      computed.mdlScore,
      computed.pushUpsScore,
      computed.sdcScore,
      computed.plankScore,
      computed.run2miScore,
    ].any((s) => s != null && s < 60);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: 'Total score out of 500',
                value: computed.total == null
                    ? 'No total yet'
                    : '${computed.total} of 500',
                child: Text(
                  computed.total == null
                      ? 'Total: — / 500'
                      : 'Total: ${computed.total} / 500',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isFail ? Colors.red : cs.onSurface,
                  ),
                ),
              ),
            ),
            if (computed.total != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: ShapeDecoration(
                  shape: StadiumBorder(
                    side: BorderSide(
                      color: isFail ? Colors.red : ArmyColors.gold,
                      width: 1.2,
                    ),
                  ),
                ),
                child: Text(
                  isFail ? 'FAIL' : 'PASS',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
          ],
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

    return SizedBox(
      height: 36,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () {
          final isCombat = profile.standard == AftStandard.combat;
          final next = isCombat ? AftStandard.general : AftStandard.combat;
          ref.read(aftProfileProvider.notifier).setStandard(next);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: profile.standard == AftStandard.combat
                ? ArmyColors.gold
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: profile.standard == AftStandard.combat
                  ? ArmyColors.gold
                  : Theme.of(context).colorScheme.outline,
              width: profile.standard == AftStandard.combat ? 1.4 : 1.0,
            ),
            boxShadow: profile.standard == AftStandard.combat
                ? [
                    BoxShadow(
                      color: ArmyColors.gold.withOpacity(0.55),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: Text(
                'Combat',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: profile.standard == AftStandard.combat
                          ? Colors.black
                          : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home-only top bar actions:
/// - Cancel (when editing an existing saved test)
/// - Save / Update (auth gated, enabled when total is computed)
class _TopBarSaveCancelActions extends ConsumerWidget {
  const _TopBarSaveCancelActions({required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routeName != Routes.home) return const SizedBox.shrink();

    final auth = ref.watch(authStateProvider);
    final computed = ref.watch(aftComputedProvider);
    final inputs = ref.watch(aftInputsProvider);
    final editing = ref.watch(editingSetProvider);

    final bool canSave = auth.isSignedIn && computed.total != null;
    final bool hasInputs = inputs.mdlLbs != null ||
        inputs.pushUps != null ||
        inputs.sdc != null ||
        inputs.plank != null ||
        inputs.run2mi != null;

    Future<void> doCancel() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel update?'),
          content: const Text('Discard your changes and exit editing mode?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (ok != true) return;

      final repo = ref.read(aftRepositoryProvider);
      final userId = ref.read(effectiveUserIdProvider);
      final sets = await repo.listScoreSets(userId: userId);
      ScoreSet? original;
      for (final s in sets) {
        if (s.id == editing!.id) {
          original = s;
          break;
        }
      }
      if (original != null) {
        final p = original.profile;
        final i = original.inputs;
        ref.read(aftProfileProvider.notifier)
          ..setAge(p.age)
          ..setSex(p.sex)
          ..setStandard(p.standard)
          ..setTestDate(p.testDate);
        ref.read(aftInputsProvider.notifier)
          ..setMdlLbs(i.mdlLbs)
          ..setPushUps(i.pushUps)
          ..setSdc(i.sdc)
          ..setPlank(i.plank)
          ..setRun2mi(i.run2mi);
      }
      ref.read(editingSetProvider.notifier).state = null;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Update canceled')),
        );
      }
    }

    Future<void> doSaveOrUpdate() async {
      final profileNow = ref.read(aftProfileProvider);
      final inputsNow = ref.read(aftInputsProvider);
      final computedNow = ref.read(aftComputedProvider);
      final repo = ref.read(aftRepositoryProvider);
      final userId = ref.read(effectiveUserIdProvider);
      final createdAt = editing?.createdAt ?? DateTime.now();
      final set = ScoreSet(
        id: editing?.id,
        profile: profileNow,
        inputs: inputsNow,
        computed: computedNow,
        createdAt: createdAt,
      );

      if (editing != null) {
        await repo.updateScoreSet(userId: userId, set: set);
        // Clear editing state after successful update
        ref.read(editingSetProvider.notifier).state = null;
        if (context.mounted) {
          await showSavedTestDialog(
            context,
            set: set,
            onExportDa705: () async {
              final profile = ref.read(settingsProvider).defaultProfile;
              await exportDa705Pdf(
                context: context,
                set: set,
                profile: profile,
                userScope: userId,
              );
            },
            onEdit: () {},
            onDelete: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this saved test?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await repo.deleteScoreSet(userId: userId, id: set.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deleted')),
                  );
                }
              }
            },
          );
        }
      } else {
        await repo.saveScoreSet(userId: userId, set: set);
        if (context.mounted) {
          await showSavedTestDialog(
            context,
            set: set,
            onExportDa705: () async {
              final profile = ref.read(settingsProvider).defaultProfile;
              await exportDa705Pdf(
                context: context,
                set: set,
                profile: profile,
                userScope: userId,
              );
            },
            onEdit: () {},
            onDelete: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete this saved test?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await repo.deleteScoreSet(userId: userId, id: set.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deleted')),
                  );
                }
              }
            },
          );
        }
      }
    }

    Future<void> doClearInputs() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Clear inputs?'),
          content: Text(
            editing == null
                ? 'This resets all event inputs on the calculator.'
                : 'This resets the event inputs while you are editing. You can still cancel to restore the original.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );
      if (ok != true) return;

      FocusScope.of(context).unfocus();
      ref.read(aftInputsProvider.notifier).clearAll();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inputs cleared')),
        );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (editing != null)
          IconButton(
            tooltip: 'Cancel update',
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
            splashRadius: 16,
            icon: const Icon(Icons.close, size: 18),
            onPressed: doCancel,
          ),
        IconButton(
          tooltip: 'Clear inputs',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          splashRadius: 16,
          icon: const Icon(Icons.restart_alt, size: 18),
          onPressed: hasInputs ? doClearInputs : null,
        ),
        IconButton(
          tooltip: auth.isSignedIn
              ? (editing != null ? 'Update saved test' : 'Save results')
              : 'Sign in to save results',
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          splashRadius: 16,
          icon: const Icon(Icons.save_outlined, size: 18),
          onPressed: canSave ? doSaveOrUpdate : null,
        ),
      ],
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
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      alignment: Alignment.center,
      splashRadius: 16,
      icon: (auth.displayName != null && auth.displayName!.trim().isNotEmpty)
          ? CircleAvatar(
              radius: 10,
              child: Text(
                _initialsFor(auth),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            )
          : const Icon(Icons.person_outline, size: 18),
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
        return Consumer(
          builder: (context, ref, _) {
            final authState = ref.watch(authStateProvider);
            if (!authState.isSignedIn) {
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
            }
            final isGuest = ref.watch(isGuestUserProvider);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isGuest) ...[
                    const ListTile(
                      leading: Icon(Icons.person_outline),
                      title: Text('Guest account'),
                      subtitle: Text(
                        'Create an account to keep data across devices.',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_add),
                      title: const Text('Create account'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(Routes.signIn);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.login),
                      title: const Text('Sign in'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pushNamed(Routes.signIn);
                      },
                    ),
                  ] else
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Sign out'),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Sign out?'),
                            content:
                                const Text('You can sign back in at any time.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Sign out')),
                            ],
                          ),
                        );
                        if (ok != true) return;

                        Navigator.of(context).pop();
                        await ref.read(authActionsProvider).signOut();
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
