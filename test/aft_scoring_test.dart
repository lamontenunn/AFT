import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';

import 'package:aft_firebase_app/features/aft/logic/data/mdl_csv.dart';
import 'package:aft_firebase_app/features/aft/logic/data/hrp_csv.dart';
import 'package:aft_firebase_app/features/aft/logic/data/sdc_csv.dart';
import 'package:aft_firebase_app/features/aft/logic/data/plk_csv.dart';
import 'package:aft_firebase_app/features/aft/logic/data/run2mi_csv.dart';

import 'package:aft_firebase_app/features/aft/logic/data/mdl_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/hrp_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/sdc_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/plk_table.dart';
import 'package:aft_firebase_app/features/aft/logic/data/run2mi_table.dart';

Duration _mmss(String s) {
  final parts = s.split(':');
  return Duration(minutes: int.parse(parts[0]), seconds: int.parse(parts[1]));
}

void main() {
  setUpAll(() {
    preloadMdlCsvOnce(mdlCsv);
    preloadHrpCsvOnce(hrpCsv);
    preloadSdcCsvOnce(sdcCsv);
    preloadPlkCsvOnce(plkCsv);
    preloadRun2miCsvOnce(run2miCsv);
  });

  group('MDL (weight-based, higher is better)', () {
    test('Anchors and boundaries - M17-21', () {
      expect(mdlPointsForSex(AftSex.male, 20, 340), 100);
      expect(mdlPointsForSex(AftSex.male, 20, 330), 98);
      expect(mdlPointsForSex(AftSex.male, 20, 300), 92);
      // boundary below/above
      expect(mdlPointsForSex(AftSex.male, 20, 79), 0);
      expect(mdlPointsForSex(AftSex.male, 20, 80), 0);
    });

    test('Anchors - M22-26', () {
      expect(mdlPointsForSex(AftSex.male, 24, 350), 100);
      expect(mdlPointsForSex(AftSex.male, 24, 340), 99);
      expect(mdlPointsForSex(AftSex.male, 24, 330), 97);
      expect(mdlPointsForSex(AftSex.male, 24, 80), 0);
      expect(mdlPointsForSex(AftSex.male, 24, 145), 50);
    });

    test('Anchors - M62+', () {
      expect(mdlPointsForSex(AftSex.male, 65, 170), 92);
      expect(mdlPointsForSex(AftSex.male, 65, 140), 60);
      expect(mdlPointsForSex(AftSex.male, 65, 120), 40);
    });

    test('Female anchors - F17–21', () {
      expect(mdlPointsForSex(AftSex.female, 20, 220), 100);
      expect(mdlPointsForSex(AftSex.female, 20, 210), 98);
      expect(mdlPointsForSex(AftSex.female, 20, 120), 60);
      expect(mdlPointsForSex(AftSex.female, 20, 60), 0);
    });
  });

  group('HRP (rep-based, higher is better)', () {
    test('Anchors - M17–21', () {
      expect(hrpPointsForSex(AftSex.male, 20, 58), 100);
      expect(hrpPointsForSex(AftSex.male, 20, 57), 99);
      expect(hrpPointsForSex(AftSex.male, 20, 55), 98);
      expect(hrpPointsForSex(AftSex.male, 20, 15), 60);
    });

    test('Anchors - F17–21', () {
      expect(hrpPointsForSex(AftSex.female, 20, 53), 100);
      expect(hrpPointsForSex(AftSex.female, 20, 48), 99);
      expect(hrpPointsForSex(AftSex.female, 20, 44), 98);
      expect(hrpPointsForSex(AftSex.female, 20, 11), 61);
    });
  });

  group('SDC (time-based, lower is better)', () {
    test('Anchors and boundaries - M17–21', () {
      expect(sdcPointsForSex(AftSex.male, 20, _mmss('1:29')), 100);
      expect(sdcPointsForSex(AftSex.male, 20, _mmss('1:31')), 99);
      // faster yields same or higher points (<=)
      expect(sdcPointsForSex(AftSex.male, 20, _mmss('1:28')), 100);
      // slower yields lower points
      expect(sdcPointsForSex(AftSex.male, 20, _mmss('1:32')), 98);
    });

    test('Anchors - F17–21', () {
      expect(sdcPointsForSex(AftSex.female, 20, _mmss('1:55')), 100);
      expect(sdcPointsForSex(AftSex.female, 20, _mmss('1:59')), 99);
    });
  });

  group('PLK (time-based, higher is better)', () {
    test('Anchors and boundaries - M17–21', () {
      expect(plkPointsForSex(AftSex.male, 20, _mmss('3:40')), 100);
      expect(plkPointsForSex(AftSex.male, 20, _mmss('3:08')), 90);
      // lower than 100-point requirement yields lower points
      expect(plkPointsForSex(AftSex.male, 20, _mmss('3:39')), 99);
      expect(plkPointsForSex(AftSex.male, 20, _mmss('3:07')), lessThan(90));
    });
  });

  group('2MR (time-based, lower is better)', () {
    test('Anchors and boundaries - M17–21', () {
      expect(run2miPointsForSex(AftSex.male, 20, _mmss('13:22')), 100);
      expect(run2miPointsForSex(AftSex.male, 20, _mmss('19:57')), 60);
      expect(run2miPointsForSex(AftSex.male, 20, _mmss('13:21')), 100); // faster is fine
      expect(run2miPointsForSex(AftSex.male, 20, _mmss('13:23')), lessThan(100));
    });

    test('Anchors - F17–21', () {
      expect(run2miPointsForSex(AftSex.female, 20, _mmss('16:00')), 100);
      expect(run2miPointsForSex(AftSex.female, 20, _mmss('22:55')), 61);
    });
  });

  group('Combat overrides male thresholds for all events', () {
    final svc = ScoringService();

    test('MDL (combat female == male)', () {
      final malePts = mdlPointsForSex(AftSex.male, 24, 330);
      final combatPts = svc.scoreEvent(
        AftStandard.combat,
        const AftProfile(age: 24, sex: AftSex.female, standard: AftStandard.general),
        AftEvent.mdl,
        330,
      );
      expect(combatPts, malePts);
    });

    test('HRP (combat female == male)', () {
      final malePts = hrpPointsForSex(AftSex.male, 24, 40);
      final combatPts = svc.scoreEvent(
        AftStandard.combat,
        const AftProfile(age: 24, sex: AftSex.female, standard: AftStandard.general),
        AftEvent.pushUps,
        40,
      );
      expect(combatPts, malePts);
    });

    test('SDC (combat female == male)', () {
      final t = _mmss('1:45');
      final malePts = sdcPointsForSex(AftSex.male, 24, t);
      final combatPts = svc.scoreEvent(
        AftStandard.combat,
        const AftProfile(age: 24, sex: AftSex.female, standard: AftStandard.general),
        AftEvent.sdc,
        t,
      );
      expect(combatPts, malePts);
    });

    test('PLK (combat female == male)', () {
      final t = _mmss('2:30');
      final malePts = plkPointsForSex(AftSex.male, 24, t);
      final combatPts = svc.scoreEvent(
        AftStandard.combat,
        const AftProfile(age: 24, sex: AftSex.female, standard: AftStandard.general),
        AftEvent.plank,
        t,
      );
      expect(combatPts, malePts);
    });

    test('2MR (combat female == male)', () {
      final t = _mmss('17:30');
      final malePts = run2miPointsForSex(AftSex.male, 24, t);
      final combatPts = svc.scoreEvent(
        AftStandard.combat,
        const AftProfile(age: 24, sex: AftSex.female, standard: AftStandard.general),
        AftEvent.run2mi,
        t,
      );
      expect(combatPts, malePts);
    });
  });

  group('Total is a dynamic partial sum via providers', () {
    test('Partial totals as inputs change', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Profile context
      container.read(aftProfileProvider.notifier).setAge(20);
      container.read(aftProfileProvider.notifier).setSex(AftSex.male);
      container.read(aftProfileProvider.notifier).setStandard(AftStandard.general);

      AftComputed comp() => container.read(aftComputedProvider);

      // Initially no inputs -> total 0
      expect(comp().total, 0);

      // MDL only -> +100
      container.read(aftInputsProvider.notifier).setMdlLbs(340);
      expect(comp().mdlScore, 100);
      expect(comp().total, 100);

      // Add HRP -> +99
      container.read(aftInputsProvider.notifier).setPushUps(57);
      expect(comp().pushUpsScore, 99);
      expect(comp().total, 199);

      // Add SDC -> +100 (1:29)
      container.read(aftInputsProvider.notifier).setSdc(_mmss('1:29'));
      expect(comp().sdcScore, 100);
      expect(comp().total, 299);

      // Add PLK -> >= 3:40 => +100
      container.read(aftInputsProvider.notifier).setPlank(_mmss('3:40'));
      expect(comp().plankScore, 100);
      expect(comp().total, 399);

      // Add 2MR -> 13:22 => +100
      container.read(aftInputsProvider.notifier).setRun2mi(_mmss('13:22'));
      expect(comp().run2miScore, 100);
      expect(comp().total, 499);
    });
  });
}
