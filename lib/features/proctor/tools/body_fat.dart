import 'package:flutter/foundation.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart'
    show AftSex;

@immutable
class BodyFatResult {
  final AftSex sex;
  final int age;
  final double weightLbs;
  final double abdomenIn;
  final double bodyFatPercent;
  final double maxAllowablePercent;

  const BodyFatResult({
    required this.sex,
    required this.age,
    required this.weightLbs,
    required this.abdomenIn,
    required this.bodyFatPercent,
    required this.maxAllowablePercent,
  });

  bool get isPass => bodyFatPercent <= maxAllowablePercent;
}

double maxAllowableBodyFatPercent({required AftSex sex, required int age}) {
  if (age <= 20) return sex == AftSex.male ? 20 : 30;
  if (age <= 27) return sex == AftSex.male ? 22 : 32;
  if (age <= 39) return sex == AftSex.male ? 24 : 34;
  return sex == AftSex.male ? 26 : 36;
}

/// DA Form equation-based body fat estimate.
///
/// Male: BF% = -26.97 – (0.12 × weight lbs) + (1.99 × abdomen in)
/// Female: BF% = -9.15 – (0.015 × weight lbs) + (1.27 × abdomen in)
///
/// Clamps negatives to 0.0 and rounds to the nearest whole percent.
BodyFatResult estimateBodyFat({
  required AftSex sex,
  required int age,
  required double weightLbs,
  required double abdomenIn,
}) {
  final bf = switch (sex) {
    AftSex.male => (-26.97) - (0.12 * weightLbs) + (1.99 * abdomenIn),
    AftSex.female => (-9.15) - (0.015 * weightLbs) + (1.27 * abdomenIn),
  };
  final clamped = bf < 0 ? 0.0 : bf;
  final rounded = clamped.roundToDouble();
  final max = maxAllowableBodyFatPercent(sex: sex, age: age);
  return BodyFatResult(
    sex: sex,
    age: age,
    weightLbs: weightLbs,
    abdomenIn: abdomenIn,
    bodyFatPercent: rounded,
    maxAllowablePercent: max,
  );
}
