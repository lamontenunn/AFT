import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/features/proctor/state/proctor_ui_state.dart';

void main() {
  group('ProctorUiController', () {
    test('Persists last selected top tab index', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorUiProvider.notifier);
      ctrl.setTopTabIndex(2);
      expect(container.read(proctorUiProvider).topTabIndex, 2);
    });

    test('Persists last selected timing event', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(proctorUiProvider.notifier);
      ctrl.setTimingEvent(AftEvent.pushUps);
      expect(container.read(proctorUiProvider).timingEvent, AftEvent.pushUps);
    });
  });
}
