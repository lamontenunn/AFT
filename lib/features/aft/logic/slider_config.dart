import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/logic/data/mdl_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/hrp_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/sdc_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/plk_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/run2mi_table.dart';

enum SliderDomainType { integer, timeSeconds }

/// Score thresholds (values at which you reach these point levels)
class ScoreThresholds {
  final int p60;
  final int p90;
  final int p100;
  const ScoreThresholds({required this.p60, required this.p90, required this.p100});
}

int _findIntMinForPoints(int Function(AftSex,int,int) scorer, AftSex sex, int age, int target) {
  for (int v = 0; v <= 1000; v++) {
    if (scorer(sex, age, v) >= target) return v;
  }
  return 0;
}

int _findTimeMaxForPointsLowerIsBetter(int Function(AftSex,int,Duration) scorer, AftSex sex, int age, int target) {
  int lastOk = 0;
  for (int t = 0; t <= 60 * 60; t++) {
    if (scorer(sex, age, Duration(seconds: t)) >= target) {
      lastOk = t;
    } else if (lastOk > 0) {
      break;
    }
  }
  return lastOk;
}

int _findTimeMinForPointsHigherIsBetter(int Function(AftSex,int,Duration) scorer, AftSex sex, int age, int target) {
  for (int t = 0; t <= 60 * 60; t++) {
    if (scorer(sex, age, Duration(seconds: t)) >= target) return t;
  }
  return 0;
}

ScoreThresholds getScoreThresholds(AftStandard standard, AftProfile profile, AftEvent event) {
  final sex = _effectiveSex(standard, profile.sex);
  final age = profile.age;
  switch (event) {
    case AftEvent.mdl:
      return ScoreThresholds(
        p60: _findIntMinForPoints(mdlPointsForSex, sex, age, 60),
        p90: _findIntMinForPoints(mdlPointsForSex, sex, age, 90),
        p100: _findIntMinForPoints(mdlPointsForSex, sex, age, 100),
      );
    case AftEvent.pushUps:
      return ScoreThresholds(
        p60: _findIntMinForPoints(hrpPointsForSex, sex, age, 60),
        p90: _findIntMinForPoints(hrpPointsForSex, sex, age, 90),
        p100: _findIntMinForPoints(hrpPointsForSex, sex, age, 100),
      );
    case AftEvent.sdc:
      return ScoreThresholds(
        p60: _findTimeMaxForPointsLowerIsBetter(sdcPointsForSex, sex, age, 60),
        p90: _findTimeMaxForPointsLowerIsBetter(sdcPointsForSex, sex, age, 90),
        p100: _findTimeMaxForPointsLowerIsBetter(sdcPointsForSex, sex, age, 100),
      );
    case AftEvent.plank:
      return ScoreThresholds(
        p60: _findTimeMinForPointsHigherIsBetter(plkPointsForSex, sex, age, 60),
        p90: _findTimeMinForPointsHigherIsBetter(plkPointsForSex, sex, age, 90),
        p100: _findTimeMinForPointsHigherIsBetter(plkPointsForSex, sex, age, 100),
      );
    case AftEvent.run2mi:
      return ScoreThresholds(
        p60: _findTimeMaxForPointsLowerIsBetter(run2miPointsForSex, sex, age, 60),
        p90: _findTimeMaxForPointsLowerIsBetter(run2miPointsForSex, sex, age, 90),
        p100: _findTimeMaxForPointsLowerIsBetter(run2miPointsForSex, sex, age, 100),
      );
  }
}

class SliderConfig {
  final double min;
  final double max;
  final double step;
  final int? divisions;
  final SliderDomainType domain;

  const SliderConfig({
    required this.min,
    required this.max,
    required this.step,
    required this.domain,
    this.divisions,
  });
}

AftSex _effectiveSex(AftStandard standard, AftSex sex) {
  return standard == AftStandard.combat ? AftSex.male : sex;
}

