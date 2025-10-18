import 'package:flutter_test/flutter_test.dart';
import 'package:aft_firebase_app/features/aft/logic/data/hrp_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/hrp_csv.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';

void main() {
  // Load the provided 20-column (M/F) HRP CSV once for all tests.
  setUpAll(() {
    preloadHrpCsvOnce(hrpCsv);
  });

  group('HRP points with age + sex (fill-down per column)', () {
    group('Male anchors (M17–21)', () {
      test('Top thresholds and base thresholds', () {
        // From CSV M17–21: 100->58, 99->57, 98->55, 60->15, 0->4
        expect(hrpPointsForSex(AftSex.male, 20, 58), 100);
        expect(hrpPointsForSex(AftSex.male, 20, 57), 99);
        expect(hrpPointsForSex(AftSex.male, 20, 55), 98);
        expect(hrpPointsForSex(AftSex.male, 20, 15), 60);
        expect(hrpPointsForSex(AftSex.male, 20, 4), 9);
        expect(hrpPointsForSex(AftSex.male, 20, 3), 0);
      });
    });

    group('Female anchors (F17–21)', () {
      test('Top thresholds and base thresholds', () {
        // From CSV F17–21: 100->53, 99->48, 98->44, 60->11, 0->4
        expect(hrpPointsForSex(AftSex.female, 20, 53), 100);
        expect(hrpPointsForSex(AftSex.female, 20, 48), 99);
        expect(hrpPointsForSex(AftSex.female, 20, 44), 98);
        expect(hrpPointsForSex(AftSex.female, 20, 11), 61);
        expect(hrpPointsForSex(AftSex.female, 20, 4), 9);
      });
    });
  });

  group('Combat standard forces male HRP thresholds', () {
    test('Combat uses male table even if profile.sex = female', () {
      final svc = ScoringService();
      const reps = 33; // from row 82 M17–21? Pick value that exists in male column for 22–26 too
      final femaleProfile = const AftProfile(age: 24, sex: AftSex.female, standard: AftStandard.general);

      final malePts = hrpPointsForSex(AftSex.male, femaleProfile.age, reps);
      final combatPts = svc.scoreEvent(AftStandard.combat, femaleProfile, AftEvent.pushUps, reps);
      expect(combatPts, malePts);
    });
  });
}
