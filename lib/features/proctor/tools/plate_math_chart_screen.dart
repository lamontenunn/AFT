import 'package:flutter/material.dart';

import 'package:aft_firebase_app/features/proctor/tools/plate_math.dart';

/// Full Plate Math chart (exact matches only).
///
/// Lists all target totals from 350 down to 60 (step 10) that can be built
/// exactly using the assumptions in [plateMath] (60 lb bar).
class PlateMathChartScreen extends StatelessWidget {
  const PlateMathChartScreen({super.key});

  static const int min = 60;
  static const int max = 350;
  static const int step = 10;
  static const int bar = 60;

  @override
  Widget build(BuildContext context) {
    final rows = <_ChartRow>[];
    for (int w = max; w >= min; w -= step) {
      final res = plateMath(targetTotalLbs: w, barLbs: bar);
      if (!res.isExact) continue;

      final combos = plateMathExactCombos(
        targetTotalLbs: w,
        barLbs: bar,
        maxCombos: 8,
      );

      rows.add(
        _ChartRow(
          targetTotal: w,
          combos: combos.isEmpty ? <List<int>>[res.platesPerSide] : combos,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plate Math Chart'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) => _ChartRowTile(row: rows[i]),
      ),
    );
  }
}

class _ChartRow {
  final int targetTotal;
  final List<List<int>> combos;
  const _ChartRow({required this.targetTotal, required this.combos});
}

class _ChartRowTile extends StatefulWidget {
  const _ChartRowTile({required this.row});

  final _ChartRow row;

  @override
  State<_ChartRowTile> createState() => _ChartRowTileState();
}

class _ChartRowTileState extends State<_ChartRowTile> {
  int _comboIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final combos = widget.row.combos;
    final hasMultiple = combos.length > 1;
    final plates = combos.isEmpty ? const <int>[] : combos[_comboIndex];
    final platesStr = 'Per side: ${formatPlatesPerSide(plates)}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${widget.row.targetTotal} lb',
        style:
            theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        platesStr,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: hasMultiple
          ? IconButton(
              tooltip: 'Next combo',
              onPressed: () {
                setState(() => _comboIndex = (_comboIndex + 1) % combos.length);
              },
              icon: const Icon(Icons.shuffle),
            )
          : null,
    );
  }
}
