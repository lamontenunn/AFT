import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart'
    show AftSex;
import 'package:aft_firebase_app/features/planner/lane_planner_screen.dart';
import 'package:aft_firebase_app/features/proctor/tools/body_fat.dart';
import 'package:aft_firebase_app/features/proctor/tools/height_weight_chart_screen.dart';
import 'package:aft_firebase_app/features/proctor/tools/height_weight.dart';
import 'package:aft_firebase_app/features/proctor/tools/plate_math.dart';
import 'package:aft_firebase_app/features/proctor/tools/plate_math_chart_screen.dart';
import 'package:aft_firebase_app/features/proctor/state/providers.dart'
    show proctorSessionProvider, selectedProctorParticipantProvider;
import 'package:aft_firebase_app/state/settings_state.dart'
    show settingsProvider;
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/widgets/aft_svg_icon.dart';

class ProctorToolsTab extends StatefulWidget {
  const ProctorToolsTab({super.key});

  @override
  State<ProctorToolsTab> createState() => _ProctorToolsTabState();
}

class _ProctorToolsTabState extends State<ProctorToolsTab> {
  int _toolIndex = 0; // 0 plate, 1 height/weight, 2 body fat, 3 lane planner

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ToolsIconSelector(
          selectedIndex: _toolIndex,
          onSelected: (i) => setState(() => _toolIndex = i),
        ),
        const SizedBox(height: 10),
        if (_toolIndex == 0)
          const _PlateMathCard()
        else if (_toolIndex == 1)
          const _HeightWeightCard()
        else if (_toolIndex == 2)
          const _BodyFatCard()
        else
          const LanePlannerPanel(),
      ],
    );
  }
}

