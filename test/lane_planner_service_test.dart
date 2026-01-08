import 'package:flutter_test/flutter_test.dart';

import 'package:aft_firebase_app/features/planner/lane_planner_models.dart';
import 'package:aft_firebase_app/features/planner/lane_planner_service.dart';

void main() {
  test('64 soldiers with 16 lanes stays within baseline cycle', () {
    const input = LanePlannerInput(
      soldiersCount: 64,
      lanesAvailable: 16,
      environment: LanePlannerEnvironment.outdoorGrass,
    );

    final plan = buildLanePlannerPlan(input);

    expect(plan.lanesUsed, 16);
    expect(plan.cyclesNeeded, 1);
    expect(plan.estimatedTotalMinutes, lessThanOrEqualTo(90));
    expect(plan.equipmentRequired.sledsRequired, 16);
    expect(plan.equipmentRequired.kettlebellPairsRequired, 16);
  });

  test('38 soldiers with 8 lanes needs two cycles', () {
    const input = LanePlannerInput(
      soldiersCount: 38,
      lanesAvailable: 8,
      environment: LanePlannerEnvironment.outdoorGrass,
    );

    final plan = buildLanePlannerPlan(input);

    expect(plan.lanesUsed, 8);
    expect(plan.cyclesNeeded, 2);
    expect(plan.estimatedTotalMinutes, 180);
  });

  test('inventory deficits are computed correctly', () {
    const input = LanePlannerInput(
      soldiersCount: 50,
      lanesAvailable: 8,
      environment: LanePlannerEnvironment.outdoorGrass,
      inventory: LanePlannerInventory(
        sledCount: 4,
        kettlebellPairsCount: 6,
      ),
    );

    final plan = buildLanePlannerPlan(input);
    final sledDeficit =
        plan.equipmentDeficits.firstWhere((d) => d.item == 'Sleds');
    final kbDeficit = plan.equipmentDeficits
        .firstWhere((d) => d.item == 'Kettlebell pairs');

    expect(sledDeficit.deficit, 4);
    expect(kbDeficit.deficit, 2);
  });
}
