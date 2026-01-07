import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/features/aft/utils/sdc_segment_info.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/features/proctor/state/proctor_session.dart';
import 'package:aft_firebase_app/features/proctor/state/proctor_inputs.dart';
import 'package:aft_firebase_app/features/proctor/state/proctor_ui_state.dart';
import 'package:aft_firebase_app/features/proctor/state/providers.dart';
import 'package:aft_firebase_app/features/proctor/timing/thresholds.dart';
import 'package:aft_firebase_app/features/proctor/timing/timer_controller.dart';
import 'package:aft_firebase_app/features/proctor/tools/tools_tab.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';

int _ceilMul(int target, double t01) {
  if (target <= 0) return 0;
  final v = (target * t01);
  return v.ceil();
}

Duration? _parseDurationThreshold(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return parseMmSs(trimmed);
}

/// Returns needed reps by time, using a linear pace over the full 2:00 window.
int neededHrpRepsByNow({required int targetReps, required Duration elapsed}) {
  final secs = elapsed.inMilliseconds / 1000.0;
  final t = (secs / 120.0).clamp(0.0, 1.0);
  return _ceilMul(targetReps, t);
}

enum ProctorTab { calculators, instructions, timing }

class ProctorScreen extends ConsumerStatefulWidget {
  const ProctorScreen({super.key});

  @override
  ConsumerState<ProctorScreen> createState() => _ProctorScreenState();
}

class _ProctorScreenState extends ConsumerState<ProctorScreen> {
  ProctorTab _tab = ProctorTab.timing;
  AftEvent _timingEvent = AftEvent.sdc;

  void _syncUiFromProvider(WidgetRef ref) {
    final ui = ref.read(proctorUiProvider);
    final tab = ProctorTab
        .values[ui.topTabIndex.clamp(0, ProctorTab.values.length - 1)];
    if (_tab != tab) _tab = tab;
    if (_timingEvent != ui.timingEvent) _timingEvent = ui.timingEvent;
  }

