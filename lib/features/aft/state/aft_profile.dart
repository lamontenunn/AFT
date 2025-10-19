import 'package:flutter/foundation.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';

/// Sex used for profile context.
enum AftSex { male, female }

/// Sentinel for copyWith nullable fields to allow explicit null.
const Object _aftProfileUnset = Object();

/// Immutable profile context for AFT scoring.
@immutable
class AftProfile {
  final int age; // 18+
  final AftSex sex;
  final DateTime? testDate;
  final AftStandard standard;

  const AftProfile({
    required this.age,
    required this.sex,
    required this.standard,
    this.testDate,
  });

  factory AftProfile.initial() => const AftProfile(
        age: 25,
        sex: AftSex.male,
        standard: AftStandard.general,
      );

  AftProfile copyWith({
    int? age,
    AftSex? sex,
    Object? testDate = _aftProfileUnset,
    AftStandard? standard,
  }) {
    return AftProfile(
      age: age ?? this.age,
      sex: sex ?? this.sex,
      testDate: identical(testDate, _aftProfileUnset)
          ? this.testDate
          : testDate as DateTime?,
      standard: standard ?? this.standard,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AftProfile &&
        other.age == age &&
        other.sex == sex &&
        other.standard == standard &&
        other.testDate == testDate;
  }

  @override
  int get hashCode =>
      age.hashCode ^ sex.hashCode ^ standard.hashCode ^ (testDate?.hashCode ?? 0);
}
