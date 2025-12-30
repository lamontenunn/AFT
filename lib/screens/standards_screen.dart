import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/standards/state/standards_selection.dart';
import 'package:aft_firebase_app/features/standards/providers.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:aft_firebase_app/features/standards/state/standards_scroll.dart';
import 'package:aft_firebase_app/features/standards/combat_info_dialog.dart';
import 'dart:ui' show FontFeature;

/// Standards screen:
/// - Top pinned controls: Gender, Combat, Age Band, ALT Event (Off)
/// - Table below: PTS | MDL | HRP | SDC | PLK | 2MR with rows 100 -> 0
class StandardsScreen extends ConsumerStatefulWidget {
  const StandardsScreen({super.key});

  @override
  ConsumerState<StandardsScreen> createState() => _StandardsScreenState();
}

class _StandardsScreenState extends ConsumerState<StandardsScreen> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    final initial = ref.read(standardsScrollOffsetProvider);
    _controller = ScrollController(initialScrollOffset: initial);
    _controller.addListener(() {
      ref.read(standardsScrollOffsetProvider.notifier).state =
          _controller.offset;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: const PageStorageKey('standards-scroll'),
      controller: _controller,
      slivers: [
        // Top pinned menu
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedControlsDelegate(
            // Fixed height (no FittedBox) so tap targets stay large.
            minExtent: 112,
            maxExtent: 112,
            builder: (ctx) => const _TopControls(),
          ),
        ),
        // Sticky header row
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedControlsDelegate(
            minExtent: 36,
            maxExtent: 36,
            builder: (ctx) => const _HeaderRow(),
          ),
        ),
        // Rows (101 from 100..0)
        const SliverToBoxAdapter(child: _StandardsRows()),
      ],
    );
  }
}

const double kCtrlHeight = 36.0;

const double _infoBtnSize = 36;

class _TopControls extends ConsumerWidget {
  const _TopControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(standardsSelectionProvider);
    final bands = ref.watch(bandsProvider);
    final ctrl = ref.read(standardsSelectionProvider.notifier);
    final theme = Theme.of(context);
    final outline = theme.colorScheme.outline;
    final onSurface = theme.colorScheme.onSurface;