  @override
  Widget build(BuildContext context) {
    _syncUiFromProvider(ref);

    final session = ref.watch(proctorSessionProvider);
    final selected = ref.watch(selectedProctorParticipantProvider);
    final proctorProfile = ref.watch(proctorProfileProvider);

    // Auto-stop timers when switching participants.
    ref.listen<ProctorParticipant?>(selectedProctorParticipantProvider,
        (prev, next) {
      final prevId = prev?.id;
      if (prevId != null && next?.id != prevId) {
        ref.read(proctorTimingProvider.notifier).stopAllForParticipant(prevId);
      }
      // Also stop timers for the newly selected participant.
      final nextId = next?.id;
      if (nextId != null) {
        ref.read(proctorTimingProvider.notifier).stopAllForParticipant(nextId);
      }
    });

    // Keep proctor profile synced to participant selection.
    ref.listen<ProctorParticipant?>(selectedProctorParticipantProvider,
        (prev, next) {
      if (next == null) return;
      ref.read(proctorProfileProvider.notifier).syncFromParticipant(next);
    });

    final theme = Theme.of(context);

    return ListView(
      // Allows users to dismiss the on-screen keyboard/keypad by dragging.
      // This is especially important for numeric keypads (often no "Done").
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: _RosterChip(
              selected: selected,
              rosterCount: session.roster.length,
              onTap: () => _showRosterSheet(context, ref),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      final isCombat =
                          proctorProfile.standard == AftStandard.combat;
                      final next =
                          isCombat ? AftStandard.general : AftStandard.combat;
                      ref
                          .read(proctorProfileProvider.notifier)
                          .setStandard(next);
                      HapticFeedback.selectionClick();
                    },
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: proctorProfile.standard == AftStandard.combat
                            ? ArmyColors.gold
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: proctorProfile.standard == AftStandard.combat
                              ? ArmyColors.gold
                              : theme.colorScheme.outline,
                          width: proctorProfile.standard == AftStandard.combat
                              ? 1.4
                              : 1.0,
                        ),
                        boxShadow: proctorProfile.standard == AftStandard.combat
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
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Center(
                          child: Text(
                            proctorProfile.standard == AftStandard.combat
                                ? 'Combat'
                                : 'General',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:
                                  proctorProfile.standard == AftStandard.combat
                                      ? Colors.black
                                      : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ProctorTab>(
            segments: const [
              ButtonSegment(
                  value: ProctorTab.calculators, label: Text('Tools')),
              ButtonSegment(
                value: ProctorTab.instructions,
                label: Text('Instr.'),
              ),
              ButtonSegment(
                value: ProctorTab.timing,
                label: Text('Timing'),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (sel) {
              if (sel.isEmpty) return;
              setState(() {
                _tab = sel.first;
                ref.read(proctorUiProvider.notifier).setTopTabIndex(_tab.index);
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _tabBody(selected),
        ),
      ],
    );
  }

  Widget _tabBody(ProctorParticipant? selected) {
    switch (_tab) {
      case ProctorTab.timing:
        if (selected == null) {
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('No participant selected'),
                  const SizedBox(height: 6),
                  Text(
                    'Tap the roster chip to add/select a participant.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }
        return _TimingTab(
          event: _timingEvent,
          onEventChanged: (e) => setState(() {
            _timingEvent = e;
            ref.read(proctorUiProvider.notifier).setTimingEvent(e);
          }),
        );
      case ProctorTab.instructions:
        return const _PlaceholderCard(
          title: 'Instructions (MVP)',
          body: 'Field-friendly event instructions will appear here.',
        );
      case ProctorTab.calculators:
        return const ProctorToolsTab();
    }
  }

  Future<void> _showRosterSheet(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => Consumer(
        builder: (ctx, ref2, _) {
          final session = ref2.watch(proctorSessionProvider);
          final selectedId = session.selectedId;

          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Roster'),
                  subtitle: Text(
                      '${session.roster.length} participant${session.roster.length == 1 ? '' : 's'}'),
                  trailing: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await _showAddParticipantDialog(context, ref);
                    },
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add'),
                  ),
                ),
                const Divider(height: 1),
                if (session.roster.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No participants yet. Tap Add.'),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final p in session.roster)
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: ArmyColors.gold,
                              foregroundColor: Colors.black,
                              child: Center(
                                child: Text(
                                  _participantShortLabel(p),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                            title: Text(p.name?.trim().isNotEmpty == true
                                ? p.name!.trim()
                                : 'Participant'),
                            subtitle: Text(
                                'Age ${p.age} • ${p.sex == AftSex.male ? 'Male' : 'Female'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Center(
                                    child: p.id == selectedId
                                        ? const Icon(Icons.check, size: 18)
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () async {
                                    await _showEditParticipantDialog(
                                        context, ref, p);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20),
                                  onPressed: () async {
                                    await ref
                                        .read(proctorSessionProvider.notifier)
                                        .removeParticipant(p.id);
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              await ref
                                  .read(proctorSessionProvider.notifier)
                                  .selectParticipant(p.id);
                              if (context.mounted) Navigator.of(ctx).pop();
                            },
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _participantShortLabel(ProctorParticipant p) {
    final n = p.name?.trim();
    if (n != null && n.isNotEmpty) return n[0].toUpperCase();
    return 'P';
  }

  Future<void> _showAddParticipantDialog(
      BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final ageCtrl = TextEditingController();
    AftSex sex = AftSex.male;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add participant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: '17-80',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<AftSex>(
                segments: const [
                  ButtonSegment(value: AftSex.male, label: Text('Male')),
                  ButtonSegment(value: AftSex.female, label: Text('Female')),
                ],
                selected: {sex},
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  setState(() => sex = sel.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final age = int.tryParse(ageCtrl.text.trim());
    if (age == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid age')),
        );
      }
      return;
    }
    final clampedAge = age.clamp(17, 80);

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final p = ProctorParticipant(
      id: id,
      name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      age: clampedAge,
      sex: sex,
    );

    await ref.read(proctorSessionProvider.notifier).addParticipant(p);

    // Ensure proctor profile reflects the new selection.
    ref.read(proctorProfileProvider.notifier).syncFromParticipant(p);
  }

  Future<void> _showEditParticipantDialog(
    BuildContext context,
    WidgetRef ref,
    ProctorParticipant existing,
  ) async {
    final nameCtrl = TextEditingController(text: existing.name ?? '');
    final ageCtrl = TextEditingController(text: '${existing.age}');
    AftSex sex = existing.sex;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Edit participant'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Age',
                  hintText: '17-80',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<AftSex>(
                segments: const [
                  ButtonSegment(value: AftSex.male, label: Text('Male')),
                  ButtonSegment(value: AftSex.female, label: Text('Female')),
                ],
                selected: {sex},
                onSelectionChanged: (sel) {
                  if (sel.isEmpty) return;
                  setState(() => sex = sel.first);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    final age = int.tryParse(ageCtrl.text.trim());
    if (age == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid age')),
        );
      }
      return;
    }

    final updated = existing.copyWith(
      name: nameCtrl.text.trim().isEmpty ? null : nameCtrl.text.trim(),
      age: age.clamp(17, 80),
      sex: sex,
    );

    await ref.read(proctorSessionProvider.notifier).updateParticipant(updated);

    // If this participant is selected, sync proctor profile immediately.
    final selected = ref.read(selectedProctorParticipantProvider);
    if (selected?.id == updated.id) {
      ref.read(proctorProfileProvider.notifier).syncFromParticipant(updated);
    }
  }
}

class _RosterChip extends StatelessWidget {
  const _RosterChip({
    required this.selected,
    required this.rosterCount,
    required this.onTap,
  });

  final ProctorParticipant? selected;
  final int rosterCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = selected == null
        ? (rosterCount == 0 ? 'Roster' : 'Roster ($rosterCount)')
        : (selected!.name?.trim().isNotEmpty == true
            ? selected!.name!.trim()
            : 'Participant');

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: ArmyColors.gold,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_outlined, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimingTab extends ConsumerWidget {
  const _TimingTab({required this.event, required this.onEventChanged});

  final AftEvent event;
  final ValueChanged<AftEvent> onEventChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProctorParticipantProvider);
    if (selected == null) {
      return const _PlaceholderCard(
        title: 'Timing',
        body: 'Select a participant to start timing.',
      );
    }
    final segments = const [
      ButtonSegment(value: AftEvent.sdc, label: Text('SDC')),
      ButtonSegment(value: AftEvent.plank, label: Text('PLK')),
      ButtonSegment(value: AftEvent.run2mi, label: Text('2MR')),
      ButtonSegment(value: AftEvent.pushUps, label: Text('HRP')),
    ];

    final title = switch (event) {
      AftEvent.sdc => 'Sprint-Drag-Carry',
      AftEvent.plank => 'Plank',
      AftEvent.run2mi => '2-Mile Run',
      AftEvent.pushUps => 'Hand-Release Push-ups (2:00)',
      _ => 'Timing',
    };

    // Keyed by participant+event so switching participants resets timers & thresholds.
    final key = ValueKey('${selected.id}:${event.name}');

    return Column(
      children: [
        SegmentedButton<AftEvent>(
          segments: segments,
          selected: {event},
          onSelectionChanged: (sel) {
            if (sel.isEmpty) return;
            onEventChanged(sel.first);
          },
        ),
        const SizedBox(height: 10),
        if (event == AftEvent.pushUps)
          _HrpPage(key: key, title: title)
        else
          _TimedEventPage(
            key: key,
            title: title,
            event: event,
          ),
      ],
    );
  }
}

class _SdcInfoButton extends StatelessWidget {
  const _SdcInfoButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return IconButton(
      tooltip: 'SDC segment targets',
      onPressed: onPressed,
      iconSize: 16,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      icon: Icon(Icons.info_outline, color: color),
    );
  }
}

class _HrpPage extends ConsumerStatefulWidget {
  const _HrpPage({required this.title, super.key});

  final String title;

  @override
  ConsumerState<_HrpPage> createState() => _HrpPageState();
}

class _HrpPageState extends ConsumerState<_HrpPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _now = DateTime.now();
  ProviderSubscription<int>? _repsSub;

  @override
  void initState() {
    super.initState();

    final pid = ref.read(selectedProctorParticipantProvider)?.id;
    if (pid != null) {
      // Keep HRP reps synced to per-participant inputs so the score badge updates
      // immediately and survives roster switching.
      _repsSub = ref.listenManual<int>(
        proctorTimingProvider
            .select((s) => s.byParticipant[pid]?.hrp.reps ?? 0),
        (prev, next) {
          if (prev == next) return;
          ref.read(proctorInputsStateProvider.notifier).setPushUps(pid, next);
        },
      );
    }

    _ticker = createTicker((_) {
      // repaint while visible
      _now = DateTime.now();
      if (mounted) setState(() {});
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _repsSub?.close();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedProctorParticipantProvider);
    if (selected == null) return const SizedBox.shrink();

    final profile = ref.watch(proctorProfileProvider);

    final timingCtrl = ref.read(proctorTimingProvider.notifier);
    final hrp = ref.watch(
        proctorTimingProvider.select((s) => s.byParticipant[selected.id]?.hrp));
    final hrpState = hrp ?? ProctorHrpState.initial();
    if (hrpState.isRunning) {
      timingCtrl.normalizeHrpIfFinished(selected.id);
    }

    final remaining = hrpState.remainingNow(_now);
    final elapsed = hrpState.elapsedNow(_now);
    final isRunning = hrpState.isRunning;

    final computed = ref.watch(proctorComputedProvider);
    final score = computed.pushUpsScore;

    final hrpTh = hrpRepThresholdsFor(
      profile: profile,
      standard: profile.standard,
    );

    final reps100 = hrpTh.reps100;
    final reps60 = hrpTh.reps60;

    final needed60Now = (reps60 == null)
        ? null
        : neededHrpRepsByNow(targetReps: reps60, elapsed: elapsed);
    final needed100Now = (reps100 == null)
        ? null
        : neededHrpRepsByNow(targetReps: reps100, elapsed: elapsed);

    final onTrack60 =
        needed60Now == null ? null : (hrpState.reps >= needed60Now);
    final onTrack100 =
        needed100Now == null ? null : (hrpState.reps >= needed100Now);

    final badgeFail = score != null && score < 60;
    final badgeBg = badgeFail ? Colors.red : ArmyColors.gold;
    final badgeFg = badgeFail ? Colors.white : Colors.black;

    final canStart = !isRunning && remaining > Duration.zero;
    final canStop = isRunning;
    final canReset = !isRunning && (hrpState.elapsedBefore > Duration.zero);
    final canSave = !isRunning;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                if (score != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$score',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w900, color: badgeFg),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                formatMmSs(remaining),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            if (reps60 != null && reps100 != null)
              _HrpPaceTimeline(
                currentReps: hrpState.reps,
                target60: reps60,
                target100: reps100,
                needed60Now: needed60Now ?? 0,
                needed100Now: needed100Now ?? 0,
                onTrack60: onTrack60 ?? false,
                onTrack100: onTrack100 ?? false,
              )
            else
              Text(
                'Pace timeline unavailable (missing standards thresholds).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: canStart
                        ? () => timingCtrl.startHrp(selected.id)
                        : null,
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed:
                        canStop ? () => timingCtrl.stopHrp(selected.id) : null,
                    child: const Text('Stop'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canReset
                        ? () => timingCtrl.resetHrp(selected.id)
                        : null,
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canSave
                        ? () {
                            ref
                                .read(proctorInputsStateProvider.notifier)
                                .setPushUps(selected.id, hrpState.reps);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Saved HRP: ${hrpState.reps} reps')),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => timingCtrl.incHrpReps(selected.id),
                    child: Text('+1 Rep (${hrpState.reps})'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: FilledButton.tonal(
                    onPressed: () => timingCtrl.decHrpReps(selected.id),
                    child: const Icon(Icons.remove, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HrpPaceTimeline extends StatelessWidget {
  const _HrpPaceTimeline({
    required this.currentReps,
    required this.target60,
    required this.target100,
    required this.needed60Now,
    required this.needed100Now,
    required this.onTrack60,
    required this.onTrack100,
  });

  final int currentReps;
  final int target60;
  final int target100;
  final int needed60Now;
  final int needed100Now;
  final bool onTrack60;
  final bool onTrack100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double pos(int v) {
      if (target100 <= 0) return 0;
      return (v / target100).clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pace (by now)',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'Current: $currentReps',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(color: theme.colorScheme.outline),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              // 60-pace marker
              Positioned(
                left:
                    pos(needed60Now) * (MediaQuery.of(context).size.width - 64),
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: ArmyColors.gold),
              ),
              // 100-pace marker
              Positioned(
                left: pos(needed100Now) *
                    (MediaQuery.of(context).size.width - 64),
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.green),
              ),
              // current marker
              Positioned(
                left:
                    pos(currentReps) * (MediaQuery.of(context).size.width - 64),
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: theme.colorScheme.onSurface),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _StatusPillMini(
              ok: onTrack60,
              text: onTrack60 ? 'On track (60)' : 'Behind (60)',
            ),
            _StatusPillMini(
              ok: onTrack100,
              text: onTrack100 ? 'On track (100)' : 'Behind (100)',
            ),
          ],
        ),
      ],
    );
  }
}

class _SdcPaceTimeline extends StatelessWidget {
  const _SdcPaceTimeline({
    required this.segmentLabel,
    required this.segmentIndex,
    required this.segmentCount,
    required this.segmentElapsed,
    required this.currentElapsed,
    required this.overallTarget60,
    required this.overallTarget100,
    required this.target60,
    required this.target100,
    required this.onTrack60,
    required this.onTrack100,
  });

  final String segmentLabel;
  final int segmentIndex;
  final int segmentCount;
  final Duration segmentElapsed;
  final Duration currentElapsed;
  final Duration overallTarget60;
  final Duration overallTarget100;
  final Duration target60;
  final Duration target100;
  final bool onTrack60;
  final bool onTrack100;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxTarget =
        overallTarget60 > overallTarget100 ? overallTarget60 : overallTarget100;

    double pos(Duration v) {
      final maxMs = maxTarget.inMilliseconds;
      if (maxMs <= 0) return 0;
      return (v.inMilliseconds / maxMs).clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pace (through segment)',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Segment ${segmentIndex + 1}/$segmentCount: $segmentLabel',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Current: ${formatMmSsMillis(currentElapsed)}',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Segment time: ${formatMmSsMillis(segmentElapsed)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxOffset =
                  (constraints.maxWidth - 2).clamp(0.0, double.infinity);
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  // 60-pace marker
                  Positioned(
                    left: pos(target60) * maxOffset,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: ArmyColors.gold),
                  ),
                  // 100-pace marker
                  Positioned(
                    left: pos(target100) * maxOffset,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.green),
                  ),
                  // current marker
                  Positioned(
                    left: pos(currentElapsed) * maxOffset,
                    top: 0,
                    bottom: 0,
                    child:
                        Container(width: 3, color: theme.colorScheme.onSurface),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: [
            _StatusPillMini(
              ok: onTrack60,
              text: onTrack60 ? 'On track (60)' : 'Behind (60)',
            ),
            _StatusPillMini(
              ok: onTrack100,
              text: onTrack100 ? 'On track (100)' : 'Behind (100)',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusPillMini extends StatelessWidget {
  const _StatusPillMini({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bg = ok ? Colors.green : Colors.red;
    final fg = Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}

class _TimedEventPage extends ConsumerStatefulWidget {
  const _TimedEventPage({required this.title, required this.event, super.key});

  final String title;
  final AftEvent event;

  @override
  ConsumerState<_TimedEventPage> createState() => _TimedEventPageState();
}

class _TimedEventPageState extends ConsumerState<_TimedEventPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      // repaint while visible so elapsed time updates; actual elapsed is derived
      // from provider state + DateTime.now().
      _now = DateTime.now();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final selected = ref.read(selectedProctorParticipantProvider);
    if (selected == null) return;
    final sw = ref
        .read(proctorTimingProvider.notifier)
        .stopwatchOf(selected.id, widget.event);
    final elapsed = sw.elapsedNow(DateTime.now());
    if (sw.isRunning || elapsed.inSeconds == 0) return;
    final inputs = ref.read(proctorInputsStateProvider.notifier);
    switch (widget.event) {
      case AftEvent.sdc:
        inputs.setSdc(selected.id, elapsed);
        break;
      case AftEvent.plank:
        inputs.setPlank(selected.id, elapsed);
        break;
      case AftEvent.run2mi:
        inputs.setRun2mi(selected.id, elapsed);
        break;
      default:
        return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved ${widget.title}: ${formatMmSsMillis(elapsed)}'),
      ),
    );
  }

  String _lapButtonLabelFor({required AftEvent event, required int lapCount}) {
    if (event != AftEvent.sdc) return 'Lap';
    // lapCount is how many laps have already been recorded.
    // During SDC, the next segment to begin is:
    // 0 => Drag (Sprint is ongoing)
    // 1 => Lateral
    // 2 => Carry
    // 3 => Final Sprint
    // 4 => Finish
    if (lapCount >= kSdcSegments.length - 1) return 'Finish';
    if (lapCount == 0) return kSdcSegments[1];
    return kSdcSegments[lapCount + 1];
  }

  void _resetSelected(BuildContext context) {
    final selected = ref.read(selectedProctorParticipantProvider);
    if (selected == null) return;

    final timingCtrl = ref.read(proctorTimingProvider.notifier);
    final inputsCtrl = ref.read(proctorInputsStateProvider.notifier);

    // Reset timer state
    timingCtrl.resetStopwatch(selected.id, widget.event);
    // Clear saved input for this participant+event (so score clears)
    inputsCtrl.clearEvent(selected.id, widget.event);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reset ${widget.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedProctorParticipantProvider);
    if (selected == null) return const SizedBox.shrink();

    final timingCtrl = ref.read(proctorTimingProvider.notifier);
    final sw = ref.watch(proctorTimingProvider.select(
        (s) => s.byParticipant[selected.id]?.stopwatches[widget.event]));
    final swState = sw ?? ProctorStopwatchState.initial();
    final elapsed = swState.elapsedNow(_now);

    // Only tick while the event timer is running.
    if (swState.isRunning && !_ticker.isActive) {
      _ticker.start();
    } else if (!swState.isRunning && _ticker.isActive) {
      _ticker.stop();
    }

    final profile = ref.watch(proctorProfileProvider);
    final computed = ref.watch(proctorComputedProvider);
    final th = thresholdsFor(
        event: widget.event, profile: profile, standard: profile.standard);

    final score = switch (widget.event) {
      AftEvent.sdc => computed.sdcScore,
      AftEvent.plank => computed.plankScore,
      AftEvent.run2mi => computed.run2miScore,
      _ => null,
    };

    final sdcTarget100 = widget.event == AftEvent.sdc
        ? _parseDurationThreshold(th.pts100)
        : null;
    final sdcTarget60 =
        widget.event == AftEvent.sdc ? _parseDurationThreshold(th.pts60) : null;
    final sdcSegmentCount = kSdcSegments.length;
    final sdcLapCount = swState.lapsCumulative.length;
    final sdcSegmentIndex = widget.event == AftEvent.sdc
        ? (sdcLapCount >= sdcSegmentCount ? sdcSegmentCount - 1 : sdcLapCount)
        : 0;
    final sdcSegmentLabel = kSdcSegments[sdcSegmentIndex];
    final sdcSegmentStartIndex = sdcSegmentIndex - 1;
    final sdcSegmentStart = (sdcSegmentStartIndex >= 0 &&
            sdcSegmentStartIndex < swState.lapsCumulative.length)
        ? swState.lapsCumulative[sdcSegmentStartIndex]
        : Duration.zero;
    final sdcSegmentElapsed =
        elapsed >= sdcSegmentStart ? elapsed - sdcSegmentStart : Duration.zero;
    final sdcCumulativeTarget60 = sdcTarget60 == null
        ? null
        : sdcCumulativeTarget(sdcTarget60, sdcSegmentIndex);
    final sdcCumulativeTarget100 = sdcTarget100 == null
        ? null
        : sdcCumulativeTarget(sdcTarget100, sdcSegmentIndex);
    final sdcPaceAvailable =
        sdcCumulativeTarget100 != null && sdcCumulativeTarget60 != null;
    final sdcOnTrack100 = sdcCumulativeTarget100 == null
        ? null
        : elapsed <= sdcCumulativeTarget100;
    final sdcOnTrack60 =
        sdcCumulativeTarget60 == null ? null : elapsed <= sdcCumulativeTarget60;

    final badgeFail = score != null && score < 60;
    final badgeBg = badgeFail ? Colors.red : ArmyColors.gold;
    final badgeFg = badgeFail ? Colors.white : Colors.black;

    final canStart = !swState.isRunning && elapsed == Duration.zero;
    final canStop = swState.isRunning;
    final canReset = !swState.isRunning && elapsed.inSeconds > 0;
    final canSave = !swState.isRunning && elapsed.inSeconds > 0;
    final cap = widget.event == AftEvent.run2mi ? 25 : 5;
    final canLap = widget.event != AftEvent.plank &&
        swState.isRunning &&
        (swState.lapsCumulative.length < cap);

    final lapLabel = _lapButtonLabelFor(
      event: widget.event,
      lapCount: swState.lapsCumulative.length,
    );

    final laps = _deriveLapEntries(widget.event, swState.lapsCumulative);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.title,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (widget.event == AftEvent.sdc) ...[
                        const SizedBox(width: 6),
                        _SdcInfoButton(
                          onPressed: () =>
                              showSdcSegmentInfoSheet(context, profile),
                        ),
                      ],
                    ],
                  ),
                ),
                if (score != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$score',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: badgeFg,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                formatMmSsMillis(elapsed),
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _ThresholdPill(label: '100', value: th.pts100)),
                const SizedBox(width: 10),
                Expanded(
                    child: _ThresholdPill(label: 'Pass (60)', value: th.pts60)),
              ],
            ),
            if (widget.event == AftEvent.sdc) ...[
              const SizedBox(height: 10),
              if (sdcPaceAvailable)
                _SdcPaceTimeline(
                  segmentLabel: sdcSegmentLabel,
                  segmentIndex: sdcSegmentIndex,
                  segmentCount: sdcSegmentCount,
                  segmentElapsed: sdcSegmentElapsed,
                  currentElapsed: elapsed,
                  overallTarget60: sdcTarget60!,
                  overallTarget100: sdcTarget100!,
                  target60: sdcCumulativeTarget60!,
                  target100: sdcCumulativeTarget100!,
                  onTrack60: sdcOnTrack60 ?? false,
                  onTrack100: sdcOnTrack100 ?? false,
                )
              else
                Text(
                  'Pace timeline unavailable (missing standards thresholds).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: canStart
                        ? () =>
                            timingCtrl.startStopwatch(selected.id, widget.event)
                        : null,
                    child: const Text('Start'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: canStop
                        ? () =>
                            timingCtrl.stopStopwatch(selected.id, widget.event)
                        : null,
                    child: const Text('Stop'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: canLap
                        ? () => timingCtrl.lapStopwatch(
                              participantId: selected.id,
                              event: widget.event,
                              cap: cap,
                              autoStopOnCapReached:
                                  widget.event == AftEvent.sdc,
                            )
                        : null,
                    child: Text(lapLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: canReset ? () => _resetSelected(context) : null,
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canSave ? () => _save(context) : null,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
            if (laps.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Laps',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              for (final lap in laps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          lap.label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        formatMmSsMillis(lap.split),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatMmSsMillis(lap.cumulative),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LapEntry {
  final String label;
  final Duration cumulative;
  final Duration split;
  const _LapEntry({
    required this.label,
    required this.cumulative,
    required this.split,
  });
}

List<_LapEntry> _deriveLapEntries(AftEvent event, List<Duration> cumulative) {
  final out = <_LapEntry>[];
  Duration prev = Duration.zero;
  for (int i = 0; i < cumulative.length; i++) {
    final cum = cumulative[i];
    final split = cum - prev;
    prev = cum;
    out.add(
      _LapEntry(
        label: _lapLabelFor(event, i),
        cumulative: cum,
        split: split,
      ),
    );
  }
  return out;
}

String _lapLabelFor(AftEvent event, int index) {
  if (event == AftEvent.sdc) {
    return index < kSdcSegments.length
        ? kSdcSegments[index]
        : 'Lap ${index + 1}';
  }
  // 2MR
  return 'Lap ${index + 1}';
}

class _ThresholdPill extends StatelessWidget {
  const _ThresholdPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
