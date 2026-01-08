import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/planner/lane_planner_constants.dart';
import 'package:aft_firebase_app/features/planner/lane_planner_models.dart';
import 'package:aft_firebase_app/features/planner/lane_planner_service.dart';

@immutable
class LanePlannerState {
  final LanePlannerInput input;
  final LanePlannerPlan plan;

  const LanePlannerState({
    required this.input,
    required this.plan,
  });

  factory LanePlannerState.initial() {
    final input = LanePlannerInput.initial();
    return LanePlannerState(input: input, plan: buildLanePlannerPlan(input));
  }

  LanePlannerState copyWith({
    LanePlannerInput? input,
    LanePlannerPlan? plan,
  }) {
    return LanePlannerState(
      input: input ?? this.input,
      plan: plan ?? this.plan,
    );
  }
}

class LanePlannerController extends Notifier<LanePlannerState> {
  @override
  LanePlannerState build() => LanePlannerState.initial();

  void setSoldiersCount(int value) {
    final next = state.input
        .copyWith(soldiersCount: value.clamp(0, 999999).toInt());
    _recompute(next);
  }

  void setLanesAvailable(int? value) {
    final next = state.input.copyWith(
      lanesAvailable:
          value == null ? null : value.clamp(1, kAftMaxLanes).toInt(),
    );
    _recompute(next);
  }

  void setEnvironment(LanePlannerEnvironment environment) {
    final next = state.input.copyWith(environment: environment);
    _recompute(next);
  }

  void setCycleMinutes(int? value) {
    final next = state.input.copyWith(
      cycleMinutes: _sanitizeOptionalPositive(value),
    );
    _recompute(next);
  }

  void setSoldiersPerLanePerCycle(int? value) {
    final next = state.input.copyWith(
      soldiersPerLanePerCycle: _sanitizeOptionalPositive(value),
    );
    _recompute(next);
  }

  void setHexBarsPerLane(int? value) {
    final next = state.input.copyWith(
      hexBarsPerLane: _sanitizeOptionalPositive(value),
    );
    _recompute(next);
  }

  void setInventory(LanePlannerInventory? inventory) {
    final next = state.input.copyWith(inventory: inventory);
    _recompute(next);
  }

  void setSledCount(int? value) {
    final inv = state.input.inventory ?? const LanePlannerInventory();
    final nextInv = inv.copyWith(
      sledCount: value == null ? null : value.clamp(0, 999999).toInt(),
    );
    _recompute(state.input.copyWith(inventory: _normalizeInventory(nextInv)));
  }

  void setKettlebellPairsCount(int? value) {
    final inv = state.input.inventory ?? const LanePlannerInventory();
    final nextInv = inv.copyWith(
      kettlebellPairsCount:
          value == null ? null : value.clamp(0, 999999).toInt(),
    );
    _recompute(state.input.copyWith(inventory: _normalizeInventory(nextInv)));
  }

  void setHexBarCount(int? value) {
    final inv = state.input.inventory ?? const LanePlannerInventory();
    final nextInv = inv.copyWith(
      hexBarCount: value == null ? null : value.clamp(0, 999999).toInt(),
    );
    _recompute(state.input.copyWith(inventory: _normalizeInventory(nextInv)));
  }

  void setInput(LanePlannerInput input) {
    _recompute(input);
  }

  void _recompute(LanePlannerInput input) {
    state = state.copyWith(input: input, plan: buildLanePlannerPlan(input));
  }
}

final lanePlannerProvider =
    NotifierProvider<LanePlannerController, LanePlannerState>(
  LanePlannerController.new,
);

int? _sanitizeOptionalPositive(int? value) {
  if (value == null || value <= 0) return null;
  return value;
}

LanePlannerInventory? _normalizeInventory(LanePlannerInventory inv) {
  if (inv.sledCount == null &&
      inv.kettlebellPairsCount == null &&
      inv.hexBarCount == null) {
    return null;
  }
  return inv;
}