class _ToolsIconSelector extends StatelessWidget {
  const _ToolsIconSelector({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tileHeight = 86.0;

    Widget toolButton({
      required int index,
      required Widget icon,
      required String label,
    }) {
      final selected = index == selectedIndex;
      final bg = selected ? ArmyColors.gold : theme.colorScheme.surface;
      final fg = selected ? Colors.black : theme.colorScheme.onSurface;

      return Expanded(
        child: SizedBox(
          height: tileHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // In very tight layouts (or large text settings), keep the
              // buttons from overflowing by reducing spacing and font size.
              final isTightHeight = constraints.maxHeight.isFinite &&
                  constraints.maxHeight < tileHeight;
              final isTightWidth =
                  constraints.maxWidth.isFinite && constraints.maxWidth <= 86;
              final isCompact = isTightHeight || isTightWidth;
              final verticalPadding = isCompact ? 6.0 : 10.0;
              final horizontalPadding = isCompact ? 4.0 : 6.0;
              final iconSize = isCompact ? 20.0 : 28.0;
              final spacing = isCompact ? 4.0 : 6.0;
              final labelStyle = theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: fg,
                fontSize: isCompact ? 12.0 : 14.0,
                height: 1.1,
              );

              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(index),
                child: Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    vertical: verticalPadding,
                    horizontal: horizontalPadding,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: iconSize,
                        child: IconTheme(
                          data: IconThemeData(color: fg, size: iconSize),
                          child: FittedBox(fit: BoxFit.contain, child: icon),
                        ),
                      ),
                      SizedBox(height: spacing),
                      Flexible(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Row(
      children: [
        toolButton(
          index: 0,
          label: 'Plate Math',
          icon: AftSvgIcon(
            'assets/icons/weight-plate.svg',
            size: 28,
            padding: const EdgeInsets.all(0),
            // Render the SVG as-authored (no tint) for best visibility.
            // If you want tinting later, we can reintroduce a ColorFilter.
            colorFilter: null,
          ),
        ),
        const SizedBox(width: 8),
        toolButton(
          index: 1,
          label: 'H/W',
          icon: AftSvgIcon(
            'assets/icons/h-w.svg',
            size: 28,
            padding: const EdgeInsets.all(0),
            colorFilter: ColorFilter.mode(
              selectedIndex == 1 ? Colors.black : theme.colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),
        ),
        const SizedBox(width: 8),
        toolButton(
          index: 2,
          label: 'Body Fat',
          icon: Icon(Icons.monitor_weight_outlined,
              color: selectedIndex == 2
                  ? Colors.black
                  : theme.colorScheme.onSurface),
        ),
        const SizedBox(width: 8),
        toolButton(
          index: 3,
          label: 'Lane Planner',
          icon: const Icon(Icons.view_column_outlined),
        ),
      ],
    );
  }
}

class _HeightWeightCard extends ConsumerStatefulWidget {
  const _HeightWeightCard();

  @override
  ConsumerState<_HeightWeightCard> createState() => _HeightWeightCardState();
}

class _HeightWeightCardState extends ConsumerState<_HeightWeightCard> {
  AftSex _sex = AftSex.male;
  late final TextEditingController _ageCtrl;
  final _heightCtrl = TextEditingController(text: '70');
  final _weightCtrl = TextEditingController(text: '180');

  HwScreeningResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Default sex to selected participant if present (but allow user override).
    final selectedSex = ref.read(selectedProctorParticipantProvider)?.sex;
    if (selectedSex != null) {
      _sex = selectedSex;
    }

    // Seed age from:
    // 1) selected participant (proctor profile)
    // 2) default profile settings
    // 3) fallback 21
    final selected = ref.read(selectedProctorParticipantProvider);
    final ageFromSelected = selected?.age;
    final defaultDob = ref.read(settingsProvider).defaultProfile.birthdate;
    int? defaultAge;
    if (defaultDob != null) {
      final now = DateTime.now();
      int a = now.year - defaultDob.year;
      final hadBirthday = (now.month > defaultDob.month) ||
          (now.month == defaultDob.month && now.day >= defaultDob.day);
      if (!hadBirthday) a--;
      defaultAge = a;
    }
    final seedAge = (ageFromSelected ?? defaultAge ?? 21).clamp(17, 80);
    _ageCtrl = TextEditingController(text: '$seedAge');

    _recompute();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final age = int.tryParse(_ageCtrl.text.trim());
    final h = double.tryParse(_heightCtrl.text.trim());
    final w = double.tryParse(_weightCtrl.text.trim());
    if (age == null || h == null || w == null) {
      setState(() {
        _error = 'Enter valid age, height, and weight.';
        _result = null;
      });
      return;
    }
    if (age < 17) {
      setState(() {
        _error = 'Age must be 17+';
        _result = null;
      });
      return;
    }

    final res = evaluateHwScreening(
      sex: _sex,
      ageYears: age,
      heightIn: h,
      weightLbs: w,
    );

    if (res == null) {
      setState(() {
        _error = 'Height must be within the AR 600-9 table (58–80 in).';
        _result = null;
      });
      return;
    }

    setState(() {
      _error = null;
      _result = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;
    final selected = ref.watch(selectedProctorParticipantProvider);
    final selectedName = selected?.name?.trim();
    final selectedLabel = (selectedName != null && selectedName.isNotEmpty)
        ? selectedName
        : 'Selected participant';
    final selectedDetail = selected == null
        ? null
        : 'Age ${selected.age} • ${selected.sex == AftSex.male ? 'Male' : 'Female'}';
    void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

    // Note: Proctor always tends to have a selected participant once roster exists,
    // so we allow manual sex override rather than locking.

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
                    'Height/Weight (AR 600-9)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Hide keypad',
                  onPressed: dismissKeyboard,
                  icon: const Icon(Icons.keyboard_hide_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Rounds height/weight to nearest whole unit (≥0.5 rounds up).',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              _SelectedParticipantBanner(
                label: selectedLabel,
                detail: selectedDetail ?? '',
                onClear: () {
                  ref
                      .read(proctorSessionProvider.notifier)
                      .clearSelection();
                },
              ),
            ],
            const SizedBox(height: 10),
            _SexToggle(
              value: _sex,
              onChanged: (next) {
                setState(() => _sex = next);
                _recompute();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onTapOutside: (_) => dismissKeyboard(),
                    onChanged: (_) => _recompute(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _heightCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Height (in)',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    onTapOutside: (_) => dismissKeyboard(),
                    onChanged: (_) => _recompute(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weightCtrl,
              decoration: InputDecoration(
                labelText: 'Weight (lb)',
                isDense: true,
                errorText: _error,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onTapOutside: (_) => dismissKeyboard(),
              onChanged: (_) => _recompute(),
            ),
            const SizedBox(height: 12),
            if (res != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Min weight',
                      value: '${res.minAllowedLbs} lb',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      label: 'Max screening weight',
                      value: '${res.maxAllowedLbs} lb',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _StatusBanner(
                ok: res.isPass,
                text: res.isPass ? 'PASS' : 'FAIL',
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const HeightWeightChartScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.table_chart_outlined),
                label: const Text('Full chart'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlateMathCard extends StatefulWidget {
  const _PlateMathCard();

  @override
  State<_PlateMathCard> createState() => _PlateMathCardState();
}

class _PlateMathCardState extends State<_PlateMathCard> {
  static const int _min = 60;
  static const int _max = 350;
  static const int _step = 10;

  int _selectedTotal = 180;
  PlateMathResult? _result;
  List<List<int>> _exactCombos = const [];
  int _comboIndex = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recompute();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _recompute() {
    final tgt = _selectedTotal;
    final res = plateMath(targetTotalLbs: tgt, barLbs: 60);
    final combos = res.isExact
        ? plateMathExactCombos(targetTotalLbs: tgt, barLbs: 60, maxCombos: 8)
        : const <List<int>>[];

    // Keep combo index valid if the list changed.
    final nextIndex =
        combos.isEmpty ? 0 : _comboIndex.clamp(0, combos.length - 1);
    setState(() {
      _result = res;
      _exactCombos = combos;
      _comboIndex = nextIndex;
      _error = tgt < 60 ? 'Target must be at least 60 lb (bar weight).' : null;
    });
  }

  Future<void> _pickTargetTotal() async {
    final theme = Theme.of(context);

    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: 420,
            child: ListView.builder(
              itemCount: ((_max - _min) ~/ _step) + 1,
              itemBuilder: (ctx, i) {
                final w = _min + i * _step;
                final selected = w == _selectedTotal;
                return ListTile(
                  title: Text('$w lb'),
                  trailing: selected ? const Icon(Icons.check, size: 20) : null,
                  onTap: () => Navigator.of(ctx).pop(w),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked == null || picked == _selectedTotal) return;
    setState(() => _selectedTotal = picked);
    _recompute();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;
    final displayedPlates =
        (res != null && res.isExact && _exactCombos.isNotEmpty)
            ? _exactCombos[_comboIndex]
            : res?.platesPerSide;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plate Math',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Assumes a 60 lb bar and equal loading on both sides with 45/35/25/15/10 lb plates.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Target total weight (lb)',
                isDense: true,
                errorText: _error,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _pickTargetTotal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$_selectedTotal',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (res != null && _error == null) ...[
              _ResultRow(
                label: 'Plates per side (each side of bar)',
                value: formatPlatesPerSide(displayedPlates ?? const []),
              ),
              _ResultRow(label: 'Bar', value: '${res.barLbs} lb'),
              _ResultRow(
                label: 'Built total',
                value:
                    '${res.barLbs + 2 * (displayedPlates?.fold<int>(0, (a, b) => a + b) ?? 0)} lb',
              ),
              const SizedBox(height: 10),
              if (!res.isExact)
                _StatusPill(
                  ok: false,
                  text:
                      'Not exact (remainder ${res.remainderPerSideLbs} lb per side)',
                ),
              if (res.isExact && _exactCombos.length > 1) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.shuffle,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Multiple exact combos available. Tap shuffle to cycle.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _comboIndex = (_comboIndex + 1) % _exactCombos.length;
                      });
                    },
                    icon: const Icon(Icons.shuffle),
                    label: Text(
                        'Next combo (${_comboIndex + 1}/${_exactCombos.length})'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PlateMathChartScreen(),
                      ),
                    );
                  },
                  icon: const AftSvgIcon(
                    'assets/icons/weight-plate.svg',
                    size: 18,
                    padding: EdgeInsets.all(0),
                    colorFilter: null,
                  ),
                  label: const Text('Full chart'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BodyFatCard extends ConsumerStatefulWidget {
  const _BodyFatCard();

  @override
  ConsumerState<_BodyFatCard> createState() => _BodyFatCardState();
}

class _BodyFatCardState extends ConsumerState<_BodyFatCard> {
  AftSex _sex = AftSex.male;
  late final TextEditingController _ageCtrl;
  final _weightCtrl = TextEditingController(text: '180');
  final _abdCtrl1 = TextEditingController(text: '34');
  final _abdCtrl2 = TextEditingController(text: '34');
  final _abdCtrl3 = TextEditingController(text: '34');
  bool _abd2Dirty = false;
  bool _abd3Dirty = false;
  bool _syncingAbd = false;

  BodyFatResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Default sex/age from selected participant if available, otherwise
    // fall back to default profile (DOB) and then 21.
    final selected = ref.read(selectedProctorParticipantProvider);
    if (selected != null) {
      _sex = selected.sex;
    }

    final ageFromSelected = selected?.age;
    final defaultDob = ref.read(settingsProvider).defaultProfile.birthdate;
    int? defaultAge;
    if (defaultDob != null) {
      final now = DateTime.now();
      int a = now.year - defaultDob.year;
      final hadBirthday = (now.month > defaultDob.month) ||
          (now.month == defaultDob.month && now.day >= defaultDob.day);
      if (!hadBirthday) a--;
      defaultAge = a;
    }
    final seedAge = (ageFromSelected ?? defaultAge ?? 21).clamp(17, 80);
    _ageCtrl = TextEditingController(text: '$seedAge');

    _recompute();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _abdCtrl1.dispose();
    _abdCtrl2.dispose();
    _abdCtrl3.dispose();
    super.dispose();
  }

  void _syncAbdFromFirst(String value) {
    if (_syncingAbd) return;
    _syncingAbd = true;
    if (!_abd2Dirty) {
      _abdCtrl2.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    if (!_abd3Dirty) {
      _abdCtrl3.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
    _syncingAbd = false;
  }

  void _recompute() {
    final age = int.tryParse(_ageCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final abd1 = double.tryParse(_abdCtrl1.text.trim());
    final abd2 = double.tryParse(_abdCtrl2.text.trim());
    final abd3 = double.tryParse(_abdCtrl3.text.trim());
    if (age == null ||
        weight == null ||
        abd1 == null ||
        abd2 == null ||
        abd3 == null) {
      setState(() {
        _error = 'Enter valid age, weight, and all abdomen values.';
        _result = null;
      });
      return;
    }
    if (age < 17) {
      setState(() {
        _error = 'Age must be 17+.';
        _result = null;
      });
      return;
    }
    if (weight <= 0 || abd1 <= 0 || abd2 <= 0 || abd3 <= 0) {
      setState(() {
        _error = 'Weight and abdomen measurements must be > 0.';
        _result = null;
      });
      return;
    }

    final abdAvg = (abd1 + abd2 + abd3) / 3.0;
    final res =
        estimateBodyFat(sex: _sex, age: age, weightLbs: weight, abdomenIn: abdAvg);
    setState(() {
      _error = null;
      _result = res;
    });
  }

  void _showBodyFatInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Body fat compliance'),
        content: const Text(
          'Soldiers who score a 465 or more on the Army Fitness Test (AFT) '
          'are in compliance with the Army body fat standard IAW AD 2025-17 '
          'and AR 600-9.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;
    final selected = ref.watch(selectedProctorParticipantProvider);
    final selectedName = selected?.name?.trim();
    final selectedLabel = (selectedName != null && selectedName.isNotEmpty)
        ? selectedName
        : 'Selected participant';
    final selectedDetail = selected == null
        ? null
        : 'Age ${selected.age} • ${selected.sex == AftSex.male ? 'Male' : 'Female'}';

    void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

    final bfStr =
        res == null ? '--' : res.bodyFatPercent.toStringAsFixed(0);
    final maxStr =
        res == null ? '--' : res.maxAllowablePercent.toStringAsFixed(0);
    final bfValue = res == null ? '--' : '$bfStr%';
    final maxValue = res == null ? '--' : '$maxStr%';

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
                    'Body Fat (DA equation)',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Body fat compliance info',
                  onPressed: _showBodyFatInfo,
                  icon: const Icon(Icons.info_outline),
                ),
                IconButton(
                  tooltip: 'Hide keypad',
                  onPressed: dismissKeyboard,
                  icon: const Icon(Icons.keyboard_hide_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Uses sex + age + weight (lb) + average of 3 abdomen measurements (in).',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (selected != null) ...[
              const SizedBox(height: 10),
              _SelectedParticipantBanner(
                label: selectedLabel,
                detail: selectedDetail ?? '',
                onClear: () {
                  ref
                      .read(proctorSessionProvider.notifier)
                      .clearSelection();
                },
              ),
            ],
            const SizedBox(height: 10),
            _SexToggle(
              value: _sex,
              onChanged: (next) {
                setState(() => _sex = next);
                _recompute();
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Age',
                      isDense: true,
                    ),
                    onTapOutside: (_) => dismissKeyboard(),
                    onChanged: (_) => _recompute(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Weight (lb)',
                      isDense: true,
                    ),
                    onTapOutside: (_) => dismissKeyboard(),
                    onChanged: (_) => _recompute(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Abdomen measurements (in)',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _abdCtrl1,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Measure 1',
                      isDense: true,
                    ),
                    onTapOutside: (_) => dismissKeyboard(),
                    onChanged: (value) {
                      _syncAbdFromFirst(value);
                      _recompute();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _abdCtrl2,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: true),
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Measure 2',
                      isDense: true,
                    ),
                    onTapOutside: (_) => dismissKeyboard(),
                    onChanged: (value) {
                      if (!_syncingAbd) {
                        _abd2Dirty = value.trim().isNotEmpty;
                      }
                      _recompute();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _abdCtrl3,
                    keyboardType: const TextInputType.numberWithOptions(
                        signed: false, decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Measure 3',
                      isDense: true,
                    ),
                    onTapOutside: (_) => dismissKeyboard(),
                    onChanged: (value) {
                      if (!_syncingAbd) {
                        _abd3Dirty = value.trim().isNotEmpty;
                      }
                      _recompute();
                    },
                    onSubmitted: (_) => dismissKeyboard(),
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Body fat %',
                    value: bfValue,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricTile(
                    label: 'Max allowed %',
                    value: maxValue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (res != null && _error == null)
              _StatusBanner(
                ok: res.isPass,
                text: res.isPass ? 'PASS' : 'FAIL',
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedParticipantBanner extends StatelessWidget {
  const _SelectedParticipantBanner({
    required this.label,
    required this.detail,
    required this.onClear,
  });

  final String label;
  final String detail;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onClear,
            child: const Text('Deselect'),
          ),
        ],
      ),
    );
  }
}

class _SexToggle extends StatelessWidget {
  const _SexToggle({
    required this.value,
    required this.onChanged,
  });

  final AftSex value;
  final ValueChanged<AftSex> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle =
        theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800);

    Widget label(IconData icon, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(text),
        ],
      );
    }

    return SegmentedButton<AftSex>(
      segments: [
        ButtonSegment(
          value: AftSex.male,
          label: label(Icons.male, 'Male'),
        ),
        ButtonSegment(
          value: AftSex.female,
          label: label(Icons.female, 'Female'),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        selectedBackgroundColor: ArmyColors.gold,
        selectedForegroundColor: Colors.black,
        textStyle: textStyle,
        minimumSize: const Size(0, 44),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      onSelectionChanged: (sel) {
        if (sel.isEmpty) return;
        onChanged(sel.first);
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bg = ok ? ArmyColors.gold : Colors.red;
    final fg = ok ? Colors.black : Colors.white;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          ),
          Text(value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final bg = ok ? ArmyColors.gold : Colors.red;
    final fg = ok ? Colors.black : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.w900, color: fg),
      ),
    );
  }
}
