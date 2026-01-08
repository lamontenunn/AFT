import 'package:aft_firebase_app/features/planner/lane_planner_models.dart';

/// Site dimensions in meters for the AFT testing area (30 m x 50 m).
/// Source: AFT site + lanes guidance (test area sizing).
const LanePlannerDimensions kAftSiteDimensions = LanePlannerDimensions(
  lengthMeters: 50,
  widthMeters: 30,
);

/// Lane dimensions in meters for each AFT lane (25 m x 3 m).
/// Source: AFT site + lanes guidance (lane sizing).
const LanePlannerDimensions kAftLaneDimensions = LanePlannerDimensions(
  lengthMeters: 25,
  widthMeters: 3,
);

/// Maximum number of lanes per site.
/// Source: AFT site + lanes guidance (max 16 lanes).
const int kAftMaxLanes = 16;

/// App default lane count when a plan does not specify lanes.
const int kAftDefaultLanes = 4;

/// Baseline throughput is 64 Soldiers per 90 minutes with 16 lanes.
/// Source: AFT throughput baseline (64 Soldiers / 16 lanes).
const int kAftBaselineSoldiersPerLanePerCycle = 4;

/// Default cycle duration in minutes for the baseline throughput.
/// Source: AFT throughput baseline (90 minutes).
const int kAftBaselineCycleMinutes = 90;

/// SDC equipment per lane: one 90 lb sled per lane.
/// Source: AFT equipment list (SDC sled requirement).
const int kAftSledsPerLane = 1;

/// SDC equipment per lane: one pair of 40 lb kettlebells per lane.
/// Source: AFT equipment list (SDC kettlebell requirement).
const int kAftKettlebellPairsPerLane = 1;

/// MDL equipment per lane/station: one 60 lb hex/trap bar per lane.
/// Source: AFT equipment appendix (MDL hex/trap bar requirement).
const int kAftHexBarsPerLane = 1;
