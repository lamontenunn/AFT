import 'package:aft_firebase_app/features/planner/lane_planner_constants.dart';
import 'package:aft_firebase_app/features/planner/lane_planner_models.dart';

const String kIndoorSurfaceWarning =
    'Indoor surface must be artificial turf only';

LanePlannerPlan buildLanePlannerPlan(LanePlannerInput input) {
  final soldiersCount = input.soldiersCount < 0 ? 0 : input.soldiersCount;
  final lanesUsed = (input.lanesAvailable ?? kAftDefaultLanes)
      .clamp(1, kAftMaxLanes)
      .toInt();

  final soldiersPerLanePerCycle =
      _positiveOrDefault(input.soldiersPerLanePerCycle,
          kAftBaselineSoldiersPerLanePerCycle);
  final cycleMinutes =
      _positiveOrDefault(input.cycleMinutes, kAftBaselineCycleMinutes);

  final baselineSoldiersPerCycle = lanesUsed * soldiersPerLanePerCycle;
  final cyclesNeeded = baselineSoldiersPerCycle == 0
      ? 0
      : (soldiersCount / baselineSoldiersPerCycle).ceil();
  final estimatedTotalMinutes = cyclesNeeded * cycleMinutes;

  final hexBarsPerLane =
      (input.hexBarsPerLane ?? 0) > 0 ? input.hexBarsPerLane : null;
  final equipmentRequired = LanePlannerEquipmentRequirements(
    sledsRequired: lanesUsed * kAftSledsPerLane,
    kettlebellPairsRequired: lanesUsed * kAftKettlebellPairsPerLane,
    hexBarsRequired:
        hexBarsPerLane == null ? null : lanesUsed * hexBarsPerLane,
  );

  final warnings = <String>[];
  if (input.environment == LanePlannerEnvironment.indoorOther) {
    warnings.add(kIndoorSurfaceWarning);
  }

  final deficits = <LanePlannerEquipmentDeficit>[];
  final inventory = input.inventory;
  if (inventory != null) {
    _addDeficit(
      deficits,
      item: 'Sleds',
      required: equipmentRequired.sledsRequired,
      available: inventory.sledCount,
    );
    _addDeficit(
      deficits,
      item: 'Kettlebell pairs',
      required: equipmentRequired.kettlebellPairsRequired,
      available: inventory.kettlebellPairsCount,
    );
    if (equipmentRequired.hexBarsRequired != null) {
      _addDeficit(
        deficits,
        item: 'Hex bars',
        required: equipmentRequired.hexBarsRequired!,
        available: inventory.hexBarCount,
      );
    }
  }

  final assumptions = <String>[
    'Baseline throughput: $kAftBaselineSoldiersPerLanePerCycle soldiers per lane '
        'per $kAftBaselineCycleMinutes minutes.',
    'Planning uses: $soldiersPerLanePerCycle soldiers per lane per '
        '$cycleMinutes minutes.',
    if (hexBarsPerLane != null)
      'Hex bars assume $hexBarsPerLane per lane (MDL stations).',
  ];

  return LanePlannerPlan(
    lanesUsed: lanesUsed,
    cyclesNeeded: cyclesNeeded,
    estimatedTotalMinutes: estimatedTotalMinutes,
    siteDimensions: kAftSiteDimensions,
    laneDimensions: kAftLaneDimensions,
    equipmentRequired: equipmentRequired,
    equipmentDeficits: deficits,
    warnings: warnings,
    assumptions: assumptions,
    baselineSoldiersPerCycle: baselineSoldiersPerCycle,
  );
}

int _positiveOrDefault(int? value, int fallback) {
  if (value == null || value <= 0) return fallback;
  return value;
}

void _addDeficit(
  List<LanePlannerEquipmentDeficit> deficits, {
  required String item,
  required int required,
  required int? available,
}) {
  if (available == null) return;
  final sanitizedAvailable = available < 0 ? 0 : available;
  if (sanitizedAvailable >= required) return;
  deficits.add(
    LanePlannerEquipmentDeficit(
      item: item,
      required: required,
      available: sanitizedAvailable,
      deficit: required - sanitizedAvailable,
    ),
  );
}
