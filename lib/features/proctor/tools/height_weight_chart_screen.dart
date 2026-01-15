import 'package:flutter/material.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart' show AftSex;
import 'package:aft_firebase_app/features/proctor/tools/height_weight.dart';

class HeightWeightChartScreen extends StatefulWidget {
  const HeightWeightChartScreen({super.key});

  @override
  State<HeightWeightChartScreen> createState() =>
      _HeightWeightChartScreenState();
}

class _HeightWeightChartScreenState extends State<HeightWeightChartScreen> {
  AftSex _sex = AftSex.male;

  @override
  Widget build(BuildContext context) {
    final rows = _rowsFor(_sex);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Height/Weight Chart'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SexToggle(
                value: _sex,
                onChanged: (next) => setState(() => _sex = next),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Maximum screening weight (lbs)',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap a row to view details.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    headingRowColor: MaterialStateProperty.all(
                      theme.colorScheme.surfaceVariant.withOpacity(0.6),
                    ),
                    dataRowMinHeight: 34,
                    dataRowMaxHeight: 42,
                    columns: const [
                      DataColumn(label: Text('Height (in)')),
                      DataColumn(label: Text('Min wt')),
                      DataColumn(label: Text('17-20')),
                      DataColumn(label: Text('21-27')),
                      DataColumn(label: Text('28-39')),
                      DataColumn(label: Text('40+')),
                    ],
                    rows: [
                      for (final entry in rows.asMap().entries)
                        DataRow(
                          color: MaterialStateProperty.resolveWith((states) {
                            if (states.contains(MaterialState.selected)) {
                              return theme.colorScheme.primary.withOpacity(0.12);
                            }
                            return entry.key.isEven
                                ? theme.colorScheme.surface
                                : theme.colorScheme.surfaceVariant
                                    .withOpacity(0.35);
                          }),
                          onSelectChanged: (_) =>
                              _showRowDetails(context, entry.value),
                          cells: [
                            DataCell(Text('${entry.value.heightIn}')),
                            DataCell(
                              Text(
                                _fmt(entry.value.minWeightLbs),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            DataCell(Text(_fmt(entry.value.max17_20))),
                            DataCell(Text(_fmt(entry.value.max21_27))),
                            DataCell(Text(_fmt(entry.value.max28_39))),
                            DataCell(Text(_fmt(entry.value.max40Plus))),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRowDetails(BuildContext context, _HwChartRow row) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Height ${row.heightIn} in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailLine('Min weight', _fmt(row.minWeightLbs)),
            _detailLine('17-20', _fmt(row.max17_20)),
            _detailLine('21-27', _fmt(row.max21_27)),
            _detailLine('28-39', _fmt(row.max28_39)),
            _detailLine('40+', _fmt(row.max40Plus)),
          ],
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

  Widget _detailLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  List<_HwChartRow> _rowsFor(AftSex sex) {
    final rows = <_HwChartRow>[];
    if (sex == AftSex.male) {
      rows.addAll([
        const _HwChartRow(
          heightIn: 58,
          minWeightLbs: 91,
        ),
        const _HwChartRow(
          heightIn: 59,
          minWeightLbs: 94,
        ),
      ]);
      final heights = hwTable.male.keys.toList()..sort();
      for (final h in heights) {
        final row = hwTable.male[h]!;
        rows.add(_HwChartRow.fromRow(row));
      }
    } else {
      final heights = hwTable.female.keys.toList()..sort();
      for (final h in heights) {
        final row = hwTable.female[h]!;
        rows.add(_HwChartRow.fromRow(row));
      }
    }
    return rows;
  }

  String _fmt(int? value) => value == null ? '--' : '$value';
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
        selectedBackgroundColor: theme.colorScheme.primaryContainer,
        selectedForegroundColor: theme.colorScheme.onPrimaryContainer,
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

class _HwChartRow {
  const _HwChartRow({
    required this.heightIn,
    required this.minWeightLbs,
    this.max17_20,
    this.max21_27,
    this.max28_39,
    this.max40Plus,
  });

  final int heightIn;
  final int? minWeightLbs;
  final int? max17_20;
  final int? max21_27;
  final int? max28_39;
  final int? max40Plus;

  factory _HwChartRow.fromRow(HwScreeningRow row) {
    return _HwChartRow(
      heightIn: row.heightIn,
      minWeightLbs: row.minWeightLbs,
      max17_20: row.max17_20,
      max21_27: row.max21_27,
      max28_39: row.max28_39,
      max40Plus: row.max40Plus,
    );
  }
}
