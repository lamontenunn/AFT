import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/features/standards/standards_loader.dart';
import 'package:aft_firebase_app/features/standards/state/standards_selection.dart'
    show bandIndexForAge, kAftAgeBands;

class ProctorEventThresholds {
  final String pts100;
  final String pts60;

  const ProctorEventThresholds({required this.pts100, required this.pts60});
}

int? _tryParseIntThreshold(String v) {
  final trimmed = v.trim();
  if (trimmed.isEmpty || trimmed == '---' || trimmed == '—') return null;
  return int.tryParse(trimmed);
}

/// HRP-specific thresholds (reps).
///
/// Returns null when unavailable.
({int? reps100, int? reps60}) hrpRepThresholdsFor({
  required AftProfile profile,
  required AftStandard standard,
}) {
  final th = thresholdsFor(
    event: AftEvent.pushUps,
    profile: profile,
    standard: standard,
  );
  return (
    reps100: _tryParseIntThreshold(th.pts100),
    reps60: _tryParseIntThreshold(th.pts60),
  );
}

/// Pulls thresholds from the same standards tables used on the Standards screen.
/// Returns formatted strings (e.g. "02:10" or "---").
ProctorEventThresholds thresholdsFor({
  required AftEvent event,
  required AftProfile profile,
  required AftStandard standard,
}) {
  final idx = bandIndexForAge(profile.age);
  final band = kAftAgeBands[idx];

  final effectiveSex =
      standard == AftStandard.combat ? AftSex.male : profile.sex;
  final col =
      loadEventColumn(event: event, effectiveSex: effectiveSex, ageBand: band);
  // col[0] = pts 100 ... col[40] = pts 60
  final pts100 = (col.isNotEmpty) ? col[0] : '---';
  final pts60 = (col.length > 40) ? col[40] : '---';
  return ProctorEventThresholds(pts100: pts100, pts60: pts60);
}
