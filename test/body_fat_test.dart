import 'package:flutter_test/flutter_test.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart'
    show AftSex;
import 'package:aft_firebase_app/features/proctor/tools/body_fat.dart';

void main() {
  group('body fat (DA equation)', () {
    test('Male equation matches expected math', () {
      // Male: BF% = -26.97 – (0.12 × weight lbs) + (1.99 × abdomen in)
      // Example: weight=200, abd=40
      // => -26.97 - 24 + 79.6 = 28.63
      final res = estimateBodyFat(
          sex: AftSex.male, age: 30, weightLbs: 200, abdomenIn: 40);
      expect(res.bodyFatPercent, closeTo(28.63, 0.0001));
    });

    test('Female equation matches expected math', () {
      // Female: BF% = -9.15 – (0.015 × weight lbs) + (1.27 × abdomen in)
      // Example: weight=150, abd=34
      // => -9.15 - 2.25 + 43.18 = 31.78
      final res = estimateBodyFat(
          sex: AftSex.female, age: 25, weightLbs: 150, abdomenIn: 34);
      expect(res.bodyFatPercent, closeTo(31.78, 0.0001));
    });

    test('Negative values are clamped to 0.0', () {
      final res = estimateBodyFat(
          sex: AftSex.male, age: 19, weightLbs: 120, abdomenIn: 20);
      expect(res.bodyFatPercent, greaterThanOrEqualTo(0.0));
    });

    test('Max allowable percent uses age brackets', () {
      expect(maxAllowableBodyFatPercent(sex: AftSex.male, age: 20), 20);
      expect(maxAllowableBodyFatPercent(sex: AftSex.male, age: 21), 22);
      expect(maxAllowableBodyFatPercent(sex: AftSex.male, age: 27), 22);
      expect(maxAllowableBodyFatPercent(sex: AftSex.male, age: 28), 24);
      expect(maxAllowableBodyFatPercent(sex: AftSex.male, age: 39), 24);
      expect(maxAllowableBodyFatPercent(sex: AftSex.male, age: 40), 26);

      expect(maxAllowableBodyFatPercent(sex: AftSex.female, age: 20), 30);
      expect(maxAllowableBodyFatPercent(sex: AftSex.female, age: 21), 32);
      expect(maxAllowableBodyFatPercent(sex: AftSex.female, age: 28), 34);
      expect(maxAllowableBodyFatPercent(sex: AftSex.female, age: 40), 36);
    });
  });
}
