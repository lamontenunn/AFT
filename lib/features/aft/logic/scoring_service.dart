import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/logic/data/mdl_table.dart';

/// AFT events supported in scoring.
enum AftEvent { mdl, pushUps, sdc, plank, run2mi }

/// Seam for real AFT scoring tables (placeholder logic for now).
class ScoringService {
  /// Returns an event score (0-100) or null when input is not valid/absent.
  /// Placeholder deterministic outputs to keep UI live:
  /// - MDL: 82
  /// - Push-ups: 74
  /// - SDC: 68
  int? scoreEvent(
    AftStandard standard,
    AftProfile profile,
    AftEvent event,
    Object? input,
  ) {
    // Validate inputs by type and basic domain rules; return null if invalid.
    switch (event) {
      case AftEvent.mdl:
        if (input is! int) return null;
        if (input < 0) return null;
        // Combat uses male standards regardless of selected sex.
        final effectiveSex =
            standard == AftStandard.combat ? AftSex.male : profile.sex;
        final pts = mdlPointsForSex(effectiveSex, profile.age, input);
        return pts;
      case AftEvent.pushUps:
        if (input is! int) return null;
        if (input < 0) return null;
        return 74;
      case AftEvent.sdc:
        if (input is! Duration) return null;
        if (input.inMilliseconds < 0) return null;
        return 68;
      case AftEvent.plank:
        if (input is! Duration) return null;
        if (input.inMilliseconds < 0) return null;
        // Placeholder deterministic score for Plank
        return 76;
      case AftEvent.run2mi:
        if (input is! Duration) return null;
        if (input.inMilliseconds < 0) return null;
        // Placeholder deterministic score for 2-Mile Run
        return 62;
    }
  }

  /// Sums event scores when all required events are present; otherwise null.
  int? totalScore(
    AftStandard standard,
    AftProfile profile,
    int? mdl,
    int? pushUps,
    int? sdc,
  ) {
    if (mdl == null || pushUps == null || sdc == null) return null;
    final total = mdl + pushUps + sdc;
    return total;
  }
}
