import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/widgets/aft_pill.dart';
import 'package:aft_firebase_app/widgets/aft_choice_chip.dart';
import 'package:aft_firebase_app/widgets/aft_event_card.dart';
import 'package:aft_firebase_app/widgets/aft_score_ring.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';

/// Home screen layout (first page) using Riverpod state.
/// - Total card with right-side pass/fail box (gold outline)
/// - Context row card: Age dropdown; Sex chips; Test Date pill (no picker)
/// - Event cards: MDL, HR Push-ups, Sprint-Drag-Carry (with inputs)
/// Score rings and total are computed via providers + scoring service.
class FeatureHomeScreen extends ConsumerStatefulWidget {
  const FeatureHomeScreen({super.key});

  @override
  ConsumerState<FeatureHomeScreen> createState() => _FeatureHomeScreenState();
}

class _FeatureHomeScreenState extends ConsumerState<FeatureHomeScreen> {
  // Inputs
  final _mdlController = TextEditingController();
  final _puController = TextEditingController();
  final _sdcController = TextEditingController(); // mm:ss
  String? _mdlError;
  String? _puError;
  String? _sdcError;

  @override
  void dispose() {
    _mdlController.dispose();
    _puController.dispose();
    _sdcController.dispose();
    super.dispose();
  }

  void _onMdlChanged(String value) {
    if (value.isEmpty) {
      setState(() => _mdlError = null);
      ref.read(aftInputsProvider.notifier).setMdlLbs(null);
      return;
    }
    final v = int.tryParse(value);
    if (v == null || v < 0) {
      setState(() => _mdlError = 'Enter a non-negative number');
      ref.read(aftInputsProvider.notifier).setMdlLbs(null);
    } else {
      setState(() => _mdlError = null);
      ref.read(aftInputsProvider.notifier).setMdlLbs(v);
    }
  }

  void _onPuChanged(String value) {
    if (value.isEmpty) {
      setState(() => _puError = null);
      ref.read(aftInputsProvider.notifier).setPushUps(null);
      return;
    }
    final v = int.tryParse(value);
    if (v == null || v < 0) {
      setState(() => _puError = 'Enter a non-negative number');
      ref.read(aftInputsProvider.notifier).setPushUps(null);
    } else {
      setState(() => _puError = null);
      ref.read(aftInputsProvider.notifier).setPushUps(v);
    }
  }

  void _onSdcChanged(String value) {
    if (value.isEmpty) {
      setState(() => _sdcError = null);
      ref.read(aftInputsProvider.notifier).setSdc(null);
      return;
    }
    final dur = _parseMmSs(value);
    if (dur == null) {
      setState(() => _sdcError = 'Use mm:ss');
      ref.read(aftInputsProvider.notifier).setSdc(null);
    } else {
      setState(() => _sdcError = null);
      ref.read(aftInputsProvider.notifier).setSdc(dur);
    }
  }

  Duration? _parseMmSs(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final m = int.tryParse(parts[0]);
    final s = int.tryParse(parts[1]);
    if (m == null || s == null || m < 0 || s < 0 || s > 59) return null;
    return Duration(minutes: m, seconds: s);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final profile = ref.watch(aftProfileProvider);
    final computed = ref.watch(aftComputedProvider);
    final auth = ref.watch(authStateProvider);
    final bool canSave = auth.isSignedIn && computed.total != null;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SizedBox(height: 12),

        // Total card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      computed.total == null ? 'Total: —' : 'Total: ${computed.total}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: ShapeDecoration(
                      shape: StadiumBorder(
                        side: BorderSide(color: ArmyColors.gold, width: 1.2),
                      ),
                    ),
                    child: Text(
                      '—', // Placeholder pass/fail
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: auth.isSignedIn ? 'Save results' : 'Sign in to save results',
                    preferBelow: false,
                    child: FilledButton.icon(
                      onPressed: canSave
                          ? () async {
                              final profileNow = ref.read(aftProfileProvider);
                              final inputsNow = ref.read(aftInputsProvider);
                              final computedNow = ref.read(aftComputedProvider);
                              final repo = ref.read(aftRepositoryProvider);
                              final userId = ref.read(authStateProvider).userId!;
                              final set = ScoreSet(
                                profile: profileNow,
                                inputs: inputsNow,
                                computed: computedNow,
                                createdAt: DateTime.now(),
                              );
                              await repo.saveScoreSet(userId: userId, set: set);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Saved')),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Context row card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Context', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Age dropdown as pill
                      AftPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Age'),
                            const SizedBox(width: 8),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: profile.age,
                                dropdownColor: cs.surface,
                                items: List.generate(63, (i) => 18 + i)
                                    .map((a) => DropdownMenuItem(
                                          value: a,
                                          child: Text('$a'),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    ref.read(aftProfileProvider.notifier).setAge(v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Sex chips
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AftChoiceChip(
                            label: 'Male',
                            selected: profile.sex == AftSex.male,
                            onSelected: (val) => ref.read(aftProfileProvider.notifier).setSex(AftSex.male),
                          ),
                          const SizedBox(width: 8),
                          AftChoiceChip(
                            label: 'Female',
                            selected: profile.sex == AftSex.female,
                            onSelected: (val) => ref.read(aftProfileProvider.notifier).setSex(AftSex.female),
                          ),
                        ],
                      ),

                      // Test date pill (no picker)
                      AftPill(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Test Date'),
                            const SizedBox(width: 8),
                            Text(
                              profile.testDate == null ? '—' : _fmtDate(profile.testDate!),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // MDL card
        AftEventCard(
          title: '3-Rep Max Deadlift (MDL)',
          icon: Icons.fitness_center,
          trailing: AftScoreRing(score: computed.mdlScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weight (lbs)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _mdlController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onMdlChanged,
                decoration: InputDecoration(
                  hintText: 'e.g., 185',
                  errorText: _mdlError,
                  suffixText: 'lbs',
                ),
              ),
            ],
          ),
        ),

        // Push-ups card
        AftEventCard(
          title: 'Hand-Release Push-ups',
          icon: Icons.accessibility_new,
          trailing: AftScoreRing(score: computed.pushUpsScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Repetitions', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _puController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onPuChanged,
                decoration: InputDecoration(
                  hintText: 'e.g., 30',
                  errorText: _puError,
                ),
              ),
            ],
          ),
        ),

        // Sprint-Drag-Carry card
        AftEventCard(
          title: 'Sprint-Drag-Carry',
          icon: Icons.timer_outlined,
          trailing: AftScoreRing(score: computed.sdcScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time (mm:ss)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _sdcController,
                keyboardType: TextInputType.number,
                inputFormatters: [_MmSsFormatter()],
                onChanged: _onSdcChanged,
                decoration: InputDecoration(
                  hintText: 'e.g., 01:45',
                  errorText: _sdcError,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }
}

/// Basic mm:ss input formatter.
/// - Only digits are accepted; a colon is inserted after 2 digits
/// - Limits length to 5 (mm:ss)
class _MmSsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 4) text = text.substring(0, 4);

    String formatted;
    if (text.length <= 2) {
      formatted = text;
    } else {
      formatted = '${text.substring(0, 2)}:${text.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