// Utilities
String formatMmSs(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// Scanning helpers to derive table thresholds without exposing internals.
// We derive slider min/max from 100-point and 0-point table thresholds.

int _scanMdlReq100(AftSex sex, int age) {
  // Heuristic upper bound 500 lbs
  for (int lbs = 0; lbs <= 500; lbs++) {
    final p = mdlPointsForSex(sex, age, lbs);
    if (p == 100) return lbs;
  }
  return 300;
}

int _scanMdlReqGT0(AftSex sex, int age) {
  for (int lbs = 0; lbs <= 500; lbs++) {
    final p = mdlPointsForSex(sex, age, lbs);
    if (p >= 1) return lbs;
  }
  return 0;
}

int _scanHrpReq100(AftSex sex, int age) {
  for (int reps = 0; reps <= 200; reps++) {
    if (hrpPointsForSex(sex, age, reps) == 100) return reps;
  }
  return 70;
}

int _scanHrpReqGT0(AftSex sex, int age) {
  for (int reps = 0; reps <= 200; reps++) {
    if (hrpPointsForSex(sex, age, reps) >= 1) return reps;
  }
  return 0;
}

// Lower-is-better time events (SDC/2MR)
int _scanTimeReq100LowerIsBetter(int Function(AftSex,int,Duration) scorer, AftSex sex, int age) {
  // Find the largest time that still yields 100 by walking up until it drops.
  int last100 = 0;
  for (int t = 0; t <= 60 * 30; t++) { // cap at 30 mins
    final p = scorer(sex, age, Duration(seconds: t));
    if (p == 100) {
      last100 = t;
    } else if (p < 100 && last100 > 0) {
      break;
    }
  }
  return last100;
}

int _scanTimeReq0LowerIsBetter(int Function(AftSex,int,Duration) scorer, AftSex sex, int age, {int start=0}) {
  for (int t = start; t <= 60 * 40; t++) { // cap at 40 mins
    final p = scorer(sex, age, Duration(seconds: t));
    if (p == 0) return t;
  }
  // fallback
  return (start + 60);
}

// Higher-is-better time event (PLK)
int _scanTimeReq100HigherIsBetter(int Function(AftSex,int,Duration) scorer, AftSex sex, int age) {
  for (int t = 0; t <= 60 * 10; t++) { // cap at 10 mins plank
    final p = scorer(sex, age, Duration(seconds: t));
    if (p == 100) return t;
  }
  return 180; // 3:00 fallback
}

int _scanTimeReqGT0HigherIsBetter(int Function(AftSex,int,Duration) scorer, AftSex sex, int age) {
  for (int t = 0; t <= 60 * 10; t++) {
    final p = scorer(sex, age, Duration(seconds: t));
    if (p >= 1) return t;
  }
  return 0;
}

// Main API
SliderConfig getSliderConfig(AftStandard standard, AftProfile profile, AftEvent event) {
  final sex = _effectiveSex(standard, profile.sex);
  final age = profile.age;

  switch (event) {
    case AftEvent.mdl:
      final minVal = _scanMdlReqGT0(sex, age); // lowest non-zero threshold
      final maxVal = _scanMdlReq100(sex, age);
      final step = 5.0;
      final divisions = ((maxVal - minVal) ~/ step).clamp(1, 400);
      return SliderConfig(
        min: minVal.toDouble(),
        max: maxVal.toDouble(),
        step: step,
        divisions: divisions,
        domain: SliderDomainType.integer,
      );

    case AftEvent.pushUps:
      final minVal = _scanHrpReqGT0(sex, age);
      final maxVal = _scanHrpReq100(sex, age);
      final step = 1.0;
      final divisions = (maxVal - minVal).clamp(1, 200);
      return SliderConfig(
        min: minVal.toDouble(),
        max: maxVal.toDouble(),
        step: step,
        divisions: divisions,
        domain: SliderDomainType.integer,
      );

    case AftEvent.sdc: {
      final t100 = _scanTimeReq100LowerIsBetter(sdcPointsForSex, sex, age);
      final t0 = _scanTimeReq0LowerIsBetter(sdcPointsForSex, sex, age, start: t100);
      final range = (t0 - t100).clamp(1, 3600);
      final step = range > 300 ? 5.0 : 1.0; // 5s if >5min range
      final divisions = (range ~/ step).clamp(1, 3600);
      return SliderConfig(
        min: t100.toDouble(),
        max: t0.toDouble(),
        step: step,
        divisions: divisions,
        domain: SliderDomainType.timeSeconds,
      );
    }

    case AftEvent.plank: {
      final t100 = _scanTimeReq100HigherIsBetter(plkPointsForSex, sex, age);
      final t1 = _scanTimeReqGT0HigherIsBetter(plkPointsForSex, sex, age);
      final minT = t1; // earliest non-zero
      final maxT = t100;
      final range = (maxT - minT).clamp(1, 3600);
      final step = range > 300 ? 5.0 : 1.0;
      final divisions = (range ~/ step).clamp(1, 3600);
      return SliderConfig(
        min: minT.toDouble(),
        max: maxT.toDouble(),
        step: step,
        divisions: divisions,
        domain: SliderDomainType.timeSeconds,
      );
    }

    case AftEvent.run2mi: {
      final t100 = _scanTimeReq100LowerIsBetter(run2miPointsForSex, sex, age);
      final t0 = _scanTimeReq0LowerIsBetter(run2miPointsForSex, sex, age, start: t100);
      final range = (t0 - t100).clamp(1, 3600);
      final step = range > 300 ? 5.0 : 1.0;
      final divisions = (range ~/ step).clamp(1, 3600);
      return SliderConfig(
        min: t100.toDouble(),
        max: t0.toDouble(),
        step: step,
        divisions: divisions,
        domain: SliderDomainType.timeSeconds,
      );
    }
  }
}
