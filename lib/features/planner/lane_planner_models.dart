import 'package:flutter/foundation.dart';

const _unset = Object();

enum LanePlannerEnvironment {
  outdoorGrass,
  outdoorTurf,
  indoorTurf,
  indoorOther,
}

extension LanePlannerEnvironmentCodec on LanePlannerEnvironment {
  String get value {
    switch (this) {
      case LanePlannerEnvironment.outdoorGrass:
        return 'outdoor_grass';
      case LanePlannerEnvironment.outdoorTurf:
        return 'outdoor_turf';
      case LanePlannerEnvironment.indoorTurf:
        return 'indoor_turf';
      case LanePlannerEnvironment.indoorOther:
        return 'indoor_other';
    }
  }

  String get label {
    switch (this) {
      case LanePlannerEnvironment.outdoorGrass:
        return 'Outdoor grass';
      case LanePlannerEnvironment.outdoorTurf:
        return 'Outdoor turf';
      case LanePlannerEnvironment.indoorTurf:
        return 'Indoor turf';
      case LanePlannerEnvironment.indoorOther:
        return 'Indoor other';
    }
  }

  static LanePlannerEnvironment? fromValue(String value) {
    switch (value) {
      case 'outdoor_grass':
        return LanePlannerEnvironment.outdoorGrass;
      case 'outdoor_turf':
        return LanePlannerEnvironment.outdoorTurf;
      case 'indoor_turf':
        return LanePlannerEnvironment.indoorTurf;
      case 'indoor_other':
        return LanePlannerEnvironment.indoorOther;
    }
    return null;
  }
}

@immutable
class LanePlannerInventory {
  final int? sledCount;
  final int? kettlebellPairsCount;
  final int? hexBarCount;

  const LanePlannerInventory({
    this.sledCount,
    this.kettlebellPairsCount,
    this.hexBarCount,
  });

  LanePlannerInventory copyWith({
    Object? sledCount = _unset,
    Object? kettlebellPairsCount = _unset,
    Object? hexBarCount = _unset,
  }) {
    return LanePlannerInventory(
      sledCount: sledCount == _unset ? this.sledCount : sledCount as int?,
      kettlebellPairsCount: kettlebellPairsCount == _unset
          ? this.kettlebellPairsCount
          : kettlebellPairsCount as int?,
      hexBarCount:
          hexBarCount == _unset ? this.hexBarCount : hexBarCount as int?,
    );
  }

  static LanePlannerInventory? fromJson(Object? json) {
    if (json == null) return null;
    if (json is! Map<String, dynamic>) {
      throw const FormatException('inventory must be an object or null.');
    }
    return LanePlannerInventory(
      sledCount: _parseNonNegativeInt(json['sledCount'], 'inventory.sledCount'),
      kettlebellPairsCount: _parseNonNegativeInt(
        json['kettlebellPairsCount'],
        'inventory.kettlebellPairsCount',
      ),
      hexBarCount:
          _parseNonNegativeInt(json['hexBarCount'], 'inventory.hexBarCount'),
    );
  }
}

@immutable
class LanePlannerInput {
  final int soldiersCount;
  final int? lanesAvailable;
  final LanePlannerEnvironment environment;
  final LanePlannerInventory? inventory;
  final int? cycleMinutes;
  final int? soldiersPerLanePerCycle;
  final int? hexBarsPerLane;

  const LanePlannerInput({
    required this.soldiersCount,
    required this.environment,
    this.lanesAvailable,
    this.inventory,
    this.cycleMinutes,
    this.soldiersPerLanePerCycle,
    this.hexBarsPerLane,
  });

  factory LanePlannerInput.initial() => const LanePlannerInput(
        soldiersCount: 64,
        lanesAvailable: 4,
        environment: LanePlannerEnvironment.outdoorGrass,
        inventory: null,
        cycleMinutes: null,
        soldiersPerLanePerCycle: null,
        hexBarsPerLane: null,
      );

