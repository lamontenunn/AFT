import 'package:flutter/foundation.dart';

/// Inputs for AFT events (only the first three used initially).
@immutable
class AftInputs {
  final int? mdlLbs; // 3RM Deadlift (lbs)
  final int? pushUps; // Hand-Release Push-ups (reps)
  final Duration? sdc; // Sprint-Drag-Carry (mm:ss)

  const AftInputs({
    this.mdlLbs,
    this.pushUps,
    this.sdc,
  });

  factory AftInputs.initial() => const AftInputs();

  AftInputs copyWith({
    int? mdlLbs,
    bool clearMdlLbs = false,
    int? pushUps,
    bool clearPushUps = false,
    Duration? sdc,
    bool clearSdc = false,
  }) {
    return AftInputs(
      mdlLbs: clearMdlLbs ? null : (mdlLbs ?? this.mdlLbs),
      pushUps: clearPushUps ? null : (pushUps ?? this.pushUps),
      sdc: clearSdc ? null : (sdc ?? this.sdc),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AftInputs &&
        other.mdlLbs == mdlLbs &&
        other.pushUps == pushUps &&
        other.sdc == sdc;
  }

  @override
  int get hashCode =>
      (mdlLbs ?? 0).hashCode ^ (pushUps ?? 0).hashCode ^ (sdc?.hashCode ?? 0);
}
