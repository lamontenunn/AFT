import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/state/settings_state.dart';

class EditDefaultProfileScreen extends ConsumerStatefulWidget {
  const EditDefaultProfileScreen({super.key});

  @override
  ConsumerState<EditDefaultProfileScreen> createState() =>
      _EditDefaultProfileScreenState();
}

class _EditDefaultProfileScreenState
    extends ConsumerState<EditDefaultProfileScreen> {
  late DefaultProfileSettings _draft;

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
    int age = now.year - dob.year;
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
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
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
                          (i) => DropdownMenuItem(value: i, child: Text('$i')),
                        ),
                        onChanged: (v) => setState(() => localIn = v ?? 0),
                      ),
                    ),
                  ],
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
                      onPressed: () => Navigator.of(ctx).pop(<String, int>{
                        'ft': localFt,
                        'in': localIn,
                      }),
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
      body: ListView(
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('Service',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TextField(
            controller: _unitCtrl,
            decoration: const InputDecoration(labelText: 'Unit', isDense: true),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mosCtrl,
                  decoration:
                      const InputDecoration(labelText: 'MOS', isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _payGradeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Pay Grade', isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('On profile'),
            value: _draft.onProfile,
            onChanged: (v) => _setDraft(_draft.copyWith(onProfile: v)),
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
                TextButton(onPressed: _pickBirthdate, child: const Text('Set')),
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
            trailing:
                TextButton(onPressed: _editBodyFat, child: const Text('Edit')),
          ),
        ],
      ),
    );
  }
}
