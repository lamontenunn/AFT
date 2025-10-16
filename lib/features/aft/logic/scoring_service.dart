import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';

/// AFT events supported in scoring.
enum AftEvent { mdl, pushUps, sdc }

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
        return 82;
      case AftEvent.pushUps:
        if (input is! int) return null;
        if (input < 0) return null;
        return 74;
      case AftEvent.sdc:
        if (input is! Duration) return null;
        if (input.inMilliseconds < 0) return null;
        return 68;
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
