import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/planner/lane_planner_constants.dart';
import 'package:aft_firebase_app/features/planner/lane_planner_controller.dart';
import 'package:aft_firebase_app/features/planner/lane_planner_models.dart';
import 'package:aft_firebase_app/features/planner/planner_ai_parse_service.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/widgets/aft_choice_chip.dart';

class LanePlannerScreen extends StatelessWidget {
  const LanePlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lane Planner'),
      ),
      body: const SingleChildScrollView(
        child: LanePlannerPanel(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
      ),
    );
  }
}

class LanePlannerPanel extends ConsumerStatefulWidget {
  const LanePlannerPanel({
    super.key,
    this.padding = EdgeInsets.zero,
    this.enabled = false,
  });

  final EdgeInsetsGeometry padding;
  final bool enabled;

  @override
  ConsumerState<LanePlannerPanel> createState() => _LanePlannerPanelState();
}

class _LanePlannerPanelState extends ConsumerState<LanePlannerPanel> {
  ProviderSubscription<LanePlannerState>? _lanePlannerSub;
  late final TextEditingController _soldiersCtrl;
  late final TextEditingController _lanesCtrl;
  late final TextEditingController _cycleMinutesCtrl;
  late final TextEditingController _soldiersPerLaneCtrl;
  late final TextEditingController _hexBarsPerLaneCtrl;
  late final TextEditingController _sledCtrl;
  late final TextEditingController _kettlebellPairsCtrl;
  late final TextEditingController _hexBarCtrl;
  final TextEditingController _askCtrl = TextEditingController();

  bool _askModeEnabled = false;
  bool _aiBusy = false;

  @override
  void initState() {
    super.initState();
    final input = ref.read(lanePlannerProvider).input;
    _soldiersCtrl = TextEditingController(text: '${input.soldiersCount}');
    _lanesCtrl = TextEditingController(
      text: input.lanesAvailable == null ? '' : '${input.lanesAvailable}',
    );
    _cycleMinutesCtrl = TextEditingController(
      text: input.cycleMinutes == null ? '' : '${input.cycleMinutes}',
    );
    _soldiersPerLaneCtrl = TextEditingController(
      text: input.soldiersPerLanePerCycle == null
          ? ''
          : '${input.soldiersPerLanePerCycle}',
    );
    _hexBarsPerLaneCtrl = TextEditingController(
      text: input.hexBarsPerLane == null ? '' : '${input.hexBarsPerLane}',
    );
    _sledCtrl = TextEditingController(
      text: input.inventory?.sledCount == null
          ? ''
          : '${input.inventory?.sledCount}',
    );
    _kettlebellPairsCtrl = TextEditingController(
      text: input.inventory?.kettlebellPairsCount == null
          ? ''
          : '${input.inventory?.kettlebellPairsCount}',
    );
    _hexBarCtrl = TextEditingController(
      text: input.inventory?.hexBarCount == null
          ? ''
          : '${input.inventory?.hexBarCount}',
    );

    _lanePlannerSub = ref.listenManual<LanePlannerState>(
      lanePlannerProvider,
      (prev, next) {
      final nextInput = next.input;
      _syncController(_soldiersCtrl, '${nextInput.soldiersCount}');
      _syncController(
        _lanesCtrl,
        nextInput.lanesAvailable == null ? '' : '${nextInput.lanesAvailable}',
      );
      _syncController(
        _cycleMinutesCtrl,
        nextInput.cycleMinutes == null ? '' : '${nextInput.cycleMinutes}',
      );
      _syncController(
        _soldiersPerLaneCtrl,
        nextInput.soldiersPerLanePerCycle == null
            ? ''
            : '${nextInput.soldiersPerLanePerCycle}',
      );
      _syncController(
        _hexBarsPerLaneCtrl,
        nextInput.hexBarsPerLane == null ? '' : '${nextInput.hexBarsPerLane}',
      );
      _syncController(
        _sledCtrl,
        nextInput.inventory?.sledCount == null
            ? ''
            : '${nextInput.inventory?.sledCount}',
      );
      _syncController(
        _kettlebellPairsCtrl,
        nextInput.inventory?.kettlebellPairsCount == null
            ? ''
            : '${nextInput.inventory?.kettlebellPairsCount}',
      );
      _syncController(
        _hexBarCtrl,
        nextInput.inventory?.hexBarCount == null
            ? ''
            : '${nextInput.inventory?.hexBarCount}',
      );
    },
    );
  }

