import 'package:flutter_test/flutter_test.dart';

import 'package:aft_firebase_app/features/proctor/proctor_screen.dart'
    show neededHrpRepsByNow;

void main() {
  test('neededHrpRepsByNow uses ceil and clamps to 0..target', () {
    // 0s => 0 needed
    expect(
      neededHrpRepsByNow(targetReps: 40, elapsed: Duration.zero),
      0,
    );

    // 60s => 0.5 => ceil(40*0.5)=20
    expect(
      neededHrpRepsByNow(targetReps: 40, elapsed: const Duration(seconds: 60)),
      20,
    );

    // 119s => 0.9916 => ceil(40*0.9916)=40
    expect(
      neededHrpRepsByNow(targetReps: 40, elapsed: const Duration(seconds: 119)),
      40,
    );

    // 120s => 1.0 => 40
    expect(
      neededHrpRepsByNow(targetReps: 40, elapsed: const Duration(seconds: 120)),
      40,
    );
  });
}
