import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Body-only settings screen. Wrapped by AftScaffold(showHeader: false).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Settings',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),


        // Default profile
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Default profile',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.event_outlined),
          title: const Text('Birthdate'),
          subtitle: Text(
            settings.defaultBirthdate == null
                ? 'Not set'
                : '${settings.defaultBirthdate!.year.toString().padLeft(4, '0')}-'
                  '${settings.defaultBirthdate!.month.toString().padLeft(2, '0')}-'
                  '${settings.defaultBirthdate!.day.toString().padLeft(2, '0')}'
                  '  (Age today: ${_ageFromDob(settings.defaultBirthdate!)})',
          ),
          trailing: Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: () async {
                  final initial = settings.defaultBirthdate ?? DateTime(DateTime.now().year - 25, 1, 1);
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime(1950, 1, 1),
                    lastDate: DateTime.now(),
                    helpText: 'Select birthdate',
                  );
                  await ctrl.setDefaultBirthdate(picked);
                },
                child: const Text('Set'),
              ),
              if (settings.defaultBirthdate != null)
                TextButton(
                  onPressed: () => ctrl.setDefaultBirthdate(null),
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 16),
              Expanded(
                child: SegmentedButton<AftSex>(
                  segments: const [
                    ButtonSegment(value: AftSex.male, label: Text('Male')),
                    ButtonSegment(value: AftSex.female, label: Text('Female')),
                  ],
                  selected: {settings.defaultSex ?? AftSex.male},
                  onSelectionChanged: (sel) {
                    if (sel.isNotEmpty) {
                      ctrl.setDefaultSex(sel.first);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Prefill Calculator with default profile'),
          value: settings.applyDefaultsOnCalculator,
          onChanged: (v) => ctrl.setApplyDefaultsOnCalculator(v),
        ),
        const Divider(height: 1),

        // Bottom navigation label behavior
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Bottom navigation labels',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<NavLabelBehavior>(
            segments: const [
              ButtonSegment(value: NavLabelBehavior.onlySelected, label: Text('Only selected')),
              ButtonSegment(value: NavLabelBehavior.always, label: Text('Always show')),
            ],
            selected: {settings.navBehavior},
            onSelectionChanged: (sel) {
              if (sel.isNotEmpty) {
                ctrl.setNavBehavior(sel.first);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),

        // Data management
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: const Text('Clear all saved sets'),
          onTap: () async {
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
              final userId = ref.read(effectiveUserIdProvider);
              await repo.clearScoreSets(userId: userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All sets cleared')));
              }
            }
          },
        ),
        const Divider(height: 1),

        // About
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'About',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snap) {
            final info = snap.data;
            final version = info?.version ?? '—';
            final build = info?.buildNumber ?? '—';
            return ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text('Version $version ($build)'),
              subtitle: const Text('AFT Calculator'),
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('About'),
                    content: const Text('Made by Nunn Technologies'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 12),
      ],
    );
  }

// Local helper: compute age in years from DOB at today.
int _ageFromDob(DateTime dob) {
  final now = DateTime.now();
  int age = now.year - dob.year;
  final hasHadBirthdayThisYear = (now.month > dob.month) ||
      (now.month == dob.month && now.day >= dob.day);
  if (!hasHadBirthdayThisYear) age--;
  return age.clamp(0, 150);
}
}
