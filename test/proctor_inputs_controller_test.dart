import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/features/proctor/state/proctor_inputs.dart';

void main() {
  group('ProctorInputsController', () {
    test('Inputs are per participant and do not overwrite each other', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorInputsStateProvider.notifier);

      ctrl.setPushUps('A', 10);
      ctrl.setPushUps('B', 20);

      final state = container.read(proctorInputsStateProvider);
      expect(state.byParticipant['A']!.pushUps, 10);
      expect(state.byParticipant['B']!.pushUps, 20);
    });

    test('clearEvent clears only the selected event', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorInputsStateProvider.notifier);
      const pid = 'A';

      ctrl.setPushUps(pid, 25);
      ctrl.setSdc(pid, const Duration(seconds: 100));

      ctrl.clearEvent(pid, AftEvent.sdc);

      final inputs =
          container.read(proctorInputsStateProvider).byParticipant[pid]!;
      expect(inputs.sdc, isNull);
      expect(inputs.pushUps, 25);
    });
  });
}
