import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/features/proctor/timing/timer_controller.dart';

void main() {
  group('ProctorTimingController', () {
    test('HRP +1 does not stop the timer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorTimingProvider.notifier);
      const pid = 'p1';

      ctrl.startHrp(pid);
      expect(
          container
              .read(proctorTimingProvider)
              .byParticipant[pid]!
              .hrp
              .isRunning,
          true);

      ctrl.incHrpReps(pid);
      final hrp = container.read(proctorTimingProvider).byParticipant[pid]!.hrp;
      expect(hrp.reps, 1);
      expect(hrp.isRunning, true,
          reason: 'Incrementing reps should not clear runningSince');
    });

    test('Stopwatch lap does not stop the timer', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorTimingProvider.notifier);
      const pid = 'p1';

      ctrl.startStopwatch(pid, AftEvent.sdc);
      expect(
          container
              .read(proctorTimingProvider)
              .byParticipant[pid]!
              .stopwatches[AftEvent.sdc]!
              .isRunning,
          true);

      ctrl.lapStopwatch(participantId: pid, event: AftEvent.sdc, cap: 5);
      final sw = container
          .read(proctorTimingProvider)
          .byParticipant[pid]!
          .stopwatches[AftEvent.sdc]!;
      expect(sw.lapsCumulative.length, 1);
      expect(sw.isRunning, true,
          reason: 'Adding a lap should not clear runningSince');
    });

    test('Lap cap is enforced (2MR cap 25)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorTimingProvider.notifier);
      const pid = 'p1';

      ctrl.startStopwatch(pid, AftEvent.run2mi);
      for (int i = 0; i < 30; i++) {
        ctrl.lapStopwatch(participantId: pid, event: AftEvent.run2mi, cap: 25);
      }

      final sw = container
          .read(proctorTimingProvider)
          .byParticipant[pid]!
          .stopwatches[AftEvent.run2mi]!;
      expect(sw.lapsCumulative.length, 25);
    });

    test('stopAllForParticipant stops all timers', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorTimingProvider.notifier);
      const pid = 'p1';

      ctrl.startStopwatch(pid, AftEvent.sdc);
      ctrl.startStopwatch(pid, AftEvent.plank);
      ctrl.startHrp(pid);

      ctrl.stopAllForParticipant(pid);

      final per = container.read(proctorTimingProvider).byParticipant[pid]!;
      expect(per.hrp.isRunning, false);
      expect(per.stopwatches[AftEvent.sdc]!.isRunning, false);
      expect(per.stopwatches[AftEvent.plank]!.isRunning, false);
    });
  });
}
