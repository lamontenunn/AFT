import 'package:flutter/material.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';
import 'package:aft_firebase_app/features/proctor/timing/thresholds.dart';

const List<String> kSdcSegments = <String>[
  'Sprint',
  'Drag',
  'Lateral',
  'Carry',
  'Final Sprint',
];

// Relative time weights per segment (order matches kSdcSegments).
const List<int> kSdcSegmentWeights = <int>[
  12,
  36,
  21,
  19,
  12,
];

String formatSdcSegmentWeights() => kSdcSegmentWeights.join('/');

Duration sdcCumulativeTarget(Duration total, int segmentIndex) {
  final clamped = segmentIndex.clamp(0, kSdcSegmentWeights.length - 1).toInt();
  final weightTotal =
      kSdcSegmentWeights.fold<double>(0, (sum, w) => sum + w);
  if (weightTotal <= 0) return total;
  double cumulative = 0;
  for (var i = 0; i <= clamped; i++) {
    cumulative += kSdcSegmentWeights[i];
  }
  final fraction = cumulative / weightTotal;
  return Duration(
    milliseconds: (total.inMilliseconds * fraction).round(),
  );
}

List<Duration> sdcSegmentTargets(Duration total) {
  final out = <Duration>[];
  Duration prev = Duration.zero;
  for (var i = 0; i < kSdcSegments.length; i++) {
    final cum = sdcCumulativeTarget(total, i);
    out.add(cum - prev);
    prev = cum;
  }
  return out;
}

String _sexLabel(AftSex sex) => sex == AftSex.male ? 'Male' : 'Female';

String _standardLabel(AftStandard standard) =>
    standard == AftStandard.combat ? 'Combat' : 'General';

Duration? _parseDurationThreshold(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return parseMmSs(trimmed);
}

void showSdcSegmentInfoSheet(BuildContext context, AftProfile profile) {
  final th = thresholdsFor(
    event: AftEvent.sdc,
    profile: profile,
    standard: profile.standard,
  );
  final target100 = _parseDurationThreshold(th.pts100);
  final target60 = _parseDurationThreshold(th.pts60);

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final headerStyle =
          theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800);
      final cellStyle =
          theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700);
      final noteStyle = theme.textTheme.bodySmall
          ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

      Widget body;
      if (target100 == null || target60 == null) {
        body = Text(
          'Segment targets unavailable (missing standards thresholds).',
          style: noteStyle,
        );
      } else {
        final seg100 = sdcSegmentTargets(target100);
        final seg60 = sdcSegmentTargets(target60);
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.7),
                1: FlexColumnWidth(1),
                2: FlexColumnWidth(1),
              },
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('Segment', style: headerStyle),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '100',
                        style: headerStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '60',
                        style: headerStyle,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                for (var i = 0; i < kSdcSegments.length; i++)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(kSdcSegments[i], style: cellStyle),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          formatMmSsMillis(seg100[i]),
                          style: cellStyle,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          formatMmSsMillis(seg60[i]),
                          style: cellStyle,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Totals: 100 = ${th.pts100}, 60 = ${th.pts60}',
              style: noteStyle,
            ),
            const SizedBox(height: 4),
            Text(
              'Targets are per segment (not cumulative) using the app split '
              'weights ${formatSdcSegmentWeights()}.',
              style: noteStyle,
            ),
          ],
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SDC segment targets',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Profile: age ${profile.age} • ${_sexLabel(profile.sex)} '
                '• ${_standardLabel(profile.standard)}',
                style: noteStyle,
              ),
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      );
    },
  );
}