  LanePlannerInput copyWith({
    int? soldiersCount,
    Object? lanesAvailable = _unset,
    LanePlannerEnvironment? environment,
    Object? inventory = _unset,
    Object? cycleMinutes = _unset,
    Object? soldiersPerLanePerCycle = _unset,
    Object? hexBarsPerLane = _unset,
  }) {
    return LanePlannerInput(
      soldiersCount: soldiersCount ?? this.soldiersCount,
      lanesAvailable: lanesAvailable == _unset
          ? this.lanesAvailable
          : lanesAvailable as int?,
      environment: environment ?? this.environment,
      inventory: inventory == _unset
          ? this.inventory
          : inventory as LanePlannerInventory?,
      cycleMinutes: cycleMinutes == _unset
          ? this.cycleMinutes
          : cycleMinutes as int?,
      soldiersPerLanePerCycle: soldiersPerLanePerCycle == _unset
          ? this.soldiersPerLanePerCycle
          : soldiersPerLanePerCycle as int?,
      hexBarsPerLane: hexBarsPerLane == _unset
          ? this.hexBarsPerLane
          : hexBarsPerLane as int?,
    );
  }

  static LanePlannerInput fromJson(Map<String, dynamic> json) {
    final soldiersCount =
        _parseRequiredNonNegativeInt(json['soldiersCount'], 'soldiersCount');
    final lanesAvailable =
        _parseNonNegativeInt(json['lanesAvailable'], 'lanesAvailable');
    final environmentValue = json['environment'];
    if (environmentValue is! String) {
      throw const FormatException('environment must be a string.');
    }
    final environment = LanePlannerEnvironmentCodec.fromValue(environmentValue);
    if (environment == null) {
      throw FormatException('Invalid environment: $environmentValue');
    }

    final inventory = LanePlannerInventory.fromJson(json['inventory']);
    final cycleMinutes =
        _parseNonNegativeInt(json['cycleMinutes'], 'cycleMinutes');
    final soldiersPerLanePerCycle = _parseNonNegativeInt(
      json['soldiersPerLanePerCycle'],
      'soldiersPerLanePerCycle',
    );

    return LanePlannerInput(
      soldiersCount: soldiersCount,
      lanesAvailable: lanesAvailable,
      environment: environment,
      inventory: inventory,
      cycleMinutes: cycleMinutes,
      soldiersPerLanePerCycle: soldiersPerLanePerCycle,
      hexBarsPerLane: null,
    );
  }
}

@immutable
class LanePlannerDimensions {
  final int lengthMeters;
  final int widthMeters;

  const LanePlannerDimensions({
    required this.lengthMeters,
    required this.widthMeters,
  });
}

@immutable
class LanePlannerEquipmentRequirements {
  final int sledsRequired;
  final int kettlebellPairsRequired;
  final int? hexBarsRequired;

  const LanePlannerEquipmentRequirements({
    required this.sledsRequired,
    required this.kettlebellPairsRequired,
    this.hexBarsRequired,
  });
}

@immutable
class LanePlannerEquipmentDeficit {
  final String item;
  final int required;
  final int available;
  final int deficit;

  const LanePlannerEquipmentDeficit({
    required this.item,
    required this.required,
    required this.available,
    required this.deficit,
  });
}

@immutable
class LanePlannerPlan {
  final int lanesUsed;
  final int cyclesNeeded;
  final int estimatedTotalMinutes;
  final LanePlannerDimensions siteDimensions;
  final LanePlannerDimensions laneDimensions;
  final LanePlannerEquipmentRequirements equipmentRequired;
  final List<LanePlannerEquipmentDeficit> equipmentDeficits;
  final List<String> warnings;
  final List<String> assumptions;
  final int baselineSoldiersPerCycle;

  const LanePlannerPlan({
    required this.lanesUsed,
    required this.cyclesNeeded,
    required this.estimatedTotalMinutes,
    required this.siteDimensions,
    required this.laneDimensions,
    required this.equipmentRequired,
    required this.equipmentDeficits,
    required this.warnings,
    required this.assumptions,
    required this.baselineSoldiersPerCycle,
  });
}

int _parseRequiredNonNegativeInt(Object? value, String field) {
  final parsed = _parseNonNegativeInt(value, field);
  if (parsed == null) {
    throw FormatException('$field must be a non-negative number.');
  }
  return parsed;
}

int? _parseNonNegativeInt(Object? value, String field) {
  if (value == null) return null;
  if (value is int) {
    if (value < 0) {
      throw FormatException('$field must be non-negative.');
    }
    return value;
  }
  if (value is num) {
    final rounded = value.round();
    if (value.toDouble() != rounded.toDouble()) {
      throw FormatException('$field must be a whole number.');
    }
    if (rounded < 0) {
      throw FormatException('$field must be non-negative.');
    }
    return rounded;
  }
  throw FormatException('$field must be a number or null.');
}
