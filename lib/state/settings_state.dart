import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';

enum NavLabelBehavior {
  onlySelected,
  always,
}

@immutable
class SettingsState {
  final bool hapticsEnabled;
  final NavLabelBehavior navBehavior;

  // Default profile settings
  final DateTime? defaultBirthdate;
  final AftSex? defaultSex;
  final bool applyDefaultsOnCalculator;

  const SettingsState({
    required this.hapticsEnabled,
    required this.navBehavior,
    this.defaultBirthdate,
    this.defaultSex,
    required this.applyDefaultsOnCalculator,
  });

  SettingsState copyWith({
    bool? hapticsEnabled,
    NavLabelBehavior? navBehavior,
    DateTime? defaultBirthdate,
    AftSex? defaultSex,
    bool? applyDefaultsOnCalculator,
    bool clearBirthdate = false,
    bool clearSex = false,
  }) {
    return SettingsState(
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      navBehavior: navBehavior ?? this.navBehavior,
      defaultBirthdate: clearBirthdate ? null : (defaultBirthdate ?? this.defaultBirthdate),
      defaultSex: clearSex ? null : (defaultSex ?? this.defaultSex),
      applyDefaultsOnCalculator:
          applyDefaultsOnCalculator ?? this.applyDefaultsOnCalculator,
    );
  }

  static const SettingsState defaults = SettingsState(
    hapticsEnabled: true,
    navBehavior: NavLabelBehavior.onlySelected,
    defaultBirthdate: null,
    defaultSex: null,
    applyDefaultsOnCalculator: true,
  );
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._ref) : super(SettingsState.defaults) {
    _load();
  }

  static const _kHaptics = 'settings_hapticsEnabled';
  static const _kNavBehavior = 'settings_navLabelBehavior'; // 0: onlySelected, 1: always
  static const _kDefaultBirthdate = 'settings_defaultBirthdate'; // yyyy-MM-dd
  static const _kDefaultSex = 'settings_defaultSex'; // 'male' | 'female'
  static const _kPrefillCalc = 'settings_applyDefaultsOnCalculator';

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final haptics = prefs.getBool(_kHaptics);
    final navIdx = prefs.getInt(_kNavBehavior);
    final dobStr = prefs.getString(_kDefaultBirthdate);
    final sexStr = prefs.getString(_kDefaultSex);
    final prefill = prefs.getBool(_kPrefillCalc);

    state = state.copyWith(
      hapticsEnabled: haptics ?? SettingsState.defaults.hapticsEnabled,
      navBehavior: _fromIndex(navIdx ?? 0),
      defaultBirthdate: _parseYmd(dobStr),
      defaultSex: _parseSex(sexStr),
      applyDefaultsOnCalculator:
          prefill ?? SettingsState.defaults.applyDefaultsOnCalculator,
    );
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    state = state.copyWith(hapticsEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHaptics, enabled);
  }

  Future<void> setNavBehavior(NavLabelBehavior behavior) async {
    state = state.copyWith(navBehavior: behavior);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kNavBehavior, _toIndex(behavior));
  }

  Future<void> setDefaultBirthdate(DateTime? dob) async {
    state = state.copyWith(defaultBirthdate: dob, clearBirthdate: dob == null);
    final prefs = await SharedPreferences.getInstance();
    if (dob == null) {
      await prefs.remove(_kDefaultBirthdate);
    } else {
      await prefs.setString(_kDefaultBirthdate, _formatYmd(dob));
    }
  }

  Future<void> setDefaultSex(AftSex? sex) async {
    state = state.copyWith(defaultSex: sex, clearSex: sex == null);
    final prefs = await SharedPreferences.getInstance();
    if (sex == null) {
      await prefs.remove(_kDefaultSex);
    } else {
      await prefs.setString(_kDefaultSex, sex == AftSex.male ? 'male' : 'female');
    }
  }

  Future<void> setApplyDefaultsOnCalculator(bool enabled) async {
    state = state.copyWith(applyDefaultsOnCalculator: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefillCalc, enabled);
  }

  int _toIndex(NavLabelBehavior b) {
    switch (b) {
      case NavLabelBehavior.onlySelected:
        return 0;
      case NavLabelBehavior.always:
        return 1;
    }
  }

  NavLabelBehavior _fromIndex(int i) {
    switch (i) {
      case 0:
        return NavLabelBehavior.onlySelected;
      case 1:
        return NavLabelBehavior.always;
      default:
        return SettingsState.defaults.navBehavior;
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
}

final settingsProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref);
});
