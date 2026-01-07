import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart'
    show AftSex;
import 'package:aft_firebase_app/features/proctor/tools/body_fat.dart';
import 'package:aft_firebase_app/features/proctor/tools/height_weight.dart';
import 'package:aft_firebase_app/features/proctor/tools/plate_math.dart';
import 'package:aft_firebase_app/features/proctor/tools/plate_math_chart_screen.dart';
import 'package:aft_firebase_app/features/proctor/state/providers.dart'
    show selectedProctorParticipantProvider;
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
  int _toolIndex = 0; // 0 plate, 1 body fat, 2 height/weight

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
          const _BodyFatCard()
        else
          const _HeightWeightCard(),
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

    Widget toolButton({
      required int index,
      required Widget icon,
      required String label,
    }) {
      final selected = index == selectedIndex;
      final bg = selected ? ArmyColors.gold : theme.colorScheme.surface;
      final fg = selected ? Colors.black : theme.colorScheme.onSurface;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onSelected(index),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(color: fg, size: 22),
                  child: icon,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: fg),
                ),
              ],
            ),
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
        const SizedBox(width: 10),
        toolButton(
          index: 1,
          label: 'Body Fat',
          icon: Icon(Icons.monitor_weight_outlined,
              color: selectedIndex == 1
                  ? Colors.black
                  : theme.colorScheme.onSurface),
        ),
        const SizedBox(width: 10),
        toolButton(
          index: 2,
          label: 'H/W',
          icon: AftSvgIcon(
            'assets/icons/h-w.svg',
            size: 28,
            padding: const EdgeInsets.all(0),
            colorFilter: null,
          ),
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
            const SizedBox(height: 10),
            SegmentedButton<AftSex>(
              segments: const [
                ButtonSegment(value: AftSex.male, label: Text('Male')),
                ButtonSegment(value: AftSex.female, label: Text('Female')),
              ],
              selected: {_sex},
              onSelectionChanged: (sel) {
                if (sel.isEmpty) return;
                setState(() => _sex = sel.first);
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
              _ResultRow(
                label: 'Min weight',
                value: '${res.minAllowedLbs} lb',
              ),
              _ResultRow(
                label: 'Max screening weight',
                value: '${res.maxAllowedLbs} lb',
              ),
              const SizedBox(height: 10),
              _StatusPill(
                ok: res.isPass,
                text: res.isPass ? 'PASS' : 'FAIL',
              ),
            ],
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
  final _abdCtrl = TextEditingController(text: '34');

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
    _abdCtrl.dispose();
    super.dispose();
  }

  void _recompute() {
    final age = int.tryParse(_ageCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final abd = double.tryParse(_abdCtrl.text.trim());
    if (age == null || weight == null || abd == null) {
      setState(() {
        _error = 'Enter valid age, weight, and abdomen values.';
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
    if (weight <= 0 || abd <= 0) {
      setState(() {
        _error = 'Weight and abdomen must be > 0.';
        _result = null;
      });
      return;
    }

    final res =
        estimateBodyFat(sex: _sex, age: age, weightLbs: weight, abdomenIn: abd);
    setState(() {
      _error = null;
      _result = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final res = _result;

    void dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

    final bfStr = res == null
        ? '--'
        : res.bodyFatPercent
            .toStringAsFixed(1)
            .replaceAll(RegExp(r'\.0$'), '.0'); // keep one decimal
    final maxStr =
        res == null ? '--' : res.maxAllowablePercent.toStringAsFixed(0);

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
                  tooltip: 'Hide keypad',
                  onPressed: dismissKeyboard,
                  icon: const Icon(Icons.keyboard_hide_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Uses sex + age + weight (lb) + abdominal circumference (in).',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            SegmentedButton<AftSex>(
              segments: const [
                ButtonSegment(value: AftSex.male, label: Text('Male')),
                ButtonSegment(value: AftSex.female, label: Text('Female')),
              ],
              selected: {_sex},
              onSelectionChanged: (sel) {
                if (sel.isEmpty) return;
                setState(() {
                  _sex = sel.first;
                });
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
            TextField(
              controller: _abdCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                  signed: false, decimal: true),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Abdomen circumference (in)',
                isDense: true,
                errorText: _error,
              ),
              onTapOutside: (_) => dismissKeyboard(),
              onChanged: (_) => _recompute(),
              onSubmitted: (_) => dismissKeyboard(),
            ),
            const SizedBox(height: 12),
            _ResultRow(label: 'Body fat %', value: bfStr),
            _ResultRow(label: 'Max allowed %', value: maxStr),
            const SizedBox(height: 10),
            if (res != null && _error == null)
              _StatusPill(
                ok: res.isPass,
                text: res.isPass ? 'PASS' : 'FAIL',
              ),
          ],
        ),
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