    Future<void> pickAgeBand() async {
      final selected = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        backgroundColor: theme.colorScheme.surface,
        builder: (ctx) {
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                const SizedBox(height: 4),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Age Band',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                ...bands.map(
                  (b) => ListTile(
                    title: Text(b),
                    trailing: b == sel.ageBand ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.of(ctx).pop(b),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
      if (selected != null) {
        ctrl.setAgeBand(selected);
      }
    }

    Widget filterChip({
      required String label,
      required bool selected,
      required VoidCallback? onTap,
      bool emphasize = false,
    }) {
      // Match Home screen chip selection style:
      // - selected bg: gold tint
      // - selected border: gold
      // - selected text: black
      final bool enabled = onTap != null;
      final bool isGlow = emphasize;

      final Color bg = selected
          ? (isGlow ? ArmyColors.gold : ArmyColors.gold.withOpacity(0.18))
          : theme.colorScheme.surface;
      final Color borderColor =
          selected ? (isGlow ? ArmyColors.gold : ArmyColors.gold) : outline;
      final Color textColor =
          selected ? (isGlow ? Colors.black : ArmyColors.black) : onSurface;

      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.2 : 1.0,
            ),
            boxShadow: selected && emphasize
                ? [
                    BoxShadow(
                      color: ArmyColors.gold.withOpacity(0.55),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Opacity(
              opacity: enabled ? 1.0 : 0.45,
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: outline.withOpacity(0.5), width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Sex + Standard
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                filterChip(
                  label: 'M',
                  selected: sel.sex == AftSex.male,
                  onTap: () => ctrl.setSex(AftSex.male),
                ),
                const SizedBox(width: 8),
                filterChip(
                  label: 'F',
                  selected: sel.sex == AftSex.female,
                  onTap: () => ctrl.setSex(AftSex.female),
                ),
                const SizedBox(width: 12),
                filterChip(
                  label: 'General',
                  selected: !sel.combat,
                  onTap: () => ctrl.setCombat(false),
                ),
                const SizedBox(width: 8),
                filterChip(
                  label: 'Combat',
                  selected: sel.combat,
                  emphasize: true,
                  onTap: () async {
                    final next = !sel.combat;
                    ctrl.setCombat(next);
                  },
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Combat info',
                  icon: const Icon(Icons.info_outline, size: 18),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                      width: _infoBtnSize, height: _infoBtnSize),
                  onPressed: () => maybeShowCombatInfoDialog(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Row 2: Age band
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: pickAgeBand,
              child: Container(
                height: kCtrlHeight,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border.all(color: outline, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Text(
                      'Age Band',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      sel.ageBand,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const List<double> _colW = <double>[
  56,
  64,
  64,
  72,
  72,
  72
]; // PTS, MDL, HRP, SDC, PLK, 2MR

// Separator metrics (thin black bars between header columns)
const double _sepPad = 4.0; // tightened from 6 to reduce total width
const double _sepBar = 1.0;
const int _numSeps = 5;
double get _sepsTotal => (_sepPad * 2 + _sepBar) * _numSeps;

// Compute scaled widths so header/rows never overflow the available width.
// Scales down the base column widths if needed; keeps proportions.
List<double> _scaledWidths(double maxWidth, {required bool includeSeps}) {
  final double baseSum = _colW.reduce((a, b) => a + b);
  final double seps = includeSeps ? _sepsTotal : 0.0;
  final double availableForCols = maxWidth - seps;
  final double scale = availableForCols / baseSum;
  final double clamped = scale < 1.0 ? scale : 1.0;
  return _colW.map((w) => w * clamped).toList();
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: ArmyColors.gold,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.black26, width: 0.8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final widths =
                _scaledWidths(constraints.maxWidth, includeSeps: true);
            return Row(
              children: [
                _HeaderCell(
                    width: widths[0], text: 'PTS', align: TextAlign.center),
                const _Sep(),
                _HeaderCell(width: widths[1], text: 'MDL'),
                const _Sep(),
                _HeaderCell(width: widths[2], text: 'HRP'),
                const _Sep(),
                _HeaderCell(width: widths[3], text: 'SDC'),
                const _Sep(),
                _HeaderCell(width: widths[4], text: 'PLK'),
                const _Sep(),
                _HeaderCell(width: widths[5], text: '2MR'),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StandardsRows extends ConsumerWidget {
  const _StandardsRows();

  static const double _rowHeight = 28.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(standardsDisplayTableProvider);
    final theme = Theme.of(context);
    final alt = theme.colorScheme.onSurface.withOpacity(0.7);
    final timeStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
      color: alt,
    );
    final numStyle =
        Theme.of(context).textTheme.bodyMedium?.copyWith(color: alt);

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: rows.length,
      itemBuilder: (ctx, i) {
        final r = rows[i];
        final isEven = i.isEven;
        final bool isPassing = r.pts == 60;
        final Color rowColor = isPassing
            ? Color.alphaBlend(
                Colors.green.withOpacity(0.18), theme.colorScheme.surface)
            : (isEven
                ? theme.colorScheme.surface
                : Color.alphaBlend(
                    theme.colorScheme.onSurface.withOpacity(0.06),
                    theme.colorScheme.surface,
                  ));
        return Container(
          color: rowColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final widths =
                  _scaledWidths(constraints.maxWidth, includeSeps: false);
              return Row(
                children: [
                  _DataCell(
                      width: widths[0],
                      text: r.pts.toString(),
                      align: TextAlign.center,
                      bold: true,
                      height: _rowHeight),
                  _DataCell(
                      width: widths[1],
                      text: r.mdl,
                      align: TextAlign.right,
                      style: numStyle,
                      height: _rowHeight),
                  _DataCell(
                      width: widths[2],
                      text: r.hrp,
                      align: TextAlign.right,
                      style: numStyle,
                      height: _rowHeight),
                  _DataCell(
                      width: widths[3],
                      text: r.sdc,
                      align: TextAlign.right,
                      style: timeStyle,
                      height: _rowHeight),
                  _DataCell(
                      width: widths[4],
                      text: r.plk,
                      align: TextAlign.right,
                      style: timeStyle,
                      height: _rowHeight),
                  _DataCell(
                      width: widths[5],
                      text: r.run2mi,
                      align: TextAlign.right,
                      style: timeStyle,
                      height: _rowHeight),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final double width;
  final String text;
  final TextAlign align;
  const _HeaderCell({
    super.key,
    required this.width,
    required this.text,
    this.align = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: 28,
      child: Align(
        alignment: align == TextAlign.center
            ? Alignment.center
            : Alignment.centerRight,
        child: Text(
          text,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final double width;
  final String? text; // null => blank cell
  final TextAlign align;
  final TextStyle? style;
  final bool bold;
  final double height;

  const _DataCell({
    super.key,
    required this.width,
    required this.text,
    this.align = TextAlign.right,
    this.style,
    this.bold = false,
    this.height = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    if (text == null) {
      return SizedBox(width: width, height: height);
    }
    final effStyle =
        (style ?? Theme.of(context).textTheme.bodyMedium)?.copyWith(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return SizedBox(
      width: width,
      height: height,
      child: Align(
        alignment: align == TextAlign.center
            ? Alignment.center
            : Alignment.centerRight,
        child: Text(
          text!,
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: effStyle,
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        height: 20,
        width: 1,
        child: const ColoredBox(color: Colors.black),
      ),
    );
  }
}

/// Generic pinned sliver header delegate for small toolbars/headers.
class _PinnedControlsDelegate extends SliverPersistentHeaderDelegate {
  _PinnedControlsDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.builder,
  });

  @override
  final double minExtent;
  @override
  final double maxExtent;

  final WidgetBuilder builder;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Ensure the header child expands to the sliver's current size to avoid
    // "layoutExtent exceeds paintExtent" assertions in pinned headers.
    return SizedBox.expand(child: builder(context));
  }

  @override
  bool shouldRebuild(_PinnedControlsDelegate oldDelegate) {
    return minExtent != oldDelegate.minExtent ||
        maxExtent != oldDelegate.maxExtent ||
        builder != oldDelegate.builder;
  }
}
