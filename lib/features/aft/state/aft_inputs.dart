import 'package:flutter/foundation.dart';

/// Inputs for AFT events (only the first three used initially).
@immutable
class AftInputs {
  final int? mdlLbs; // 3RM Deadlift (lbs)
  final int? pushUps; // Hand-Release Push-ups (reps)
  final Duration? sdc; // Sprint-Drag-Carry (mm:ss)
  final Duration? plank; // Plank time (mm:ss)
  final Duration? run2mi; // 2-Mile Run time (mm:ss)

  const AftInputs({
    this.mdlLbs,
    this.pushUps,
    this.sdc,
    this.plank,
    this.run2mi,
  });

  factory AftInputs.initial() => const AftInputs();

  AftInputs copyWith({
    int? mdlLbs,
    bool clearMdlLbs = false,
    int? pushUps,
    bool clearPushUps = false,
    Duration? sdc,
    bool clearSdc = false,
    Duration? plank,
    bool clearPlank = false,
    Duration? run2mi,
    bool clearRun2mi = false,
  }) {
    return AftInputs(
      mdlLbs: clearMdlLbs ? null : (mdlLbs ?? this.mdlLbs),
      pushUps: clearPushUps ? null : (pushUps ?? this.pushUps),
      sdc: clearSdc ? null : (sdc ?? this.sdc),
      plank: clearPlank ? null : (plank ?? this.plank),
      run2mi: clearRun2mi ? null : (run2mi ?? this.run2mi),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AftInputs &&
        other.mdlLbs == mdlLbs &&
        other.pushUps == pushUps &&
        other.sdc == sdc &&
        other.plank == plank &&
        other.run2mi == run2mi;
  }

  @override
  int get hashCode =>
      (mdlLbs ?? 0).hashCode ^
      (pushUps ?? 0).hashCode ^
      (sdc?.hashCode ?? 0) ^
      (plank?.hashCode ?? 0) ^
      (run2mi?.hashCode ?? 0);
}
