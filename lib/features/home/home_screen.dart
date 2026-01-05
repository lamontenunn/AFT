import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/widgets/aft_pill.dart';
import 'package:aft_firebase_app/widgets/aft_choice_chip.dart';
import 'package:aft_firebase_app/widgets/aft_event_card.dart';
import 'package:aft_firebase_app/widgets/aft_score_ring.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/saves/editing.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/features/aft/logic/slider_config.dart'
    as slidercfg;
import 'package:aft_firebase_app/widgets/aft_event_slider.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:aft_firebase_app/widgets/aft_svg_icon.dart';
import 'package:aft_firebase_app/features/standards/combat_info_dialog.dart';
import 'package:aft_firebase_app/features/aft/utils/rank_assets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Home screen layout (first page) using Riverpod state.
/// - Total card with right-side pass/fail box (gold outline) + Save button (auth-gated)
/// - Context row card: Age dropdown; Sex chips; Test Date pill (no picker)
/// - Event cards: MDL, HR Push-ups, Sprint-Drag-Carry (with inputs + sliders)
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

  void _syncControllersFromProviders(AftInputs inputs) {
    bool changed = false;

    String fmtTime(Duration? d) =>
        d == null ? '' : slidercfg.formatMmSs(d.inSeconds);

    void sync(TextEditingController c, FocusNode f, String desired) {
      if (f.hasFocus) return;
      if (c.text != desired) {
        c.text = desired;
        changed = true;
      }
    }

    sync(_mdlController, _mdlFocus, inputs.mdlLbs?.toString() ?? '');
    sync(_puController, _puFocus, inputs.pushUps?.toString() ?? '');
    sync(_sdcController, _sdcFocus, fmtTime(inputs.sdc));
    sync(_plankController, _plankFocus, fmtTime(inputs.plank));
    sync(_run2miController, _runFocus, fmtTime(inputs.run2mi));

    if (changed) {
      // Clear transient validation errors when we are syncing from state (e.g., after Cancel).
      setState(() {
        _mdlError = null;
        _puError = null;
        _sdcError = null;
        _plankError = null;
        _run2miError = null;
      });
    }
  }

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

  Future<void> _pickAge(
      BuildContext context, WidgetRef ref, int currentAge) async {
    final theme = Theme.of(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) {
        const minAge = 17;
        const maxAge = 80;
        final ages = List<int>.generate(maxAge - minAge + 1, (i) => minAge + i);
        return SafeArea(
          child: ListView(
            children: [
              const SizedBox(height: 4),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Select Age',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ...ages.map(
                (a) => ListTile(
                  title: Text('$a'),
                  trailing: a == currentAge ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(ctx).pop(a),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null) {
      ref.read(aftProfileProvider.notifier).setAge(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
    // Save/Update actions moved to the top app bar.
    // (Keep reading auth so UI updates when signed-in/out.)
    // ignore: unused_local_variable
    final bool canSave = auth.isSignedIn && computed.total != null;

    // Ensure text fields stay in sync with provider state (important when editing is cancelled).
    _syncControllersFromProviders(inputs);

    // Fail rule: if any *known* event score is < 60.
    // (We ignore null scores so missing inputs don't immediately show as failing.)
    // React to Settings changes while on Calculator (apply defaults when not editing)
    ref.listen<SettingsState>(settingsProvider, (prev, next) {
      final editingNow = ref.read(editingSetProvider);
      if (editingNow != null) return;

      // Compute age from DOB and apply if changed
      final dob = next.defaultProfile.birthdate;
      if (dob != null) {
        final now = DateTime.now();
        int age = (DateTime.now().year - dob.year).toInt();
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
      final sex = next.defaultProfile.sex;
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

        // Apply defaults when not editing
        if (editing == null) {
          // Default birthdate -> compute age today
          final dob = settings.defaultProfile.birthdate;
          if (dob != null) {
            final now = DateTime.now();
            int age = (DateTime.now().year - dob.year).toInt();
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
          final defSex = settings.defaultProfile.sex;
          if (defSex != null) {
            prof.setSex(defSex);
          }
        }
      });
    }

    final dp = ref.watch(settingsProvider).defaultProfile;
    final lastName = dp.lastName?.trim();
    final explicitRankAbbrev = dp.rankAbbrev?.trim();
    final derivedRankAbbrev = dp.payGrade == null
        ? null
        : rankAbbrevByPayGrade[dp.payGrade!.trim().toUpperCase()];
    final rankAbbrev =
        (explicitRankAbbrev != null && explicitRankAbbrev.isNotEmpty)
            ? explicitRankAbbrev.toUpperCase()
            : derivedRankAbbrev;

    final canShowGreeting = (lastName != null && lastName.isNotEmpty) &&
        (rankAbbrev != null && rankAbbrev.isNotEmpty) &&
        rankAssetByAbbrev.containsKey(rankAbbrev);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Greeting row (only when we have both last name + rank abbrev).
            if (canShowGreeting)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SizedBox(
                  height: 60,
                  child: _RankGreetingRow(
                    rankAbbrev: rankAbbrev!,
                    lastName: lastName!,
                  ),
                ),
              ),

            // Context row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Age picker
                      AftPill(
                        onTap: () => _pickAge(context, ref, profile.age),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Age'),
                            const SizedBox(width: 8),
                            Text(
                              '${profile.age}',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Sex chips
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AftChoiceChip(
                              label: 'Male',
                              selected: profile.sex == AftSex.male,
                              onSelected: (val) => ref
                                  .read(aftProfileProvider.notifier)
                                  .setSex(AftSex.male),
                            ),
                            const SizedBox(width: 8),
                            AftChoiceChip(
                              label: 'Female',
                              selected: profile.sex == AftSex.female,
                              onSelected: (val) => ref
                                  .read(aftProfileProvider.notifier)
                                  .setSex(AftSex.female),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Combat toggle
                      SizedBox(
                        height: 36,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () async {
                            final isCombat =
                                profile.standard == AftStandard.combat;
                            final next = isCombat
                                ? AftStandard.general
                                : AftStandard.combat;
                            if (next == AftStandard.combat) {
                              await maybeShowCombatInfoDialog(context, ref);
                            }
                            ref
                                .read(aftProfileProvider.notifier)
                                .setStandard(next);
                            HapticFeedback.selectionClick();
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: profile.standard == AftStandard.combat
                                  ? ArmyColors.gold
                                  : theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: profile.standard == AftStandard.combat
                                    ? ArmyColors.gold
                                    : theme.colorScheme.outline,
                                width: profile.standard == AftStandard.combat
                                    ? 1.4
                                    : 1.0,
                              ),
                              boxShadow: profile.standard == AftStandard.combat
                                  ? [
                                      BoxShadow(
                                        color:
                                            ArmyColors.gold.withOpacity(0.55),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : const [],
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Center(
                                child: Text(
                                  'Combat',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color:
                                        profile.standard == AftStandard.combat
                                            ? Colors.black
                                            : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),

                      // Test date
                      AftPill(
                        onTap: () async {
                          final initial = profile.testDate ?? DateTime.now();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(2018, 1, 1),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 365 * 2)),
                            helpText: 'Select test date',
                          );
                          if (picked != null) {
                            ref
                                .read(aftProfileProvider.notifier)
                                .setTestDate(picked);
                          }
                        },
                        tooltip: 'Set test date',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.event, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              profile.testDate == null
                                  ? 'Test Date —'
                                  : 'Test Date ${formatYmd(profile.testDate!)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (profile.testDate != null) ...[
                              const SizedBox(width: 6),
                              Tooltip(
                                message: 'Clear date',
                                child: InkWell(
                                  onTap: () {
                                    ref
                                        .read(aftProfileProvider.notifier)
                                        .setTestDate(null);
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

            // MDL card
            AftEventCard(
              title: '3-Rep Max Deadlift (MDL)',
              icon: Icons.fitness_center,
              compact: true,
              leading: const AftSvgIcon(
                'assets/icons/deadlift.svg',
                size: 24,
                padding: const EdgeInsets.all(2),
                colorFilter:
                    const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
              ),
              trailing:
                  AftScoreRing(score: computed.mdlScore, size: 36, stroke: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _mdlController,
                    focusNode: _mdlFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_puFocus),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onMdlChanged,
                    scrollPadding: const EdgeInsets.only(bottom: 80),
                    decoration: InputDecoration(
                      labelText: 'MDL weight',
                      hintText: 'e.g., 185',
                      errorText: _mdlError,
                      suffixText: 'lbs',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final cfg = slidercfg.getSliderConfig(
                          profile.standard, profile, AftEvent.mdl);
                      final curr = ((inputs.mdlLbs ??
                                  int.tryParse(_mdlController.text) ??
                                  cfg.min.toInt())
                              .clamp(cfg.min.toInt(), cfg.max.toInt()))
                          .toInt();
                      return AftIntSlider(
                        label: 'Weight',
                        value: curr,
                        suffix: 'lbs',
                        config: cfg,
                        showTicks: false,
                        thresholds: slidercfg.getScoreThresholds(
                          profile.standard,
                          profile,
                          AftEvent.mdl,
                        ),
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
              compact: true,
              leading: const AftSvgIcon(
                'assets/icons/pushup.svg',
                size: 24,
                padding: const EdgeInsets.all(2),
                colorFilter:
                    const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
              ),
              trailing: AftScoreRing(
                  score: computed.pushUpsScore, size: 36, stroke: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _puController,
                    focusNode: _puFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_sdcFocus),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onPuChanged,
                    scrollPadding: const EdgeInsets.only(bottom: 80),
                    decoration: InputDecoration(
                      labelText: 'Push-ups',
                      hintText: 'e.g., 30',
                      errorText: _puError,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final cfg = slidercfg.getSliderConfig(
                          profile.standard, profile, AftEvent.pushUps);
                      final curr = ((inputs.pushUps ??
                                  int.tryParse(_puController.text) ??
                                  cfg.min.toInt())
                              .clamp(cfg.min.toInt(), cfg.max.toInt()))
                          .toInt();
                      return AftIntSlider(
                        label: 'Repetitions',
                        value: curr,
                        config: cfg,
                        showTicks: false,
                        thresholds: slidercfg.getScoreThresholds(
                          profile.standard,
                          profile,
                          AftEvent.pushUps,
                        ),
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
              compact: true,
              leading: const AftSvgIcon(
                'assets/icons/dragcarry.svg',
                size: 24,
                padding: const EdgeInsets.all(2),
                colorFilter:
                    const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
              ),
              trailing:
                  AftScoreRing(score: computed.sdcScore, size: 36, stroke: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _sdcController,
                    focusNode: _sdcFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_plankFocus),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MmSsFormatter()],
                    onChanged: _onSdcChanged,
                    scrollPadding: const EdgeInsets.only(bottom: 80),
                    decoration: InputDecoration(
                      labelText: 'Sprint-Drag-Carry time',
                      hintText: 'e.g., 1:45',
                      errorText: _sdcError,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final cfg = slidercfg.getSliderConfig(
                          profile.standard, profile, AftEvent.sdc);
                      final sec = inputs.sdc?.inSeconds ??
                          parseMmSs(_sdcController.text)?.inSeconds ??
                          cfg.max.toInt();
                      final curr =
                          sec.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                      return AftTimeSlider(
                        label: 'Sprint-Drag-Carry',
                        seconds: curr,
                        config: cfg,
                        reversed: true,
                        showTicks: false,
                        thresholds: slidercfg.getScoreThresholds(
                          profile.standard,
                          profile,
                          AftEvent.sdc,
                        ),
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
              compact: true,
              leading: const AftSvgIcon(
                'assets/icons/plank.svg',
                size: 24,
                padding: EdgeInsets.all(2),
                colorFilter: ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
              ),
              trailing:
                  AftScoreRing(score: computed.plankScore, size: 36, stroke: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _plankController,
                    focusNode: _plankFocus,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_runFocus),
                    keyboardType: TextInputType.number,
                    inputFormatters: [MmSsFormatter()],
                    onChanged: _onPlankChanged,
                    scrollPadding: const EdgeInsets.only(bottom: 80),
                    decoration: InputDecoration(
                      labelText: 'Plank time',
                      hintText: 'e.g., 2:10',
                      errorText: _plankError,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final cfg = slidercfg.getSliderConfig(
                          profile.standard, profile, AftEvent.plank);
                      final sec = inputs.plank?.inSeconds ??
                          parseMmSs(_plankController.text)?.inSeconds ??
                          cfg.min.toInt();
                      final curr =
                          sec.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                      return AftTimeSlider(
                        label: 'Plank',
                        seconds: curr,
                        config: cfg,
                        showTicks: false,
                        thresholds: slidercfg.getScoreThresholds(
                          profile.standard,
                          profile,
                          AftEvent.plank,
                        ),
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
              compact: true,
              leading: const AftSvgIcon(
                'assets/icons/run.svg',
                size: 24,
                padding: const EdgeInsets.all(2),
                colorFilter:
                    const ColorFilter.mode(ArmyColors.gold, BlendMode.srcIn),
              ),
              trailing: AftScoreRing(
                  score: computed.run2miScore, size: 36, stroke: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
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
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final cfg = slidercfg.getSliderConfig(
                          profile.standard, profile, AftEvent.run2mi);
                      final sec = inputs.run2mi?.inSeconds ??
                          parseMmSs(_run2miController.text)?.inSeconds ??
                          cfg.max.toInt();
                      final curr =
                          sec.clamp(cfg.min.toInt(), cfg.max.toInt()).toInt();
                      return AftTimeSlider(
                        label: '2-Mile Run',
                        seconds: curr,
                        config: cfg,
                        reversed: true,
                        showTicks: false,
                        thresholds: slidercfg.getScoreThresholds(
                          profile.standard,
                          profile,
                          AftEvent.run2mi,
                        ),
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
        ),
      ),
    );
  }
}

class _RankGreetingRow extends StatelessWidget {
  const _RankGreetingRow({
    required this.rankAbbrev,
    required this.lastName,
  });

  final String rankAbbrev;
  final String lastName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final assetPath = rankAssetByAbbrev[rankAbbrev];
    final rankLabel = rankDisplayLabel(rankAbbrev);

    // If insignia is missing/unavailable (PV1), show a minimal neutral glyph.
    Widget fallbackGlyph() => Icon(
          Icons.chevron_right,
          size: 28,
          color: theme.colorScheme.onSurfaceVariant,
        );

    final icon = (assetPath == null)
        ? fallbackGlyph()
        : SvgPicture.asset(
            assetPath,
            width: 56,
            height: 56,
            fit: BoxFit.contain,
            semanticsLabel: '$rankLabel rank insignia',
            // If decoding fails, render the neutral glyph instead of crashing.
            placeholderBuilder: (_) => fallbackGlyph(),
          );

    // If the SVG asset is missing, AftSvgIcon falls back to empty via
    // placeholderBuilder, and our placeholder remains visible.

    return Row(
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: Center(child: icon),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Hello, $rankLabel $lastName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
        ),
      ],
    );
  }
}
