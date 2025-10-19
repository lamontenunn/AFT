import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/saves/editing.dart';
import 'package:aft_firebase_app/router/app_router.dart';

class SavedSetsScreen extends ConsumerWidget {
  const SavedSetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    if (!auth.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved sets')),
        body: const Center(
          child: Text('Sign in to view saved sets'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved sets'),
        actions: [
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear all saved sets?'),
                  content: const Text('This will delete all saved sets for the current user.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear all')),
                  ],
                ),
              );
              if (ok == true) {
                final repo = ref.read(aftRepositoryProvider);
                final userId = ref.read(authStateProvider).userId!;
                await repo.clearScoreSets(userId: userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All sets cleared')));
                  Navigator.pushReplacementNamed(context, Routes.savedSets);
                }
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<ScoreSet>>(
        future: ref.read(aftRepositoryProvider).listScoreSets(userId: auth.userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load sets: ${snapshot.error}'),
            );
          }
          final sets = snapshot.data ?? const <ScoreSet>[];
          if (sets.isEmpty) {
            return const Center(child: Text('No saved sets yet'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final set = sets[index];
              final total = set.computed?.total;
              final date = set.createdAt;
              final savedAtLabel = formatYmdHm(date);
              final testDateLabel = set.profile.testDate == null ? '—' : formatYmd(set.profile.testDate!);
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
                      title: const Text('Delete this saved set?'),
                      content: const Text('This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    final repo = ref.read(aftRepositoryProvider);
                    final userId = ref.read(authStateProvider).userId!;
                    await repo.deleteScoreSet(userId: userId, id: set.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                      // Reload screen to reflect changes
                      Navigator.pushReplacementNamed(context, Routes.savedSets);
                    }
                    return true;
                  }
                  return false;
                },
                child: ListTile(
                  leading: const Icon(Icons.fitness_center_outlined),
                  title: Text('Total: ${total ?? '—'}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Test date: $testDateLabel'),
                      Text('Saved $savedAtLabel'),
                    ],
                  ),
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
                          Navigator.of(context).pop(); // back to Home
                        }
                      } else if (value == 'delete') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete this saved set?'),
                            content: const Text('This cannot be undone.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) {
                          final repo = ref.read(aftRepositoryProvider);
                          final userId = ref.read(authStateProvider).userId!;
                          await repo.deleteScoreSet(userId: userId, id: set.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
                            Navigator.pushReplacementNamed(context, Routes.savedSets);
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
      ),
    );
  }
}
