import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';

enum MeasurementSystem {
  imperial,
  metric,
}

@immutable
class DefaultProfileSettings {
  // DA Form 705-ish profile fields (all optional unless noted)
  final String? firstName;
  final String? lastName;
  final String? middleInitial;

  /// Rank abbreviation for greetings/insignia (e.g., "SGT", "SSG", "CPT", "PV1").
  /// NOTE: This is stored as an abbrev string (not pay grade).
  final String? rankAbbrev;

  final AftSex? sex;
  final DateTime? birthdate;

  final String? unit;
  final String? mos;
  final String? payGrade;

  /// "On profile" (user-defined flag)
  final bool onProfile;

  /// Measurement system for height/weight fields.
  final MeasurementSystem measurementSystem;

  /// Height storage:
  /// - imperial: store total inches
  /// - metric: store centimeters
  final double? height;

  /// Weight storage:
  /// - imperial: store pounds
  /// - metric: store kilograms
  final double? weight;

  /// Body fat percentage [0..100]
  final double? bodyFatPercent;

  const DefaultProfileSettings({
    this.firstName,
    this.lastName,
    this.middleInitial,
    this.rankAbbrev,
    this.sex,
    this.birthdate,
    this.unit,
    this.mos,
    this.payGrade,
    this.onProfile = false,
    this.measurementSystem = MeasurementSystem.imperial,
    this.height,
    this.weight,
    this.bodyFatPercent,
  });

  DefaultProfileSettings copyWith({
    String? firstName,
    bool clearFirstName = false,
    String? lastName,
    bool clearLastName = false,
    String? middleInitial,
    bool clearMiddleInitial = false,
    String? rankAbbrev,
    bool clearRankAbbrev = false,
    AftSex? sex,
    bool clearSex = false,
    DateTime? birthdate,
    bool clearBirthdate = false,
    String? unit,
    bool clearUnit = false,
    String? mos,
    bool clearMos = false,
    String? payGrade,
    bool clearPayGrade = false,
    bool? onProfile,
    MeasurementSystem? measurementSystem,
    double? height,
    bool clearHeight = false,
    double? weight,
    bool clearWeight = false,
    double? bodyFatPercent,
    bool clearBodyFatPercent = false,
  }) {
    return DefaultProfileSettings(
      firstName: clearFirstName ? null : (firstName ?? this.firstName),
      lastName: clearLastName ? null : (lastName ?? this.lastName),
      middleInitial:
          clearMiddleInitial ? null : (middleInitial ?? this.middleInitial),
      rankAbbrev: clearRankAbbrev ? null : (rankAbbrev ?? this.rankAbbrev),
      sex: clearSex ? null : (sex ?? this.sex),
      birthdate: clearBirthdate ? null : (birthdate ?? this.birthdate),
      unit: clearUnit ? null : (unit ?? this.unit),
      mos: clearMos ? null : (mos ?? this.mos),
      payGrade: clearPayGrade ? null : (payGrade ?? this.payGrade),
      onProfile: onProfile ?? this.onProfile,
      measurementSystem: measurementSystem ?? this.measurementSystem,
      height: clearHeight ? null : (height ?? this.height),
      weight: clearWeight ? null : (weight ?? this.weight),
      bodyFatPercent:
          clearBodyFatPercent ? null : (bodyFatPercent ?? this.bodyFatPercent),
    );
  }

  static const DefaultProfileSettings defaults = DefaultProfileSettings();
}

@immutable
class SettingsState {
  final bool hapticsEnabled;

  // Theme
  final ThemeMode themeMode;

  // UI flags
  final bool showCombatInfo;

  // Default profile settings (DA 705 style)
  final DefaultProfileSettings defaultProfile;

  const SettingsState({
    required this.hapticsEnabled,
    required this.themeMode,
    required this.showCombatInfo,
    required this.defaultProfile,
  });

  SettingsState copyWith({
    bool? hapticsEnabled,
    ThemeMode? themeMode,
    bool? showCombatInfo,
    DefaultProfileSettings? defaultProfile,
  }) {
    return SettingsState(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      themeMode: themeMode ?? this.themeMode,
      showCombatInfo: showCombatInfo ?? this.showCombatInfo,
      defaultProfile: defaultProfile ?? this.defaultProfile,
    );
  }

