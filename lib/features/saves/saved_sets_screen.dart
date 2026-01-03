import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/saves/editing.dart';
import 'package:aft_firebase_app/features/saves/saved_test_dialog.dart';
import 'package:aft_firebase_app/router/app_router.dart';

/// Body-only screen for Saved Sets (no nested Scaffold/AppBar).
/// AftScaffold provides the global AppBar/NavigationBar.
class SavedSetsScreen extends ConsumerWidget {
  const SavedSetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final isGuest = ref.watch(isGuestUserProvider);

    // Signed-out users cannot access saved tests.
    if (!auth.isSignedIn) {
      return const Center(child: Text('Sign in to view saved tests'));
    }

    final effectiveId = ref.watch(effectiveUserIdProvider);
    return FutureBuilder<List<ScoreSet>>(
      key: ValueKey(effectiveId),
      future:
          ref.read(aftRepositoryProvider).listScoreSets(userId: effectiveId),
      builder: (context, snapshot) {
        // Header row with actions shown regardless of state (kept lightweight).
        Widget header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Spacer(),
              if (auth.isSignedIn && !isGuest)
                IconButton(
                  tooltip: 'Merge guest data',
                  icon: const Icon(Icons.merge_type_outlined),
                  onPressed: () async {
                    final uid = auth.userId!;
                    await ref
                        .read(guestMigrationProvider)
                        .maybeMigrateGuestTo(uid);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Guest data merged (if any)')),
                      );
                      Navigator.pushReplacementNamed(context, Routes.savedSets);
                    }
                  },
                ),
              IconButton(
                tooltip: 'Clear all',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear all saved tests?'),
                      content: const Text(
                          'This will delete all saved tests for the current user.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Clear all')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    final repo = ref.read(aftRepositoryProvider);
                    final userId = ref.read(effectiveUserIdProvider);
                    await repo.clearScoreSets(userId: userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('All sets cleared')));
                      Navigator.pushReplacementNamed(context, Routes.savedSets);
                    }
                  }
                },
              ),
            ],
          ),
        );

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            children: [
              header,
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (snapshot.hasError) {
          return ListView(
            children: [
              header,
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                    child: Text('Failed to load sets: ${snapshot.error}')),
              ),
            ],
          );
        }
        final sets = snapshot.data ?? const <ScoreSet>[];
        if (sets.isEmpty) {
          return ListView(
            children: const [
              SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No saved tests yet')),
              ),
            ],
          );
        }

        // Build a list with a header followed by set tiles.
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: sets.length + 1,
          separatorBuilder: (context, index) =>
              index == 0 ? const SizedBox.shrink() : const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index == 0) return header;

            final set = sets[index - 1];
            final total = set.computed?.total;
            final comp = set.computed;
            final bool isFail = [
              comp?.mdlScore,
              comp?.pushUpsScore,
              comp?.sdcScore,
              comp?.plankScore,
              comp?.run2miScore,
            ].any((s) => s != null && s < 60);
            final date = set.createdAt;
            final savedAtLabel = formatYmdHm(date);
            final testDateLabel = set.profile.testDate == null
                ? '—'
                : formatYmd(set.profile.testDate!);

            return Dismissible(
              key: ValueKey(set.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red.withOpacity(0.8),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete this saved test?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  final repo = ref.read(aftRepositoryProvider);
                  final userId = ref.read(effectiveUserIdProvider);
                  await repo.deleteScoreSet(userId: userId, id: set.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Deleted')));
                    Navigator.pushReplacementNamed(context, Routes.savedSets);
                  }
                  return true;
                }
                return false;
              },
              child: ListTile(
                leading: const Icon(Icons.fitness_center_outlined),
                title: Text(
                  'Total: ${total ?? '—'}',
                  style: TextStyle(color: isFail ? Colors.red : null),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test date: $testDateLabel'),
                    Text('Saved $savedAtLabel'),
                  ],
                ),
                onTap: () async {
                  await showSavedTestDialog(
                    context,
                    set: set,
                    onEdit: () async {
                      // Load into calculator for editing
                      final p = set.profile;
                      final i = set.inputs;
                      final prof = ref.read(aftProfileProvider.notifier);
                      prof.setAge(p.age);
                      prof.setSex(p.sex);
                      prof.setStandard(p.standard);
                      prof.setTestDate(p.testDate);
                      final inp = ref.read(aftInputsProvider.notifier);
                      inp.setMdlLbs(i.mdlLbs);
                      inp.setPushUps(i.pushUps);
                      inp.setSdc(i.sdc);
                      inp.setPlank(i.plank);
                      inp.setRun2mi(i.run2mi);

                      ref.read(editingSetProvider.notifier).state =
                          ScoreEditing(id: set.id, createdAt: set.createdAt);
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, Routes.home);
                      }
                    },
                    onDelete: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete this saved test?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final repo = ref.read(aftRepositoryProvider);
                        final userId = ref.read(effectiveUserIdProvider);
                        await repo.deleteScoreSet(userId: userId, id: set.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Deleted')));
                          Navigator.pushReplacementNamed(
                              context, Routes.savedSets);
                        }
                      }
                    },
                  );
                },
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') {
                      // Load into calculator for editing
                      final p = set.profile;
                      final i = set.inputs;
                      final prof = ref.read(aftProfileProvider.notifier);
                      prof.setAge(p.age);
                      prof.setSex(p.sex);
                      prof.setStandard(p.standard);
                      prof.setTestDate(p.testDate);
                      final inp = ref.read(aftInputsProvider.notifier);
                      inp.setMdlLbs(i.mdlLbs);
                      inp.setPushUps(i.pushUps);
                      inp.setSdc(i.sdc);
                      inp.setPlank(i.plank);
                      inp.setRun2mi(i.run2mi);
                      // Stash editing context and navigate home
                      ref.read(editingSetProvider.notifier).state =
                          ScoreEditing(id: set.id, createdAt: set.createdAt);
                      if (context.mounted) {
                        // Use replacement to switch tabs; popping can leave a blank screen
                        Navigator.pushReplacementNamed(context, Routes.home);
                      }
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete this saved test?'),
                          content: const Text('This cannot be undone.'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel')),
                            FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final repo = ref.read(aftRepositoryProvider);
                        final userId = ref.read(effectiveUserIdProvider);
                        await repo.deleteScoreSet(userId: userId, id: set.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Deleted')));
                          Navigator.pushReplacementNamed(
                              context, Routes.savedSets);
                        }
                      }
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