  @override
  void dispose() {
    _lanePlannerSub?.close();
    _soldiersCtrl.dispose();
    _lanesCtrl.dispose();
    _cycleMinutesCtrl.dispose();
    _soldiersPerLaneCtrl.dispose();
    _hexBarsPerLaneCtrl.dispose();
    _sledCtrl.dispose();
    _kettlebellPairsCtrl.dispose();
    _hexBarCtrl.dispose();
    _askCtrl.dispose();
    super.dispose();
  }

  void _syncController(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
  }

  int? _tryParseInt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _sharePlan(
    LanePlannerPlan plan,
    LanePlannerInput input,
  ) async {
    final buffer = StringBuffer('Lane Planner\n');
    final lanesAvailable = input.lanesAvailable ?? kAftDefaultLanes;
    buffer.writeln('Soldiers: ${input.soldiersCount}');
    buffer.writeln('Lanes used: ${plan.lanesUsed} (available $lanesAvailable)');
    buffer.writeln('Cycles: ${plan.cyclesNeeded}');
    buffer.writeln(
      'Site: ${plan.siteDimensions.widthMeters}x${plan.siteDimensions.lengthMeters} m; '
      'Lane: ${plan.laneDimensions.lengthMeters}x${plan.laneDimensions.widthMeters} m',
    );
    final equipmentParts = <String>[
      '${plan.equipmentRequired.sledsRequired} sleds',
      '${plan.equipmentRequired.kettlebellPairsRequired} kettlebell pairs',
      if (plan.equipmentRequired.hexBarsRequired != null)
        '${plan.equipmentRequired.hexBarsRequired} hex bars',
    ];
    buffer.writeln('Equipment: ${equipmentParts.join(', ')}');
    if (plan.warnings.isNotEmpty) {
      buffer.writeln('Warnings: ${plan.warnings.join(' | ')}');
    }
    if (plan.equipmentDeficits.isNotEmpty) {
      buffer.writeln('Deficits:');
      for (final d in plan.equipmentDeficits) {
        buffer.writeln(
          '- ${d.item}: need ${d.required}, have ${d.available}, deficit ${d.deficit}',
        );
      }
    }
    if (plan.assumptions.isNotEmpty) {
      buffer.writeln('Assumptions:');
      for (final a in plan.assumptions) {
        buffer.writeln('- $a');
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString().trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan copied to clipboard.')),
      );
    }
  }