  static const SettingsState defaults = SettingsState(
    hapticsEnabled: true,
    themeMode: ThemeMode.dark,
    showCombatInfo: true,
    defaultProfile: DefaultProfileSettings.defaults,
  );
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._ref) : super(SettingsState.defaults) {
    _load();
  }

  static const _kHaptics = 'settings_hapticsEnabled';
  static const _kThemeMode =
      'settings_themeMode'; // 0: system, 1: light, 2: dark
  static const _kShowCombatInfo = 'settings_showCombatInfo'; // bool
  // Legacy keys (kept for migration)
  static const _kDefaultBirthdate = 'settings_defaultBirthdate'; // yyyy-MM-dd
  static const _kDefaultSex = 'settings_defaultSex'; // 'male' | 'female'

  // New DefaultProfile keys
  static const _kDpFirstName = 'settings_defaultProfile_firstName';
  static const _kDpLastName = 'settings_defaultProfile_lastName';
  static const _kDpMiddleInitial = 'settings_defaultProfile_middleInitial';
  static const _kDpRankAbbrev = 'settings_defaultProfile_rankAbbrev';
  static const _kDpUnit = 'settings_defaultProfile_unit';
  static const _kDpMos = 'settings_defaultProfile_mos';
  static const _kDpPayGrade = 'settings_defaultProfile_payGrade';
  static const _kDpOnProfile = 'settings_defaultProfile_onProfile';
  static const _kDpBirthdate =
      'settings_defaultProfile_birthdate'; // yyyy-MM-dd
  static const _kDpSex = 'settings_defaultProfile_sex'; // 'male' | 'female'
  static const _kDpMeasSystem =
      'settings_defaultProfile_measurementSystem'; // 0: imperial, 1: metric
  static const _kDpHeight = 'settings_defaultProfile_height'; // double
  static const _kDpWeight = 'settings_defaultProfile_weight'; // double
  static const _kDpBodyFat = 'settings_defaultProfile_bodyFatPercent'; // double
  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final haptics = prefs.getBool(_kHaptics);
    final themeIdx = prefs.getInt(_kThemeMode);
    final showCombatInfo = prefs.getBool(_kShowCombatInfo);
    // New profile values (fallback to legacy)
    final dpDobStr =
        prefs.getString(_kDpBirthdate) ?? prefs.getString(_kDefaultBirthdate);
    final dpSexStr = prefs.getString(_kDpSex) ?? prefs.getString(_kDefaultSex);
    final dp = DefaultProfileSettings(
      firstName: _emptyToNull(prefs.getString(_kDpFirstName)),
      lastName: _emptyToNull(prefs.getString(_kDpLastName)),
      middleInitial: _emptyToNull(prefs.getString(_kDpMiddleInitial)),
      rankAbbrev: _emptyToNull(prefs.getString(_kDpRankAbbrev)),
      unit: _emptyToNull(prefs.getString(_kDpUnit)),
      mos: _emptyToNull(prefs.getString(_kDpMos)),
      payGrade: _emptyToNull(prefs.getString(_kDpPayGrade)),
      onProfile: prefs.getBool(_kDpOnProfile) ??
          DefaultProfileSettings.defaults.onProfile,
      birthdate: _parseYmd(dpDobStr),
      sex: _parseSex(dpSexStr),
      measurementSystem:
          _measurementFromIndex(prefs.getInt(_kDpMeasSystem) ?? 0),
      height: prefs.getDouble(_kDpHeight),
      weight: prefs.getDouble(_kDpWeight),
      bodyFatPercent: prefs.getDouble(_kDpBodyFat),
    );
    // Always prefill calculator now; legacy key ignored.

    // Cleanup deprecated keys (best-effort).
    prefs.remove('settings_navLabelBehavior');
    prefs.remove('settings_applyDefaultsOnCalculator');

    state = state.copyWith(
      hapticsEnabled: haptics ?? SettingsState.defaults.hapticsEnabled,
      themeMode: _themeModeFromIndex(
          themeIdx ?? _themeModeToIndex(SettingsState.defaults.themeMode)),
      showCombatInfo: showCombatInfo ?? SettingsState.defaults.showCombatInfo,
      defaultProfile: dp,
    );
  }

  /// Default Profile setters
  Future<void> setDefaultProfile(DefaultProfileSettings profile) async {
    state = state.copyWith(defaultProfile: profile);
    final prefs = await SharedPreferences.getInstance();

    Future<void> setOrRemoveString(String key, String? value) async {
      final v = value?.trim();
      if (v == null || v.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, v);
      }
    }

    await setOrRemoveString(_kDpFirstName, profile.firstName);
    await setOrRemoveString(_kDpLastName, profile.lastName);
    await setOrRemoveString(_kDpMiddleInitial, profile.middleInitial);
    await setOrRemoveString(_kDpRankAbbrev, profile.rankAbbrev);
    await setOrRemoveString(_kDpUnit, profile.unit);
    await setOrRemoveString(_kDpMos, profile.mos);
    await setOrRemoveString(_kDpPayGrade, profile.payGrade);
    await prefs.setBool(_kDpOnProfile, profile.onProfile);

    if (profile.birthdate == null) {
      await prefs.remove(_kDpBirthdate);
    } else {
      await prefs.setString(_kDpBirthdate, _formatYmd(profile.birthdate!));
    }

    if (profile.sex == null) {
      await prefs.remove(_kDpSex);
    } else {
      await prefs.setString(
          _kDpSex, profile.sex == AftSex.male ? 'male' : 'female');
    }

    await prefs.setInt(
        _kDpMeasSystem, _measurementToIndex(profile.measurementSystem));

    if (profile.height == null) {
      await prefs.remove(_kDpHeight);
    } else {
      await prefs.setDouble(_kDpHeight, profile.height!);
    }

    if (profile.weight == null) {
      await prefs.remove(_kDpWeight);
    } else {
      await prefs.setDouble(_kDpWeight, profile.weight!);
    }

    if (profile.bodyFatPercent == null) {
      await prefs.remove(_kDpBodyFat);
    } else {
      await prefs.setDouble(_kDpBodyFat, profile.bodyFatPercent!);
    }
  }

  Future<void> updateDefaultProfile(
      DefaultProfileSettings Function(DefaultProfileSettings) updater) async {
    final next = updater(state.defaultProfile);
    await setDefaultProfile(next);
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    state = state.copyWith(hapticsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHaptics, enabled);
  }

  Future<void> setShowCombatInfo(bool show) async {
    state = state.copyWith(showCombatInfo: show);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowCombatInfo, show);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, _themeModeToIndex(mode));
  }

  /// Backwards-compatible wrappers (used by existing UI while we migrate).
  Future<void> setDefaultBirthdate(DateTime? dob) async {
    await updateDefaultProfile(
        (p) => p.copyWith(birthdate: dob, clearBirthdate: dob == null));
    // Also keep legacy key in sync so older builds (if any) still work.
    final prefs = await SharedPreferences.getInstance();
    if (dob == null) {
      await prefs.remove(_kDefaultBirthdate);
    } else {
      await prefs.setString(_kDefaultBirthdate, _formatYmd(dob));
    }
  }

  Future<void> setDefaultSex(AftSex? sex) async {
    await updateDefaultProfile(
        (p) => p.copyWith(sex: sex, clearSex: sex == null));
    final prefs = await SharedPreferences.getInstance();
    if (sex == null) {
      await prefs.remove(_kDefaultSex);
    } else {
      await prefs.setString(
          _kDefaultSex, sex == AftSex.male ? 'male' : 'female');
    }
  }

  // nav label behavior removed.

  int _themeModeToIndex(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return 0;
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
    }
  }

  ThemeMode _themeModeFromIndex(int i) {
    switch (i) {
      case 0:
        return ThemeMode.system;
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return SettingsState.defaults.themeMode;
    }
  }

  DateTime? _parseYmd(String? s) {
    if (s == null || s.isEmpty) return null;
    // Expect yyyy-MM-dd
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  String _formatYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final da = d.day.toString().padLeft(2, '0');
    return '$y-$m-$da';
  }

  AftSex? _parseSex(String? s) {
    if (s == null) return null;
    if (s == 'male') return AftSex.male;
    if (s == 'female') return AftSex.female;
    return null;
  }

  String? _emptyToNull(String? s) {
    if (s == null) return null;
    final v = s.trim();
    return v.isEmpty ? null : v;
  }

  int _measurementToIndex(MeasurementSystem m) {
    switch (m) {
      case MeasurementSystem.imperial:
        return 0;
      case MeasurementSystem.metric:
        return 1;
    }
  }

  MeasurementSystem _measurementFromIndex(int i) {
    switch (i) {
      case 0:
        return MeasurementSystem.imperial;
      case 1:
        return MeasurementSystem.metric;
      default:
        return DefaultProfileSettings.defaults.measurementSystem;
    }
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref);
});
