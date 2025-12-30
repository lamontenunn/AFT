import 'package:flutter_test/flutter_test.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart'
    show AftSex;
import 'package:aft_firebase_app/features/proctor/tools/height_weight.dart';

void main() {
  group('Height/Weight screening rounding', () {
    test('Height rounds half up', () {
      expect(roundHeightInches(70.49), 70);
      expect(roundHeightInches(70.5), 71);
    });

    test('Weight rounds half up', () {
      expect(roundWeightLbs(179.49), 179);
      expect(roundWeightLbs(179.5), 180);
    });
  });

  group('Height/Weight screening lookup', () {
    test('Male 25yo 70in max is 185', () {
      final res = evaluateHwScreening(
        sex: AftSex.male,
        ageYears: 25,
        heightIn: 70,
        weightLbs: 185,
      );
      expect(res, isNotNull);
      expect(res!.maxAllowedLbs, 185);
      expect(res.isPass, isTrue);
    });

    test('Female 25yo 60in max is 129', () {
      final res = evaluateHwScreening(
        sex: AftSex.female,
        ageYears: 25,
        heightIn: 60,
        weightLbs: 130,
      );
      expect(res, isNotNull);
      expect(res!.maxAllowedLbs, 129);
      expect(res.isPass, isFalse);
    });
  });
}
