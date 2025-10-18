import 'package:flutter_test/flutter_test.dart';
import 'package:aft_firebase_app/features/aft/logic/data/mdl_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/mdl_csv.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';

void main() {
  // Load the provided 20-column (M/F) CSV once for all tests.
  setUpAll(() {
    preloadMdlCsvOnce(mdlCsv);
  });

  group('MDL points with age + sex (fill-down per column)', () {
    group('Male anchors', () {
      test('Age 17–21 (M17-21)', () {
        expect(mdlPointsForSex(AftSex.male, 20, 340), 100);
        expect(mdlPointsForSex(AftSex.male, 20, 330), 99);
        expect(mdlPointsForSex(AftSex.male, 20, 300), 93);
        expect(mdlPointsForSex(AftSex.male, 20, 150), 62);
        expect(mdlPointsForSex(AftSex.male, 20, 80), 9);
        expect(mdlPointsForSex(AftSex.male, 20, 79), 0);
      });

      test('Age 22–26 (M22-26)', () {
        expect(mdlPointsForSex(AftSex.male, 24, 350), 100);
        expect(mdlPointsForSex(AftSex.male, 24, 340), 99);
        expect(mdlPointsForSex(AftSex.male, 24, 330), 98);
        expect(mdlPointsForSex(AftSex.male, 24, 150), 62);
      });

      test('Age 62+ (M62+)', () {
        expect(mdlPointsForSex(AftSex.male, 65, 170), 92);
        expect(mdlPointsForSex(AftSex.male, 65, 140), 71);
        expect(mdlPointsForSex(AftSex.male, 65, 120), 49);
      });
    });

    group('Female anchors (different from male)', () {
      test('Age 17–21 (F17-21)', () {
        expect(mdlPointsForSex(AftSex.female, 20, 220), 100);
        expect(mdlPointsForSex(AftSex.female, 20, 210), 99);
        expect(mdlPointsForSex(AftSex.female, 20, 120), 67);
        expect(mdlPointsForSex(AftSex.female, 20, 60), 9);
      });

      test('Age 62+ (F62+)', () {
        expect(mdlPointsForSex(AftSex.female, 65, 170), 100);
        expect(mdlPointsForSex(AftSex.female, 65, 140), 89);
        expect(mdlPointsForSex(AftSex.female, 65, 120), 71);
      });
    });
  });

  group('Combat standard forces male MDL thresholds', () {
    test('Combat uses male table even if profile.sex = female', () {
      final svc = ScoringService();
      final femaleProfile = const AftProfile(age: 24, sex: AftSex.female, standard: AftStandard.general);
      // Same input/age should yield same points when using combat vs male directly.
      final malePts = mdlPointsForSex(AftSex.male, femaleProfile.age, 330);
      final combatPts = svc.scoreEvent(AftStandard.combat, femaleProfile, AftEvent.mdl, 330);
      expect(combatPts, malePts);
    });
  });
}
