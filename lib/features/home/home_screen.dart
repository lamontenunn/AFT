import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/widgets/aft_pill.dart';
import 'package:aft_firebase_app/widgets/aft_choice_chip.dart';
import 'package:aft_firebase_app/widgets/aft_event_card.dart';
import 'package:aft_firebase_app/widgets/aft_score_ring.dart';
import 'package:aft_firebase_app/widgets/aft_stepper.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/features/saves/editing.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/features/aft/logic/slider_config.dart' as slidercfg;
import 'package:aft_firebase_app/widgets/aft_event_slider.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';
import 'package:aft_firebase_app/router/app_router.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:aft_firebase_app/widgets/aft_svg_icon.dart';

/// Home screen layout (first page) using Riverpod state.
/// - Total card with right-side pass/fail box (gold outline) + Save button (auth-gated)
/// - Context row card: Age dropdown; Sex chips; Test Date pill (no picker)
/// - Event cards: MDL, HR Push-ups, Sprint-Drag-Carry (with inputs + steppers)
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
  final _plankController = TextEditingController(); // mm:ss
  final _run2miController = TextEditingController(); // mm:ss

  // Focus management for better keyboard UX on mobile
  final _mdlFocus = FocusNode();
  final _puFocus = FocusNode();
  final _sdcFocus = FocusNode();
  final _plankFocus = FocusNode();
  final _runFocus = FocusNode();

  String? _mdlError;
  String? _puError;
  String? _sdcError;
  String? _plankError;
  String? _run2miError;

  // Apply default profile (from Settings) once per visit when not editing
  bool _prefillApplied = false;


  @override
  void dispose() {
    _mdlController.dispose();
    _puController.dispose();
    _sdcController.dispose();
    _plankController.dispose();
    _run2miController.dispose();

    // Dispose focus nodes
    _mdlFocus.dispose();
    _puFocus.dispose();
    _sdcFocus.dispose();
    _plankFocus.dispose();
    _runFocus.dispose();

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
    final dur = parseMmSs(value);
    if (dur == null) {
      setState(() => _sdcError = 'Use mm:ss');
      ref.read(aftInputsProvider.notifier).setSdc(null);
    } else {
      setState(() => _sdcError = null);
      ref.read(aftInputsProvider.notifier).setSdc(dur);
    }
  }

  void _onPlankChanged(String value) {
    if (value.isEmpty) {
      setState(() => _plankError = null);
      ref.read(aftInputsProvider.notifier).setPlank(null);
      return;
    }
    final dur = parseMmSs(value);
    if (dur == null) {
      setState(() => _plankError = 'Use mm:ss');
      ref.read(aftInputsProvider.notifier).setPlank(null);
    } else {
      setState(() => _plankError = null);
      ref.read(aftInputsProvider.notifier).setPlank(dur);
    }
  }

  void _onRunChanged(String value) {
    if (value.isEmpty) {
      setState(() => _run2miError = null);
      ref.read(aftInputsProvider.notifier).setRun2mi(null);
      return;
    }
    final dur = parseMmSs(value);
    if (dur == null) {
      setState(() => _run2miError = 'Use mm:ss');
      ref.read(aftInputsProvider.notifier).setRun2mi(null);
    } else {
      setState(() => _run2miError = null);
      ref.read(aftInputsProvider.notifier).setRun2mi(dur);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final profile = ref.watch(aftProfileProvider);
    final computed = ref.watch(aftComputedProvider);
    final inputs = ref.watch(aftInputsProvider);
    final editing = ref.watch(editingSetProvider);
    // Light haptic when total score transitions to a valid number.
    ref.listen<AftComputed>(aftComputedProvider, (prev, next) {
      if (next.total != null && next.total != prev?.total) {
        HapticFeedback.lightImpact();
      }
    });
    final auth = ref.watch(authStateProvider);
    final bool canSave = auth.isSignedIn && computed.total != null;

    // React to Settings changes while on Calculator (apply defaults when not editing)
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      final editingNow = ref.read(editingSetProvider);
      if (!next.applyDefaultsOnCalculator || editingNow != null) return;

      // Compute age from DOB and apply if changed
      final dob = next.defaultBirthdate;
      if (dob != null) {
        final now = DateTime.now();
        int age = now.year - dob.year;
        final hasHadBirthday = (now.month > dob.month) ||
            (now.month == dob.month && now.day >= dob.day);
        if (!hasHadBirthday) age--;
        // Clamp to supported dropdown range [17..80] to avoid invalid value assertions
        int clamped = age;
        if (clamped < 17) clamped = 17;
        if (clamped > 80) clamped = 80;
        final current = ref.read(aftProfileProvider).age;
        if (current != clamped) {
          ref.read(aftProfileProvider.notifier).setAge(clamped);
        }
      }
      // Apply sex if changed
      final sex = next.defaultSex;
      if (sex != null && ref.read(aftProfileProvider).sex != sex) {
        ref.read(aftProfileProvider.notifier).setSex(sex);
      }
    });

    // Prefill Calculator profile defaults and default test date when not editing
    if (!_prefillApplied) {
      _prefillApplied = true;
      final settings = ref.read(settingsProvider);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final prof = ref.read(aftProfileProvider.notifier);
        final currentProfile = ref.read(aftProfileProvider);

        // Default test date to today if not set and not editing
        if (editing == null && currentProfile.testDate == null) {
          prof.setTestDate(DateTime.now());
        }

        // Apply other defaults only when enabled in Settings and not editing
        if (settings.applyDefaultsOnCalculator && editing == null) {
          // Default birthdate -> compute age today
          final dob = settings.defaultBirthdate;
          if (dob != null) {
            final now = DateTime.now();
            int age = now.year - dob.year;
            final hasHadBirthday = (now.month > dob.month) ||
                (now.month == dob.month && now.day >= dob.day);
            if (!hasHadBirthday) age--;
            // Clamp to supported dropdown range [17..80]
            int clampedAge = age;
            if (clampedAge < 17) clampedAge = 17;
            if (clampedAge > 80) clampedAge = 80;
            prof.setAge(clampedAge);
          }
          // Default sex
          final defSex = settings.defaultSex;
          if (defSex != null) {
            prof.setSex(defSex);
          }
        }
      });
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: EdgeInsets.only(bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
      children: [


        const SizedBox(height: 12),

        // Total card
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Semantics(
                      label: 'Total score',
                      value: computed.total?.toString() ?? 'No total yet',
                      child: Text(
                        computed.total == null ? 'Total: —' : 'Total: ${computed.total}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  if (editing != null)
                    TextButton.icon(
                      onPressed: () async {
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
                        if (ok == true) {
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
                            final p = original!.profile;
                            final i = original!.inputs;
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
                          }
                          ref.read(editingSetProvider.notifier).state = null;
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Update canceled')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  Tooltip(
                    message: auth.isSignedIn
                        ? (editing != null ? 'Update saved set' : 'Save results')
                        : 'Sign in to save results',
                    preferBelow: false,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: canSave
                          ? () async {
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
                                  final testDateLabel = profileNow.testDate == null
                                      ? '—'
                                      : formatYmd(profileNow.testDate!);
                                  final totalLabel = computedNow.total?.toString() ?? '—';
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Test updated'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Test date: $testDateLabel'),
                                          Text('Total: $totalLabel'),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('Close'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            Navigator.pushNamed(context, Routes.savedSets);
                                          },
                                          child: const Text('View saved sets'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              } else {
                                await repo.saveScoreSet(userId: userId, set: set);
                                if (context.mounted) {
                                  final testDateLabel = profileNow.testDate == null
                                      ? '—'
                                      : formatYmd(profileNow.testDate!);
                                  final totalLabel = computedNow.total?.toString() ?? '—';
                                  await showDialog<void>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Test saved'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Test date: $testDateLabel'),
                                          Text('Total: $totalLabel'),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(ctx).pop(),
                                          child: const Text('Close'),
                                        ),
                                        FilledButton(
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            Navigator.pushNamed(context, Routes.savedSets);
                                          },
                                          child: const Text('View saved sets'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(editing != null ? 'Update' : 'Save'),
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
                  Semantics(
                    header: true,
                    child: Text('Context', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
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
                                items: List.generate(64, (i) => 17 + i)
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


                      // Test date pill (picker + clear)
                      AftPill(
                        onTap: () async {
                          final initial = profile.testDate ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(2018, 1, 1),
                            lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                            helpText: 'Select test date',
                          );
                          if (picked != null) {
                            ref.read(aftProfileProvider.notifier).setTestDate(picked);
                          }
                        },
                        tooltip: 'Set test date',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Test Date'),
                            const SizedBox(width: 8),
                            Text(
                              profile.testDate == null ? '—' : formatYmd(profile.testDate!),
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (profile.testDate != null) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Clear date',
                                child: InkWell(
                                  onTap: () {
                                    ref.read(aftProfileProvider.notifier).setTestDate(null);
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: const Padding(
                                    padding: EdgeInsets.all(2),
                                    child: Icon(Icons.close, size: 16),
                                  ),
                                ),
                              ),
                            ],
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
          leading: const AftSvgIcon(
            'assets/icons/deadlift.svg',
            size: 24,
            padding: const EdgeInsets.all(2),
            colorFilter: const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
          ),
          trailing: AftScoreRing(score: computed.mdlScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Weight (lbs)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mdlController,
                      focusNode: _mdlFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_puFocus),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onMdlChanged,
                      scrollPadding: const EdgeInsets.only(bottom: 80),
                      decoration: InputDecoration(
                        labelText: 'MDL weight',
                        hintText: 'e.g., 185',
                        errorText: _mdlError,
                        suffixText: 'lbs',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AftStepper(
                    value: int.tryParse(_mdlController.text) ?? 0,
                    min: 0,
                    step: 5,
                    onChanged: (v) {
                      _mdlController.text = '$v';
                      _onMdlChanged(_mdlController.text);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final cfg = slidercfg.getSliderConfig(profile.standard, profile, AftEvent.mdl);
                  final curr = ((inputs.mdlLbs ?? int.tryParse(_mdlController.text) ?? cfg.min.toInt())
                      .clamp(cfg.min.toInt(), cfg.max.toInt())).toInt();
                  return AftIntSlider(
                    label: 'Weight',
                    value: curr,
                    suffix: 'lbs',
                    config: cfg,
                    onChanged: (v) {
                      _mdlController.text = '$v';
                      _onMdlChanged(_mdlController.text);
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // Push-ups card
        AftEventCard(
          title: 'Hand-Release Push-ups',
          icon: Icons.accessibility_new,
          leading: const AftSvgIcon(
            'assets/icons/pushup.svg',
            size: 24,
            padding: const EdgeInsets.all(2),
            colorFilter: const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
          ),
          trailing: AftScoreRing(score: computed.pushUpsScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Repetitions', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _puController,
                      focusNode: _puFocus,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_sdcFocus),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onPuChanged,
                      scrollPadding: const EdgeInsets.only(bottom: 80),
                      decoration: InputDecoration(
                        labelText: 'Push-ups',
                        hintText: 'e.g., 30',
                        errorText: _puError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AftStepper(
                    value: int.tryParse(_puController.text) ?? 0,
                    min: 0,
                    step: 1,
                    onChanged: (v) {
                      _puController.text = '$v';
                      _onPuChanged(_puController.text);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final cfg = slidercfg.getSliderConfig(profile.standard, profile, AftEvent.pushUps);
                  final curr = ((inputs.pushUps ?? int.tryParse(_puController.text) ?? cfg.min.toInt())
                      .clamp(cfg.min.toInt(), cfg.max.toInt())).toInt();
                  return AftIntSlider(
                    label: 'Repetitions',
                    value: curr,
                    config: cfg,
                    onChanged: (v) {
                      _puController.text = '$v';
                      _onPuChanged(_puController.text);
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // Sprint-Drag-Carry card
        AftEventCard(
          title: 'Sprint-Drag-Carry',
          icon: Icons.timer_outlined,
          leading: const AftSvgIcon(
            'assets/icons/dragcarry.svg',
            size: 24,
            padding: const EdgeInsets.all(2),
            colorFilter: const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
          ),
          trailing: AftScoreRing(score: computed.sdcScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time (mm:ss)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _sdcController,
                focusNode: _sdcFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_plankFocus),
                keyboardType: TextInputType.number,
                inputFormatters: [MmSsFormatter()],
                onChanged: _onSdcChanged,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: InputDecoration(
                  labelText: 'Sprint-Drag-Carry time',
                  hintText: 'e.g., 01:45',
                  errorText: _sdcError,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final cfg = slidercfg.getSliderConfig(profile.standard, profile, AftEvent.sdc);
                  final sec = inputs.sdc?.inSeconds ?? parseMmSs(_sdcController.text)?.inSeconds ?? cfg.min.toInt();
                  final curr = sec.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                  return AftTimeSlider(
                    label: 'Sprint-Drag-Carry',
                    seconds: curr,
                    config: cfg,
                    onChanged: (v) {
                      _sdcController.text = slidercfg.formatMmSs(v);
                      _onSdcChanged(_sdcController.text);
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // Plank card
        AftEventCard(
          title: 'Plank',
          icon: Icons.access_time,
          leading: const AftSvgIcon(
            'assets/icons/plank.svg',
            size: 24,
            padding: const EdgeInsets.all(2),
            colorFilter: const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
          ),
          trailing: AftScoreRing(score: computed.plankScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time (mm:ss)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              TextField(
                controller: _plankController,
                focusNode: _plankFocus,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => FocusScope.of(context).requestFocus(_runFocus),
                keyboardType: TextInputType.number,
                inputFormatters: [MmSsFormatter()],
                onChanged: _onPlankChanged,
                scrollPadding: const EdgeInsets.only(bottom: 80),
                decoration: InputDecoration(
                  labelText: 'Plank time',
                  hintText: 'e.g., 02:10',
                  errorText: _plankError,
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final cfg = slidercfg.getSliderConfig(profile.standard, profile, AftEvent.plank);
                  final sec = inputs.plank?.inSeconds ?? parseMmSs(_plankController.text)?.inSeconds ?? cfg.min.toInt();
                  final curr = sec.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                  return AftTimeSlider(
                    label: 'Plank',
                    seconds: curr,
                    config: cfg,
                    onChanged: (v) {
                      _plankController.text = slidercfg.formatMmSs(v);
                      _onPlankChanged(_plankController.text);
                    },
                  );
                },
              ),
            ],
          ),
        ),

        // 2-Mile Run card
        AftEventCard(
          title: '2-Mile Run',
          icon: Icons.directions_run,
          leading: const AftSvgIcon(
            'assets/icons/run.svg',
            size: 24,
            padding: const EdgeInsets.all(2),
            colorFilter: const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
          ),
          trailing: AftScoreRing(score: computed.run2miScore),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Time (mm:ss)', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final cfg = slidercfg.getSliderConfig(profile.standard, profile, AftEvent.run2mi);
                  final sec = inputs.run2mi?.inSeconds ?? parseMmSs(_run2miController.text)?.inSeconds ?? cfg.min.toInt();
                  final curr = sec.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _run2miController,
                          focusNode: _runFocus,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          keyboardType: TextInputType.number,
                          inputFormatters: [MmSsFormatter()],
                          onChanged: _onRunChanged,
                          scrollPadding: const EdgeInsets.only(bottom: 80),
                          decoration: InputDecoration(
                            labelText: '2-Mile Run time',
                            hintText: 'e.g., 16:45',
                            errorText: _run2miError,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AftStepper(
                        value: curr,
                        min: cfg.min.toInt(),
                        max: cfg.max.toInt(),
                        step: 1,
                        displayFormatter: (v) => slidercfg.formatMmSs(v),
                        semanticsLabel: '2-mile run time',
                        onChanged: (v) {
                          final clamped = v.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                          _run2miController.text = slidercfg.formatMmSs(clamped);
                          _onRunChanged(_run2miController.text);
                        },
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final cfg = slidercfg.getSliderConfig(profile.standard, profile, AftEvent.run2mi);
                  final sec = inputs.run2mi?.inSeconds ?? parseMmSs(_run2miController.text)?.inSeconds ?? cfg.min.toInt();
                  final curr = sec.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                  return AftTimeSlider(
                    label: '2-Mile Run',
                    seconds: curr,
                    config: cfg,
                    onChanged: (v) {
                      _run2miController.text = slidercfg.formatMmSs(v);
                      _onRunChanged(_run2miController.text);
                    },
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    ));
  }

}
