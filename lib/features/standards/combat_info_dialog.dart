import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows the Combat MOS info dialog if the user hasn't disabled it.
/// Uses Material 3 AlertDialog with scrollable content and a "Don't show again" option.
Future<void> maybeShowCombatInfoDialog(
    BuildContext context, WidgetRef ref) async {
  final settings = ref.read(settingsProvider);
  if (!settings.showCombatInfo) return;

  bool dontShowAgain = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Combat MOS List:'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              // Keep dialog content within a comfortable viewport height
              maxHeight: MediaQuery.of(ctx).size.height * 0.6,
              maxWidth: 520,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'The following MOSs are all classified as combat for AFT purposes:',
                  ),
                  const SizedBox(height: 12),
                  ..._combatItems.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $e', style: theme.textTheme.bodyMedium),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: dontShowAgain,
                    onChanged: (v) =>
                        setState(() => dontShowAgain = v ?? false),
                    title: const Text("Don't show again"),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await _openAftFaq();
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Learn more'),
            ),
            FilledButton(
              onPressed: () async {
                if (dontShowAgain) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setShowCombatInfo(false);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openAftFaq() async {
  final uri = Uri.parse('https://www.army.mil/aft/#faq');
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Silently ignore launch failures.
  }
}

const List<String> _combatItems = [
  '11A. Infantry Officer',
  '11B. Infantryman',
  '11C. Indirect Fire Infantryman (Mortarman)',
  '11Z. Infantry Senior Sergeant',
  '12A. Engineer; General Engineer',
  '12B. Combat Engineer',
  '13A. Field Artillery Officer',
  '13F. Fire Support Specialist',
  '18A. Special Forces Officer',
  '180A. Special Forces Warrant Officer',
  '18B. Special Forces Weapons Sergeant',
  '18C. Special Forces Engineer Sergeant',
  '18D. Special Forces Medical Sergeant',
  '18E. Special Forces Communications Sergeant',
  '18F. Special Forces Intelligence Sergeant',
  '18Z. Special Forces Senior Sergeant',
  '19A. Armor Officer',
  '19C. Bradley Crew member',
  '19D. Cavalry Scout',
  '19K. M1 Armor Crewman',
  '19Z. Armor Senior Sergeant',
];