  Future<void> _handleAiParse() async {
    if (_aiBusy) return;
    final question = _askCtrl.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a planning question first.')),
      );
      return;
    }

    setState(() => _aiBusy = true);
    try {
      final service = ref.read(plannerAiParseServiceProvider);
      final input = await service.parseQuestion(question);
      ref.read(lanePlannerProvider.notifier).setInput(input);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inputs updated from AI.')),
        );
      }
    } catch (err) {
      if (mounted) {
        final msg = err.toString().isEmpty ? 'AI parsing failed.' : err.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _aiBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(lanePlannerProvider);
    final input = state.input;
    final plan = state.plan;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.enabled) ...[
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Coming soon — preview only.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          AbsorbPointer(
            absorbing: !widget.enabled,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inputs',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _soldiersCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Soldiers',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onTapOutside: (_) => _dismissKeyboard(),
                    onChanged: (value) {
                      final parsed = _tryParseInt(value) ?? 0;
                      ref
                          .read(lanePlannerProvider.notifier)
                          .setSoldiersCount(parsed);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _lanesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Lanes available (optional, max 16)',
                      isDense: true,
                      helperText: 'Default is 4 if left blank.',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onTapOutside: (_) => _dismissKeyboard(),
                    onChanged: (value) {
                      final parsed = _tryParseInt(value);
                      ref
                          .read(lanePlannerProvider.notifier)
                          .setLanesAvailable(parsed);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Environment',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final env in LanePlannerEnvironment.values)
                        AftChoiceChip(
                          label: env.label,
                          selected: input.environment == env,
                          onSelected: (_) => ref
                              .read(lanePlannerProvider.notifier)
                              .setEnvironment(env),
                          compact: false,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Inventory constraints (optional)'),
                    children: [
                      const SizedBox(height: 6),
                      TextField(
                        controller: _sledCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Sleds available',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onTapOutside: (_) => _dismissKeyboard(),
                        onChanged: (value) {
                          final parsed = _tryParseInt(value);
                          ref
                              .read(lanePlannerProvider.notifier)
                              .setSledCount(parsed);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _kettlebellPairsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Kettlebell pairs available',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onTapOutside: (_) => _dismissKeyboard(),
                        onChanged: (value) {
                          final parsed = _tryParseInt(value);
                          ref
                              .read(lanePlannerProvider.notifier)
                              .setKettlebellPairsCount(parsed);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _hexBarCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hex bars available',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onTapOutside: (_) => _dismissKeyboard(),
                        onChanged: (value) {
                          final parsed = _tryParseInt(value);
                          ref
                              .read(lanePlannerProvider.notifier)
                              .setHexBarCount(parsed);
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Planning assumptions (optional)'),
                    children: [
                      const SizedBox(height: 6),
                      TextField(
                        controller: _cycleMinutesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Cycle minutes',
                          isDense: true,
                          helperText: 'Default is 90 minutes.',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onTapOutside: (_) => _dismissKeyboard(),
                        onChanged: (value) {
                          final parsed = _tryParseInt(value);
                          ref
                              .read(lanePlannerProvider.notifier)
                              .setCycleMinutes(parsed);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _soldiersPerLaneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Soldiers per lane per cycle',
                          isDense: true,
                          helperText: 'Default is 4 per lane.',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onTapOutside: (_) => _dismissKeyboard(),
                        onChanged: (value) {
                          final parsed = _tryParseInt(value);
                          ref
                              .read(lanePlannerProvider.notifier)
                              .setSoldiersPerLanePerCycle(parsed);
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _hexBarsPerLaneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hex bars per lane (MDL stations)',
                          isDense: true,
                          helperText: 'Leave blank to omit MDL stations.',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onTapOutside: (_) => _dismissKeyboard(),
                        onChanged: (value) {
                          final parsed = _tryParseInt(value);
                          ref
                              .read(lanePlannerProvider.notifier)
                              .setHexBarsPerLane(parsed);
                        },
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Plan',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _MetricTile(label: 'Lanes used', value: '${plan.lanesUsed}'),
                      _MetricTile(
                        label: 'Cycles',
                        value: '${plan.cyclesNeeded}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Site: ${plan.siteDimensions.widthMeters}x${plan.siteDimensions.lengthMeters} m '
                    '(lane ${plan.laneDimensions.lengthMeters}x${plan.laneDimensions.widthMeters} m)',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Equipment required',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _ResultRow(
                    label: 'Sleds',
                    value: '${plan.equipmentRequired.sledsRequired}',
                  ),
                  _ResultRow(
                    label: 'Kettlebell pairs',
                    value: '${plan.equipmentRequired.kettlebellPairsRequired}',
                  ),
                  if (plan.equipmentRequired.hexBarsRequired != null)
                    _ResultRow(
                      label: 'Hex bars',
                      value: '${plan.equipmentRequired.hexBarsRequired}',
                    ),
                  if (plan.equipmentDeficits.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Inventory shortfalls',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _BulletList(
                      items: [
                        for (final d in plan.equipmentDeficits)
                          '${d.item}: need ${d.required}, have ${d.available} (deficit ${d.deficit})',
                      ],
                      bulletColor: theme.colorScheme.error,
                    ),
                  ],
                  if (plan.warnings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.warnings.join(' '),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Assumptions',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  _BulletList(items: plan.assumptions),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _sharePlan(plan, input),
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Share plan'),
                      ),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Export PDF (coming soon)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ask a planning question'),
                    subtitle: const Text('Coming soon'),
                    value: _askModeEnabled,
                    onChanged: null,
                  ),
                  if (_askModeEnabled) ...[
                    const SizedBox(height: 6),
                    TextField(
                      controller: _askCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ask a planning question',
                        alignLabelWithHint: true,
                      ),
                      onTapOutside: (_) => _dismissKeyboard(),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _aiBusy ? null : _handleAiParse,
                      icon: _aiBusy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_outlined),
                      label: Text(_aiBusy ? 'Parsing...' : 'Parse inputs'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Backend required: connect a Cloud Function proxy to return JSON.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
        color: cs.surfaceContainerHighest.withOpacity(0.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
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
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items, this.bulletColor});

  final List<String> items;
  final Color? bulletColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = bulletColor ?? ArmyColors.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ',
                    style:
                        theme.textTheme.bodyMedium?.copyWith(color: color)),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
