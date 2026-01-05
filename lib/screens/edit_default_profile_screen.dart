import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/utils/rank_assets.dart';
import 'package:aft_firebase_app/features/proctor/tools/body_fat.dart';
import 'package:aft_firebase_app/state/settings_state.dart';

class EditDefaultProfileScreen extends ConsumerStatefulWidget {
  const EditDefaultProfileScreen({super.key});

  @override
  ConsumerState<EditDefaultProfileScreen> createState() =>
      _EditDefaultProfileScreenState();
}

enum _HeightInputMode { feetInches, inches }

class _EditDefaultProfileScreenState
    extends ConsumerState<EditDefaultProfileScreen> {
  late DefaultProfileSettings _draft;

  static const List<String> _armyPayGrades = <String>[
    // Enlisted
    'E-1',
    'E-2',
    'E-3',
    'E-4',
    'E-5',
    'E-6',
    'E-7',
    'E-8',
    'E-9',
    // Warrant
    'W-1',
    'W-2',
    'W-3',
    'W-4',
    'W-5',
    // Officer
    'O-1',
    'O-2',
    'O-3',
    'O-4',
    'O-5',
    'O-6',
    'O-7',
    'O-8',
    'O-9',
    // Prior-enlisted officer
    'O-1E',
    'O-2E',
    'O-3E',
  ];

  static const Map<String, List<String>> _rankOptionsByPayGrade =
      <String, List<String>>{
    'E-4': ['SPC', 'CPL'],
    'E-5': ['SGT', 'CDT'],
    'E-8': ['MSG', '1SG'],
    'E-9': ['SGM', 'CSM', 'SMA'],
  };

  late final TextEditingController _firstCtrl;
  late final TextEditingController _miCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _mosCtrl;
  late final TextEditingController _payGradeCtrl;

  @override
  void initState() {
    super.initState();
    final dp = ref.read(settingsProvider).defaultProfile;
    _draft = dp;
    _firstCtrl = TextEditingController(text: dp.firstName ?? '');
    _miCtrl = TextEditingController(text: dp.middleInitial ?? '');
    _lastCtrl = TextEditingController(text: dp.lastName ?? '');
    _unitCtrl = TextEditingController(text: dp.unit ?? '');
    _mosCtrl = TextEditingController(text: dp.mos ?? '');
    _payGradeCtrl = TextEditingController(text: dp.payGrade ?? '');
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _miCtrl.dispose();
    _lastCtrl.dispose();
    _unitCtrl.dispose();
    _mosCtrl.dispose();
    _payGradeCtrl.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = (DateTime.now().year - dob.year).toInt();
    final hasHadBirthdayThisYear = (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hasHadBirthdayThisYear) age--;
    return age.clamp(0, 150);
  }

  DefaultProfileSettings _buildDraftFromControllers() {
    String? norm(String s) {
      final v = s.trim();
      return v.isEmpty ? null : v;
    }

    final mi = norm(_miCtrl.text);
    final miNorm = mi == null ? null : mi[0].toUpperCase();

    return _draft.copyWith(
      firstName: norm(_firstCtrl.text),
      clearFirstName: norm(_firstCtrl.text) == null,
      lastName: norm(_lastCtrl.text),
      clearLastName: norm(_lastCtrl.text) == null,
      middleInitial: miNorm,
      clearMiddleInitial: miNorm == null,
      unit: norm(_unitCtrl.text),
      clearUnit: norm(_unitCtrl.text) == null,
      mos: norm(_mosCtrl.text),
      clearMos: norm(_mosCtrl.text) == null,
      payGrade: norm(_payGradeCtrl.text),
      clearPayGrade: norm(_payGradeCtrl.text) == null,
    );
  }

  Future<void> _save() async {
    final ctrl = ref.read(settingsProvider.notifier);
    final next = _buildDraftFromControllers();

    final bf = next.bodyFatPercent;
    if (bf != null && (bf < 0 || bf > 100)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Body fat % must be between 0 and 100')),
        );
      }
      return;
    }

    await ctrl.setDefaultProfile(next);
    if (mounted) Navigator.of(context).pop();
  }

  void _setDraft(DefaultProfileSettings next) {
    setState(() => _draft = next);
  }

  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  List<String> _rankOptionsForPayGrade(String payGrade) {
    final normalized = payGrade.trim().toUpperCase();
    final multi = _rankOptionsByPayGrade[normalized];
    if (multi != null) return multi;
    final single = rankAbbrevByPayGrade[normalized];
    return single == null ? const [] : <String>[single];
  }

  Future<String?> _showRankPicker({
    required String payGrade,
    required List<String> options,
    bool allowClear = true,
  }) {
    final theme = Theme.of(context);
    final current = _draft.rankAbbrev?.trim().toUpperCase();

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Select Rank ($payGrade)'),
              trailing: allowClear
                  ? TextButton(
                      onPressed: () => Navigator.of(ctx).pop(''),
                      child: const Text('Clear'),
                    )
                  : null,
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (ctx, i) {
                  final abbrev = options[i];
                  final selected = abbrev.toUpperCase() == current;
                  final display = rankDisplayLabel(abbrev);
                  return ListTile(
                    title: Text('$payGrade $display'),
                    trailing:
                        selected ? const Icon(Icons.check, size: 18) : null,
                    onTap: () => Navigator.of(ctx).pop(abbrev),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _maybeResolveRankForPayGrade(String payGrade) async {
    final options = _rankOptionsForPayGrade(payGrade);
    if (options.isEmpty) return;

    final current = _draft.rankAbbrev?.trim().toUpperCase();
    if (options.length == 1) {
      if (current != options.first) {
        _setDraft(_draft.copyWith(rankAbbrev: options.first));
      }
      return;
    }

    final picked = await _showRankPicker(
      payGrade: payGrade,
      options: options,
      allowClear: false,
    );
    if (!mounted) return;
    if (picked == null) {
      if (current != null && options.contains(current)) return;
      _setDraft(_draft.copyWith(rankAbbrev: options.first));
      return;
    }
    _setDraft(_draft.copyWith(rankAbbrev: picked));
  }

  String _rankLabel() {
    final payGrade = _payGradeCtrl.text.trim();
    if (payGrade.isEmpty) return 'Not set';
    final options = _rankOptionsForPayGrade(payGrade);
    if (options.isEmpty) return 'Not set';
    final current = _draft.rankAbbrev?.trim();
    if (current != null && current.isNotEmpty) {
      return rankDisplayLabel(current);
    }
    return options.length == 1 ? rankDisplayLabel(options.first) : 'Not set';
  }

  Future<void> _pickPayGrade() async {
    _dismissKeyboard();

    final theme = Theme.of(context);
    final current = _payGradeCtrl.text.trim();

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) {
        Widget header(String label) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              label,
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          );
        }

        List<String> section(List<String> items) => items;

        final enlisted =
            section(_armyPayGrades.where((e) => e.startsWith('E-')).toList());
        final warrant =
            section(_armyPayGrades.where((e) => e.startsWith('W-')).toList());
        final officer = section(
          _armyPayGrades
              .where((e) => e.startsWith('O-') && !e.endsWith('E'))
              .toList(),
        );
        final officerE =
            section(_armyPayGrades.where((e) => e.endsWith('E')).toList());

        final all = <({String? header, String? value})>[
          (header: 'Enlisted', value: null),
          for (final v in enlisted) (header: null, value: v),
          (header: 'Warrant Officer', value: null),
          for (final v in warrant) (header: null, value: v),
          (header: 'Officer', value: null),
          for (final v in officer) (header: null, value: v),
          (header: 'Officer (Prior Enlisted)', value: null),
          for (final v in officerE) (header: null, value: v),
        ];

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Select Pay Grade'),
                trailing: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(''),
                  child: const Text('Clear'),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: all.length,
                  itemBuilder: (ctx, i) {
                    final item = all[i];
                    final h = item.header;
                    final v = item.value;
                    if (h != null) return header(h);
                    final selected = v == current;
                    return ListTile(
                      title: Text(v!),
                      trailing:
                          selected ? const Icon(Icons.check, size: 18) : null,
                      onTap: () => Navigator.of(ctx).pop(v),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    if (selected.isEmpty) {
      setState(() {
        _payGradeCtrl.text = '';
        // Keep draft in sync so other UI that depends on _draft updates too.
        _draft = _draft.copyWith(
          clearPayGrade: true,
          clearRankAbbrev: true,
        );
      });
      return;
    }
    setState(() {
      _payGradeCtrl.text = selected;
      _draft = _draft.copyWith(payGrade: selected);
    });
    await _maybeResolveRankForPayGrade(selected);
  }

  Future<void> _pickBirthdate() async {
    final initial =
        _draft.birthdate ?? DateTime(DateTime.now().year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950, 1, 1),
      lastDate: DateTime.now(),
      helpText: 'Select birthdate',
    );
    if (picked != null) {
      _setDraft(_draft.copyWith(birthdate: picked));
    }
  }

  void _clearBirthdate() {
    _setDraft(_draft.copyWith(clearBirthdate: true));
  }

  void _toggleMeasurementSystem(MeasurementSystem next) {
    if (next == _draft.measurementSystem) return;

    double? height = _draft.height;
    double? weight = _draft.weight;

    // Convert values so users don't "lose" meaning when flipping units.
    if (height != null) {
      if (_draft.measurementSystem == MeasurementSystem.imperial &&
          next == MeasurementSystem.metric) {
        height = height * 2.54; // inches -> cm
      } else if (_draft.measurementSystem == MeasurementSystem.metric &&
          next == MeasurementSystem.imperial) {
        height = height / 2.54; // cm -> inches
      }
    }

    if (weight != null) {
      if (_draft.measurementSystem == MeasurementSystem.imperial &&
          next == MeasurementSystem.metric) {
        weight = weight * 0.45359237; // lb -> kg
      } else if (_draft.measurementSystem == MeasurementSystem.metric &&
          next == MeasurementSystem.imperial) {
        weight = weight / 0.45359237; // kg -> lb
      }
    }

    _setDraft(
      _draft.copyWith(
        measurementSystem: next,
        height: height,
        weight: weight,
      ),
    );
  }

  Future<void> _editHeight() async {
    if (_draft.measurementSystem == MeasurementSystem.metric) {
      final controller = TextEditingController(
        text: _draft.height == null ? '' : _draft.height!.toStringAsFixed(0),
      );
      final res = await showDialog<String?>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Height (cm)'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            decoration: const InputDecoration(hintText: 'e.g., 178'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (res == null) return;
      if (res.isEmpty) {
        _setDraft(_draft.copyWith(clearHeight: true));
        return;
      }
      final v = double.tryParse(res);
      _setDraft(_draft.copyWith(height: v, clearHeight: v == null));
      return;
    }

    // Imperial: feet/inches bottom sheet.
    int totalIn = (_draft.height?.round() ?? 0).clamp(0, 96);
    int ft = (totalIn ~/ 12).clamp(0, 8);
    int inch = (totalIn % 12).clamp(0, 11);

    final picked = await showModalBottomSheet<Map<String, int>>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        int localFt = ft;
        int localIn = inch;
        var mode = _HeightInputMode.feetInches;
        final inchesController =
            TextEditingController(text: totalIn.toString());
        String? inchesError;
        return StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Height',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SegmentedButton<_HeightInputMode>(
                  segments: const [
                    ButtonSegment(
                      value: _HeightInputMode.feetInches,
                      label: Text('Ft/In'),
                    ),
                    ButtonSegment(
                      value: _HeightInputMode.inches,
                      label: Text('Inches'),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (sel) {
                    if (sel.isEmpty) return;
                    final next = sel.first;
                    if (next == mode) return;
                    setState(() {
                      inchesError = null;
                      if (next == _HeightInputMode.inches) {
                        inchesController.text =
                            (localFt * 12 + localIn).toString();
                      } else {
                        final total =
                            int.tryParse(inchesController.text.trim()) ?? 0;
                        localFt = (total ~/ 12).clamp(0, 8);
                        localIn = (total % 12).clamp(0, 11);
                      }
                      mode = next;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (mode == _HeightInputMode.feetInches)
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: localFt,
                          decoration: const InputDecoration(
                            labelText: 'Feet',
                            isDense: true,
                          ),
                          items: List.generate(
                            9,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('$i'),
                            ),
                          ),
                          onChanged: (v) => setState(() => localFt = v ?? 0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: localIn,
                          decoration: const InputDecoration(
                            labelText: 'Inches',
                            isDense: true,
                          ),
                          items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                              value: i,
                              child: Text('$i'),
                            ),
                          ),
                          onChanged: (v) => setState(() => localIn = v ?? 0),
                        ),
                      ),
                    ],
                  )
                else
                  TextField(
                    controller: inchesController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Total inches',
                      hintText: 'e.g., 70',
                      isDense: true,
                      errorText: inchesError,
                    ),
                    onChanged: (_) {
                      if (inchesError != null) {
                        setState(() => inchesError = null);
                      }
                    },
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(<String, int>{}),
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(null),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        if (mode == _HeightInputMode.inches) {
                          final raw = inchesController.text.trim();
                          final inches = int.tryParse(raw);
                          if (inches == null) {
                            setState(
                                () => inchesError = 'Enter total inches');
                            return;
                          }
                          Navigator.of(ctx)
                              .pop(<String, int>{'inches': inches});
                          return;
                        }
                        Navigator.of(ctx).pop(<String, int>{
                          'ft': localFt,
                          'in': localIn,
                        });
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null) return;
    if (picked.isEmpty) {
      _setDraft(_draft.copyWith(clearHeight: true));
      return;
    }
    final inches = picked['inches'];
    if (inches != null) {
      _setDraft(_draft.copyWith(height: inches.toDouble()));
      return;
    }
    final selFt = picked['ft'] ?? 0;
    final selIn = picked['in'] ?? 0;
    _setDraft(_draft.copyWith(height: (selFt * 12 + selIn).toDouble()));
  }

  String _heightLabel() {
    if (_draft.height == null) return 'Not set';
    if (_draft.measurementSystem == MeasurementSystem.metric) {
      return '${_draft.height!.toStringAsFixed(0)} cm';
    }
    final totalIn = _draft.height!.round();
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return "$ft' $inch\"";
  }

  Future<void> _editWeight() async {
    final unit =
        _draft.measurementSystem == MeasurementSystem.metric ? 'kg' : 'lb';
    final controller = TextEditingController(
      text: _draft.weight == null ? '' : _draft.weight!.toStringAsFixed(1),
    );
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Weight ($unit)'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: 'e.g., 180.0 $unit'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(''),
              child: const Text('Clear')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (res == null) return;
    if (res.isEmpty) {
      _setDraft(_draft.copyWith(clearWeight: true));
      return;
    }
    final v = double.tryParse(res);
    _setDraft(_draft.copyWith(weight: v, clearWeight: v == null));
  }

  String _weightLabel() {
    if (_draft.weight == null) return 'Not set';
    if (_draft.measurementSystem == MeasurementSystem.metric) {
      return '${_draft.weight!.toStringAsFixed(1)} kg';
    }
    return '${_draft.weight!.toStringAsFixed(1)} lb';
  }

  Future<void> _editBodyFat() async {
    final controller = TextEditingController(
      text: _draft.bodyFatPercent == null
          ? ''
          : _draft.bodyFatPercent!.toStringAsFixed(1),
    );

    String? error;

    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Body fat %'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'e.g., 18.5',
              errorText: error,
            ),
            onChanged: (v) {
              final raw = v.trim();
              setState(() {
                if (raw.isEmpty) {
                  error = null;
                  return;
                }
                final d = double.tryParse(raw);
                if (d == null) {
                  error = 'Enter a number';
                } else if (d < 0 || d > 100) {
                  error = 'Must be between 0 and 100';
                } else {
                  error = null;
                }
              });
            },
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(null),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(''),
                child: const Text('Clear')),
            FilledButton(
              onPressed: error != null
                  ? null
                  : () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (res == null) return;
    if (res.isEmpty) {
      _setDraft(_draft.copyWith(clearBodyFatPercent: true));
      return;
    }

    final d = double.tryParse(res);
    if (d == null || d < 0 || d > 100) return;
    _setDraft(_draft.copyWith(bodyFatPercent: d));
  }

  String _bodyFatLabel() {
    if (_draft.bodyFatPercent == null) return 'Not set';
    return '${_draft.bodyFatPercent!.toStringAsFixed(1)}%';
  }

  Future<void> _openBodyFatCalculator() async {
    final theme = Theme.of(context);

    // Sex: fall back to current draft sex (or Male if unset)
    AftSex sex = _draft.sex ?? AftSex.male;

    // We don't store age directly on the DefaultProfileSettings; we can derive it
    // from DOB if present, otherwise default to 25.
    final derivedAge =
        _draft.birthdate == null ? 25 : _ageFromDob(_draft.birthdate!);
    int age = derivedAge.clamp(17, 80);

    // Weight: draft weight is stored in either lb or kg depending on measurementSystem.
    double? weightLbs;
    if (_draft.weight != null) {
      weightLbs = _draft.measurementSystem == MeasurementSystem.metric
          ? _draft.weight! / 0.45359237
          : _draft.weight!;
    }

    final ageCtrl = TextEditingController(text: '$age');
    final weightCtrl = TextEditingController(
      text: weightLbs == null ? '' : weightLbs.toStringAsFixed(1),
    );
    final abdomenCtrl = TextEditingController();

    BodyFatResult? result;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          void recompute() {
            final w = double.tryParse(weightCtrl.text.trim());
            final a = double.tryParse(abdomenCtrl.text.trim());
            if (w == null || a == null || w <= 0 || a <= 0) {
              setState(() => result = null);
              return;
            }
            setState(() {
              result = estimateBodyFat(
                sex: sex,
                age: age,
                weightLbs: w,
                abdomenIn: a,
              );
            });
          }

          final pass = result?.isPass;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(ctx).unfocus(),
            child: AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        Text(
                          'Body Fat Calculator',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Done',
                          onPressed: () => FocusScope.of(ctx).unfocus(),
                          icon: const Icon(Icons.keyboard_hide_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<AftSex>(
                      segments: const [
                        ButtonSegment(value: AftSex.male, label: Text('Male')),
                        ButtonSegment(
                            value: AftSex.female, label: Text('Female')),
                      ],
                      selected: {sex},
                      onSelectionChanged: (sel) {
                        if (sel.isEmpty) return;
                        setState(() => sex = sel.first);
                        recompute();
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ageCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final parsed = int.tryParse(v.trim());
                              if (parsed == null) return;
                              setState(() => age = parsed.clamp(17, 80));
                              recompute();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: weightCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Weight (lb)',
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (_) => recompute(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: abdomenCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Abdomen (in)',
                        isDense: true,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => recompute(),
                    ),
                    const SizedBox(height: 14),
                    if (result != null)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated BF%: ${result!.bodyFatPercent.toStringAsFixed(1)}%',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Max allowable: ${result!.maxAllowablePercent.toStringAsFixed(0)}%',
                              ),
                              const SizedBox(height: 6),
                              Text(
                                pass == true ? 'PASS' : 'FAIL',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color:
                                      pass == true ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        'Enter age, weight, and abdomen to calculate.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Close'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: result == null
                              ? null
                              : () {
                                  _setDraft(_draft.copyWith(
                                    bodyFatPercent: result!.bodyFatPercent,
                                  ));
                                  Navigator.of(ctx).pop();
                                },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    // NOTE: Don't manually dispose these controllers here.
    // The bottom-sheet uses them during its closing animation; disposing here
    // can trigger "TextEditingController used after being disposed".
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissKeyboard,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text('Name',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _firstCtrl,
                    decoration: const InputDecoration(
                      labelText: 'First',
                      isDense: true,
                    ),
                    onTapOutside: (_) => _dismissKeyboard(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _miCtrl,
                    maxLength: 1,
                    decoration: const InputDecoration(
                      labelText: 'MI',
                      counterText: '',
                      isDense: true,
                    ),
                    onTapOutside: (_) => _dismissKeyboard(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _lastCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Last',
                      isDense: true,
                    ),
                    onTapOutside: (_) => _dismissKeyboard(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Text(
                    'Rank',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _rankLabel(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Service',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _unitCtrl,
              decoration:
                  const InputDecoration(labelText: 'Unit', isDense: true),
              onTapOutside: (_) => _dismissKeyboard(),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mosCtrl,
                    decoration:
                        const InputDecoration(labelText: 'MOS', isDense: true),
                    onTapOutside: (_) => _dismissKeyboard(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Pay Grade',
                      isDense: true,
                    ),
                    child: InkWell(
                      onTap: _pickPayGrade,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _payGradeCtrl.text.trim().isEmpty
                                    ? 'Select'
                                    : _payGradeCtrl.text.trim(),
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Demographics',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Birthdate'),
              subtitle: Text(
                _draft.birthdate == null
                    ? 'Not set'
                    : '${_ymd(_draft.birthdate!)} (Age today: ${_ageFromDob(_draft.birthdate!)})',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton(
                      onPressed: _pickBirthdate, child: const Text('Set')),
                  if (_draft.birthdate != null)
                    TextButton(
                        onPressed: _clearBirthdate, child: const Text('Clear')),
                ],
              ),
            ),
            SegmentedButton<AftSex>(
              segments: const [
                ButtonSegment(value: AftSex.male, label: Text('Male')),
                ButtonSegment(value: AftSex.female, label: Text('Female')),
              ],
              selected: {_draft.sex ?? AftSex.male},
              onSelectionChanged: (sel) {
                if (sel.isEmpty) return;
                _setDraft(_draft.copyWith(sex: sel.first));
              },
            ),
            const SizedBox(height: 18),
            Text('Body composition',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            SegmentedButton<MeasurementSystem>(
              segments: const [
                ButtonSegment(
                    value: MeasurementSystem.imperial, label: Text('Imperial')),
                ButtonSegment(
                    value: MeasurementSystem.metric, label: Text('Metric')),
              ],
              selected: {_draft.measurementSystem},
              onSelectionChanged: (sel) {
                if (sel.isEmpty) return;
                _toggleMeasurementSystem(sel.first);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.height),
              title: const Text('Height'),
              subtitle: Text(_heightLabel()),
              trailing:
                  TextButton(onPressed: _editHeight, child: const Text('Edit')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.monitor_weight_outlined),
              title: const Text('Weight'),
              subtitle: Text(_weightLabel()),
              trailing:
                  TextButton(onPressed: _editWeight, child: const Text('Edit')),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.percent),
              title: const Text('Body fat %'),
              subtitle: Text(_bodyFatLabel()),
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Calculate',
                    icon: const Icon(Icons.calculate_outlined),
                    onPressed: _openBodyFatCalculator,
                  ),
                  TextButton(
                      onPressed: _editBodyFat, child: const Text('Edit')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
