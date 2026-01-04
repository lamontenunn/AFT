import 'package:flutter/material.dart';

import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/features/aft/logic/slider_config.dart'
    as slidercfg;
import 'package:aft_firebase_app/theme/army_colors.dart';

/// Shows a clean “Saved Test” summary dialog for a [ScoreSet].
///
/// Optionally provide [onEdit] and [onDelete] callbacks to allow actions.
Future<void> showSavedTestDialog(
  BuildContext context, {
  required ScoreSet set,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  Future<void> Function()? onExportDa705,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;

  String fmtTime(Duration? d) =>
      d == null ? '—' : slidercfg.formatMmSs(d.inSeconds);

  Widget kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            v,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget kvWidget(String k, Widget v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          v,
        ],
      ),
    );
  }

  final total = set.computed?.total;
  final testDateLabel =
      set.profile.testDate == null ? '—' : formatYmd(set.profile.testDate!);
  final savedAtLabel = formatYmdHm(set.createdAt);
  final prof = set.profile;
  final inp = set.inputs;
  final comp = set.computed;

  // Fail rule: if any *known* event score is < 60.
  // (We ignore null scores so missing inputs don't immediately show as failing.)
  final bool isFail = [
    comp?.mdlScore,
    comp?.pushUpsScore,
    comp?.sdcScore,
    comp?.plankScore,
    comp?.run2miScore,
  ].any((s) => s != null && s < 60);

  final String sexLabel = prof.sex == AftSex.male ? 'M' : 'F';

  final bool isCombat = prof.standard == AftStandard.combat;
  final Widget standardValue = Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: isCombat ? ArmyColors.gold : cs.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: isCombat ? ArmyColors.gold : cs.outline,
        width: isCombat ? 1.4 : 1.0,
      ),
      boxShadow: isCombat
          ? [
              BoxShadow(
                color: ArmyColors.gold.withOpacity(0.55),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
          : const [],
    ),
    child: Text(
      isCombat ? 'Combat' : 'General',
      style: theme.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: isCombat ? Colors.black : cs.onSurface,
      ),
    ),
  );

  final ButtonStyle compactFilledStyle = FilledButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    minimumSize: const Size.fromHeight(38),
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  );

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Saved Test'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header summary
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total: ${total ?? '—'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isFail ? Colors.red : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Test date: $testDateLabel'),
                    Text('Saved: $savedAtLabel'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Text('Profile',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              kv('Age', '${prof.age}'),
              kv('Sex', sexLabel),
              kvWidget('Standard', standardValue),

              const SizedBox(height: 12),
              Text('Scores',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              kv('MDL', comp?.mdlScore?.toString() ?? '—'),
              kv('HRP', comp?.pushUpsScore?.toString() ?? '—'),
              kv('SDC', comp?.sdcScore?.toString() ?? '—'),
              kv('Plank', comp?.plankScore?.toString() ?? '—'),
              kv('2MR', comp?.run2miScore?.toString() ?? '—'),

              const SizedBox(height: 12),
              Text('Inputs',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              kv('MDL (lbs)', inp.mdlLbs?.toString() ?? '—'),
              kv('HRP (reps)', inp.pushUps?.toString() ?? '—'),
              kv('SDC (mm:ss)', fmtTime(inp.sdc)),
              kv('Plank (mm:ss)', fmtTime(inp.plank)),
              kv('2MR (mm:ss)', fmtTime(inp.run2mi)),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onExportDa705 != null) ...[
                FilledButton.tonal(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await onExportDa705();
                  },
                  style: compactFilledStyle,
                  child: const Text('Export to DA-706'),
                ),
                const SizedBox(height: 6),
              ],
              if (onEdit != null || onDelete != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Edit',
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onEdit();
                        },
                        icon: const Icon(Icons.edit),
                      ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Delete',
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onDelete();
                        },
                        color: theme.colorScheme.error,
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: compactFilledStyle,
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
