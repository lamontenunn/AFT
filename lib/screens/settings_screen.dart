import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/screens/edit_default_profile_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Body-only settings screen. Wrapped by AftScaffold(showHeader: false).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _displayName(DefaultProfileSettings dp) {
    final first = dp.firstName?.trim();
    final last = dp.lastName?.trim();
    final mi = dp.middleInitial?.trim();

    final parts = <String>[];
    if (last != null && last.isNotEmpty) parts.add(last);
    if (first != null && first.isNotEmpty) parts.add(first);
    if (mi != null && mi.isNotEmpty) parts.add('$mi.');

    if (parts.isEmpty) return 'Not set';
    if (last != null && last.isNotEmpty && first != null && first.isNotEmpty) {
      // "Last, First M."
      final firstPart = mi != null && mi.isNotEmpty ? '$first $mi.' : first;
      return '$last, $firstPart';
    }
    // fallback
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final dp = settings.defaultProfile;

    String ymd(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    String heightLabel() {
      if (dp.height == null) return 'Not set';
      if (dp.measurementSystem == MeasurementSystem.metric) {
        return '${dp.height!.toStringAsFixed(0)} cm';
      }
      final totalIn = dp.height!.round();
      final ft = totalIn ~/ 12;
      final inch = totalIn % 12;
      return "$ft' $inch\"";
    }

    String weightLabel() {
      if (dp.weight == null) return 'Not set';
      if (dp.measurementSystem == MeasurementSystem.metric) {
        return '${dp.weight!.toStringAsFixed(1)} kg';
      }
      return '${dp.weight!.toStringAsFixed(1)} lb';
    }

    String bodyFatLabel() {
      if (dp.bodyFatPercent == null) return 'Not set';
      return '${dp.bodyFatPercent!.toStringAsFixed(1)}%';
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Profile (read-only)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Profile',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Name',
                    value: _displayName(dp),
                  ),
                  const Divider(height: 12),
                  _SummaryRow(
                    label: 'Unit',
                    value: dp.unit?.trim().isNotEmpty == true
                        ? dp.unit!.trim()
                        : 'Not set',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'MOS',
                    value: dp.mos?.trim().isNotEmpty == true
                        ? dp.mos!.trim()
                        : 'Not set',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Pay Grade',
                    value: dp.payGrade?.trim().isNotEmpty == true
                        ? dp.payGrade!.trim()
                        : 'Not set',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'On profile',
                    value: dp.onProfile ? 'Yes' : 'No',
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    label: 'Birthdate',
                    value: dp.birthdate == null
                        ? 'Not set'
                        : '${ymd(dp.birthdate!)} (Age ${_ageFromDob(dp.birthdate!)})',
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'Gender',
                    value: dp.sex == null
                        ? 'Not set'
                        : (dp.sex == AftSex.male ? 'Male' : 'Female'),
                  ),
                  const Divider(height: 20),
                  _SummaryRow(label: 'Height', value: heightLabel()),
                  const SizedBox(height: 8),
                  _SummaryRow(label: 'Weight', value: weightLabel()),
                  const SizedBox(height: 8),
                  _SummaryRow(label: 'Body fat %', value: bodyFatLabel()),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const EditDefaultProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const Divider(height: 1),

        // Popups & tips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Popups & tips',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Show Combat info popup'),
          value: settings.showCombatInfo,
          onChanged: (v) => ctrl.setShowCombatInfo(v),
        ),
        const Divider(height: 1),

        // Data management
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Data',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.delete_sweep_outlined),
          title: const Text('Clear all saved tests'),
          onTap: () async {
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
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
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

        // Appearance (moved to bottom)
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Appearance',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Card(
            color:
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Theme selection is coming soon. Dark mode is currently the default.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: null, // Disabled: coming soon
          ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
