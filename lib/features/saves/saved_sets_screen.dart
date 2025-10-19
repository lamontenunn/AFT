import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';

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
      appBar: AppBar(title: const Text('Saved sets')),
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
              return ListTile(
                leading: const Icon(Icons.fitness_center_outlined),
                title: Text('Total: ${total ?? '—'}'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Test date: $testDateLabel'),
                    Text('Saved $savedAtLabel'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
