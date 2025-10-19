import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/state/providers.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';

void main() {
  group('Profile testDate via provider', () {
    test('testDate can be set and cleared', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // ensure initial state (in case other tests touched global providers)
      container.read(aftProfileProvider.notifier).setTestDate(null);
      expect(container.read(aftProfileProvider).testDate, isNull);

      // set a date
      final d = DateTime(2024, 5, 1);
      container.read(aftProfileProvider.notifier).setTestDate(d);
      expect(container.read(aftProfileProvider).testDate, equals(d));

      // clear the date
      container.read(aftProfileProvider.notifier).setTestDate(null);
      expect(container.read(aftProfileProvider).testDate, isNull);
    });
  });

  group('ScoreSet encode/decode preserves profile.testDate', () {
    test('round-trip JSON retains test date (by Y-M-D)', () {
      final testDate = DateTime(2024, 12, 31);
      final createdAt = DateTime(2025, 1, 15, 10, 30);

      final profile = AftProfile(
        age: 25,
        sex: AftSex.male,
        standard: AftStandard.general,
        testDate: testDate,
      );
      const inputs = AftInputs();

      final original = ScoreSet(
        profile: profile,
        inputs: inputs,
        createdAt: createdAt,
        computed: null, // computed is optional
      );

      final json = encodeScoreSets([original]);
      final decoded = decodeScoreSets(json);
      expect(decoded, hasLength(1));

      final restored = decoded.first;

      // Compare testDate by components (avoids timezone-related issues)
      final td = restored.profile.testDate;
      expect(td, isNotNull);
      expect(td!.year, equals(testDate.year));
      expect(td.month, equals(testDate.month));
      expect(td.day, equals(testDate.day));

      // Sanity: other fields preserved
      expect(restored.profile.age, equals(25));
      expect(restored.profile.sex, equals(AftSex.male));
      expect(restored.profile.standard, equals(AftStandard.general));
      expect(restored.inputs.mdlLbs, isNull);
      expect(restored.computed, isNull);
    });
  });
}
