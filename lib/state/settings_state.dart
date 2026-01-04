import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:state_notifier/state_notifier.dart';

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
    _loadFuture = _load();
    _ref.listen<AsyncValue<User?>>(
      firebaseUserProvider,
      (previous, next) {
        final auth = _ref.read(firebaseAuthProvider);
        final user = next.asData?.value ?? auth?.currentUser;
        _handleAuthChange(user);
      },
      fireImmediately: true,
    );
  }

  late final Future<void> _loadFuture;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  String? _activeUserId;
  String? _activeScope;
  bool _isApplyingRemote = false;

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
  static const _kDpUpdatedAt = 'settings_defaultProfile_updatedAt'; // millis
  static const _signedOutScope = 'signed-out';
  static const List<String> _dpScopedKeys = [
    _kDpFirstName,
    _kDpLastName,
    _kDpMiddleInitial,
    _kDpRankAbbrev,
    _kDpUnit,
    _kDpMos,
    _kDpPayGrade,
    _kDpOnProfile,
    _kDpBirthdate,
    _kDpSex,
    _kDpMeasSystem,
    _kDpHeight,
    _kDpWeight,
    _kDpBodyFat,
    _kDpUpdatedAt,
  ];
  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final haptics = prefs.getBool(_kHaptics);
    final themeIdx = prefs.getInt(_kThemeMode);
    final showCombatInfo = prefs.getBool(_kShowCombatInfo);
    final dp = _readLegacyProfileFromPrefs(prefs);
    // Always prefill calculator now; legacy key ignored.

    // Cleanup deprecated keys (best-effort).
    prefs.remove('settings_navLabelBehavior');
    prefs.remove('settings_applyDefaultsOnCalculator');

    final dpUpdatedAt = prefs.getInt(_kDpUpdatedAt);
    if (dpUpdatedAt == null && _profileHasData(dp)) {
      await prefs.setInt(
        _kDpUpdatedAt,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
    if (!mounted) return;

    state = state.copyWith(
      hapticsEnabled: haptics ?? SettingsState.defaults.hapticsEnabled,
      themeMode: _themeModeFromIndex(
          themeIdx ?? _themeModeToIndex(SettingsState.defaults.themeMode)),
      showCombatInfo: showCombatInfo ?? SettingsState.defaults.showCombatInfo,
      defaultProfile: dp,
    );
  }

  DocumentReference<Map<String, dynamic>> _profileDoc(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid);
  }

  Future<void> _handleAuthChange(User? user) async {
    if (!mounted) return;
    final nextScope = _scopeForUser(user);
    final expectedUserId = (user == null || user.isAnonymous) ? null : user.uid;
    if (_activeScope == nextScope && _activeUserId == expectedUserId) return;
    _activeScope = nextScope;

    if (user == null || user.isAnonymous) {
      _activeUserId = expectedUserId;
      await _profileSub?.cancel();
      _profileSub = null;
      await _loadFuture;
      if (!mounted ||
          _activeScope != nextScope ||
          _activeUserId != expectedUserId) {
        return;
      }
      await _loadProfileForScope(nextScope, allowLegacy: false);
      return;
    }

    _activeUserId = expectedUserId;
    await _profileSub?.cancel();
    _profileSub = null;
    await _loadFuture;
    if (!mounted ||
        _activeScope != nextScope ||
        _activeUserId != expectedUserId) {
      return;
    }
    if (user != null && !user.isAnonymous) {
      await _maybeMigrateGuestProfileToUser(user.uid);
    }
    await _loadProfileForScope(nextScope, allowLegacy: true);
    if (!mounted ||
        _activeScope != nextScope ||
        _activeUserId != expectedUserId) {
      return;
    }
    await _syncProfileWithFirestore(user.uid);
    if (!mounted ||
        _activeScope != nextScope ||
        _activeUserId != expectedUserId) {
      return;
    }
    _listenToRemoteProfile(user.uid);
  }

  String _scopeForUser(User? user) {
    if (user == null) return _signedOutScope;
    if (user.isAnonymous) return 'guest:${user.uid}';
    return user.uid;
  }

  String _scopedKey(String base, String scope) => '$base:$scope';

  Future<void> _maybeMigrateGuestProfileToUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final guestScope = 'guest:$uid';
    if (!_hasScopedProfileData(prefs, guestScope)) return;
    final guestProfile = _readProfileFromPrefs(prefs, scope: guestScope);
    if (!_profileHasData(guestProfile)) return;
    final guestUpdatedAt =
        prefs.getInt(_scopedKey(_kDpUpdatedAt, guestScope)) ?? 0;
    final userUpdatedAt = prefs.getInt(_scopedKey(_kDpUpdatedAt, uid)) ?? 0;
    if (userUpdatedAt >= guestUpdatedAt && _hasScopedProfileData(prefs, uid)) {
      return;
    }
    await _writeProfileToPrefs(
      prefs,
      uid,
      guestProfile,
      guestUpdatedAt > 0
          ? guestUpdatedAt
          : DateTime.now().millisecondsSinceEpoch,
    );
    await _clearScopedProfilePrefs(prefs, guestScope);
  }

  bool _hasScopedProfileData(SharedPreferences prefs, String scope) {
    for (final base in _dpScopedKeys) {
      if (prefs.containsKey(_scopedKey(base, scope))) {
        return true;
      }
    }
    return false;
  }

  DefaultProfileSettings _readProfileFromPrefs(
    SharedPreferences prefs, {
    required String scope,
  }) {
    final dpDobStr = prefs.getString(_scopedKey(_kDpBirthdate, scope));
    final dpSexStr = prefs.getString(_scopedKey(_kDpSex, scope));
    return DefaultProfileSettings(
      firstName:
          _emptyToNull(prefs.getString(_scopedKey(_kDpFirstName, scope))),
      lastName: _emptyToNull(prefs.getString(_scopedKey(_kDpLastName, scope))),
      middleInitial:
          _emptyToNull(prefs.getString(_scopedKey(_kDpMiddleInitial, scope))),
      rankAbbrev:
          _emptyToNull(prefs.getString(_scopedKey(_kDpRankAbbrev, scope))),
      unit: _emptyToNull(prefs.getString(_scopedKey(_kDpUnit, scope))),
      mos: _emptyToNull(prefs.getString(_scopedKey(_kDpMos, scope))),
      payGrade: _emptyToNull(prefs.getString(_scopedKey(_kDpPayGrade, scope))),
      onProfile: prefs.getBool(_scopedKey(_kDpOnProfile, scope)) ??
          DefaultProfileSettings.defaults.onProfile,
      birthdate: _parseYmd(dpDobStr),
      sex: _parseSex(dpSexStr),
      measurementSystem: _measurementFromIndex(
        prefs.getInt(_scopedKey(_kDpMeasSystem, scope)) ?? 0,
      ),
      height: prefs.getDouble(_scopedKey(_kDpHeight, scope)),
      weight: prefs.getDouble(_scopedKey(_kDpWeight, scope)),
      bodyFatPercent: prefs.getDouble(_scopedKey(_kDpBodyFat, scope)),
    );
  }

  DefaultProfileSettings _readLegacyProfileFromPrefs(
    SharedPreferences prefs,
  ) {
    final dpDobStr =
        prefs.getString(_kDpBirthdate) ?? prefs.getString(_kDefaultBirthdate);
    final dpSexStr = prefs.getString(_kDpSex) ?? prefs.getString(_kDefaultSex);
    return DefaultProfileSettings(
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
  }

  Future<void> _loadProfileForScope(
    String scope, {
    required bool allowLegacy,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final scopedProfile = _readProfileFromPrefs(prefs, scope: scope);
    if (_hasScopedProfileData(prefs, scope) || _profileHasData(scopedProfile)) {
      state = state.copyWith(defaultProfile: scopedProfile);
      return;
    }

    if (allowLegacy) {
      final legacyProfile = _readLegacyProfileFromPrefs(prefs);
      if (_profileHasData(legacyProfile)) {
        state = state.copyWith(defaultProfile: legacyProfile);
        final legacyUpdatedAt = prefs.getInt(_kDpUpdatedAt) ??
            DateTime.now().millisecondsSinceEpoch;
        await _writeProfileToPrefs(
          prefs,
          scope,
          legacyProfile,
          legacyUpdatedAt,
        );
        await _clearLegacyProfilePrefs(prefs);
        return;
      }
    }

    state = state.copyWith(defaultProfile: DefaultProfileSettings.defaults);
  }

  void _listenToRemoteProfile(String uid) {
    _profileSub = _profileDoc(uid).snapshots().listen((snapshot) {
      if (!mounted) return;
      if (_activeUserId != uid || !snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;
      _applyRemoteProfile(data);
    });
  }

  Future<void> _syncProfileWithFirestore(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final scope = uid;
    final localUpdatedAt = prefs.getInt(_scopedKey(_kDpUpdatedAt, scope)) ?? 0;

    final doc = await _profileDoc(uid).get();
    if (!mounted) return;
    final localProfile = state.defaultProfile;
    final data = doc.data();
    if (data == null) {
      if (localUpdatedAt > 0 || _profileHasData(localProfile)) {
        await _pushProfileToFirestore(uid, localProfile);
      }
      return;
    }

    final remoteProfileRaw = data['defaultProfile'];
    if (remoteProfileRaw == null) {
      if (localUpdatedAt > 0 || _profileHasData(localProfile)) {
        await _pushProfileToFirestore(uid, localProfile);
      }
      return;
    }

    final remoteProfile = _defaultProfileFromMap(
      Map<String, dynamic>.from(remoteProfileRaw as Map),
    );
    final remoteUpdatedAt =
        _coerceDate(data['updatedAt'])?.millisecondsSinceEpoch ?? 0;

    if (localUpdatedAt == 0) {
      if (_profileHasData(remoteProfile)) {
        await _applyRemoteProfile(data);
      }
      return;
    }

    if (remoteUpdatedAt > localUpdatedAt) {
      await _applyRemoteProfile(data);
    } else if (localUpdatedAt > remoteUpdatedAt) {
      await _pushProfileToFirestore(uid, localProfile);
    }
  }

  Future<void> _applyRemoteProfile(Map<String, dynamic> data) async {
    if (!mounted) return;
    final profileRaw = data['defaultProfile'];
    if (profileRaw == null) return;

    final profile =
        _defaultProfileFromMap(Map<String, dynamic>.from(profileRaw as Map));
    final updatedAt = _coerceDate(data['updatedAt']) ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final scope = _activeScope ?? _signedOutScope;
    final localUpdatedAt = prefs.getInt(_scopedKey(_kDpUpdatedAt, scope)) ?? 0;
    if (updatedAt.millisecondsSinceEpoch <= localUpdatedAt) {
      return;
    }

    _isApplyingRemote = true;
    try {
      await setDefaultProfile(
        profile,
        updatedAt: updatedAt,
        syncRemote: false,
      );
    } finally {
      _isApplyingRemote = false;
    }
  }

  Future<void> _pushProfileToFirestore(
    String uid,
    DefaultProfileSettings profile,
  ) async {
    await _profileDoc(uid).set(
      {
        'defaultProfile': _defaultProfileToMap(profile),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Default Profile setters
  Future<void> setDefaultProfile(
    DefaultProfileSettings profile, {
    DateTime? updatedAt,
    bool syncRemote = true,
  }) async {
    if (!mounted) return;
    final stamp = updatedAt ?? DateTime.now();
    state = state.copyWith(defaultProfile: profile);
    final auth = _ref.read(firebaseAuthProvider);
    final currentUser = auth?.currentUser;
    final prefs = await SharedPreferences.getInstance();
    final scope = currentUser != null
        ? _scopeForUser(currentUser)
        : (_activeScope ?? _signedOutScope);
    await _writeProfileToPrefs(
      prefs,
      scope,
      profile,
      stamp.millisecondsSinceEpoch,
    );
    if (syncRemote && !_isApplyingRemote) {
      if (currentUser != null && !currentUser.isAnonymous) {
        await _pushProfileToFirestore(currentUser.uid, profile);
      }
    }
  }

  Future<void> updateDefaultProfile(
      DefaultProfileSettings Function(DefaultProfileSettings) updater) async {
    final next = updater(state.defaultProfile);
    await setDefaultProfile(next);
  }

  Future<void> _writeProfileToPrefs(
    SharedPreferences prefs,
    String scope,
    DefaultProfileSettings profile,
    int updatedAtMillis,
  ) async {
    Future<void> setOrRemoveString(String key, String? value) async {
      final v = value?.trim();
      if (v == null || v.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, v);
      }
    }

    await setOrRemoveString(
        _scopedKey(_kDpFirstName, scope), profile.firstName);
    await setOrRemoveString(_scopedKey(_kDpLastName, scope), profile.lastName);
    await setOrRemoveString(
        _scopedKey(_kDpMiddleInitial, scope), profile.middleInitial);
    await setOrRemoveString(
        _scopedKey(_kDpRankAbbrev, scope), profile.rankAbbrev);
    await setOrRemoveString(_scopedKey(_kDpUnit, scope), profile.unit);
    await setOrRemoveString(_scopedKey(_kDpMos, scope), profile.mos);
    await setOrRemoveString(_scopedKey(_kDpPayGrade, scope), profile.payGrade);
    await prefs.setBool(_scopedKey(_kDpOnProfile, scope), profile.onProfile);

    if (profile.birthdate == null) {
      await prefs.remove(_scopedKey(_kDpBirthdate, scope));
    } else {
      await prefs.setString(
          _scopedKey(_kDpBirthdate, scope), _formatYmd(profile.birthdate!));
    }

    if (profile.sex == null) {
      await prefs.remove(_scopedKey(_kDpSex, scope));
    } else {
      await prefs.setString(_scopedKey(_kDpSex, scope),
          profile.sex == AftSex.male ? 'male' : 'female');
    }

    await prefs.setInt(_scopedKey(_kDpMeasSystem, scope),
        _measurementToIndex(profile.measurementSystem));

    if (profile.height == null) {
      await prefs.remove(_scopedKey(_kDpHeight, scope));
    } else {
      await prefs.setDouble(_scopedKey(_kDpHeight, scope), profile.height!);
    }

    if (profile.weight == null) {
      await prefs.remove(_scopedKey(_kDpWeight, scope));
    } else {
      await prefs.setDouble(_scopedKey(_kDpWeight, scope), profile.weight!);
    }

    if (profile.bodyFatPercent == null) {
      await prefs.remove(_scopedKey(_kDpBodyFat, scope));
    } else {
      await prefs.setDouble(
          _scopedKey(_kDpBodyFat, scope), profile.bodyFatPercent!);
    }

    await prefs.setInt(_scopedKey(_kDpUpdatedAt, scope), updatedAtMillis);
  }

  Future<void> _clearLegacyProfilePrefs(SharedPreferences prefs) async {
    for (final key in _dpScopedKeys) {
      await prefs.remove(key);
    }
    await prefs.remove(_kDefaultBirthdate);
    await prefs.remove(_kDefaultSex);
  }

  Future<void> _clearScopedProfilePrefs(
    SharedPreferences prefs,
    String scope,
  ) async {
    for (final key in _dpScopedKeys) {
      await prefs.remove(_scopedKey(key, scope));
    }
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

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  /// Backwards-compatible wrappers (used by existing UI while we migrate).
  Future<void> setDefaultBirthdate(DateTime? dob) async {
    await updateDefaultProfile(
        (p) => p.copyWith(birthdate: dob, clearBirthdate: dob == null));
    // Also keep legacy key in sync so older builds (if any) still work.
    if (_activeScope == _signedOutScope) {
      final prefs = await SharedPreferences.getInstance();
      if (dob == null) {
        await prefs.remove(_kDefaultBirthdate);
      } else {
        await prefs.setString(_kDefaultBirthdate, _formatYmd(dob));
      }
    }
  }

  Future<void> setDefaultSex(AftSex? sex) async {
    await updateDefaultProfile(
        (p) => p.copyWith(sex: sex, clearSex: sex == null));
    if (_activeScope == _signedOutScope) {
      final prefs = await SharedPreferences.getInstance();
      if (sex == null) {
        await prefs.remove(_kDefaultSex);
      } else {
        await prefs.setString(
            _kDefaultSex, sex == AftSex.male ? 'male' : 'female');
      }
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

  bool _profileHasData(DefaultProfileSettings profile) {
    if (profile.firstName?.trim().isNotEmpty == true) return true;
    if (profile.lastName?.trim().isNotEmpty == true) return true;
    if (profile.middleInitial?.trim().isNotEmpty == true) return true;
    if (profile.rankAbbrev?.trim().isNotEmpty == true) return true;
    if (profile.unit?.trim().isNotEmpty == true) return true;
    if (profile.mos?.trim().isNotEmpty == true) return true;
    if (profile.payGrade?.trim().isNotEmpty == true) return true;
    if (profile.sex != null) return true;
    if (profile.birthdate != null) return true;
    if (profile.onProfile != DefaultProfileSettings.defaults.onProfile) {
      return true;
    }
    if (profile.measurementSystem !=
        DefaultProfileSettings.defaults.measurementSystem) {
      return true;
    }
    if (profile.height != null) return true;
    if (profile.weight != null) return true;
    if (profile.bodyFatPercent != null) return true;
    return false;
  }

  Map<String, dynamic> _defaultProfileToMap(DefaultProfileSettings profile) {
    return {
      'firstName': profile.firstName,
      'lastName': profile.lastName,
      'middleInitial': profile.middleInitial,
      'rankAbbrev': profile.rankAbbrev,
      'unit': profile.unit,
      'mos': profile.mos,
      'payGrade': profile.payGrade,
      'onProfile': profile.onProfile,
      'sex': profile.sex?.name,
      'birthdate': profile.birthdate == null
          ? null
          : Timestamp.fromDate(profile.birthdate!),
      'measurementSystem': profile.measurementSystem.name,
      'height': profile.height,
      'weight': profile.weight,
      'bodyFatPercent': profile.bodyFatPercent,
    };
  }

  DefaultProfileSettings _defaultProfileFromMap(Map<String, dynamic> data) {
    return DefaultProfileSettings(
      firstName: _emptyToNull(data['firstName'] as String?),
      lastName: _emptyToNull(data['lastName'] as String?),
      middleInitial: _emptyToNull(data['middleInitial'] as String?),
      rankAbbrev: _emptyToNull(data['rankAbbrev'] as String?),
      unit: _emptyToNull(data['unit'] as String?),
      mos: _emptyToNull(data['mos'] as String?),
      payGrade: _emptyToNull(data['payGrade'] as String?),
      onProfile: data['onProfile'] as bool? ??
          DefaultProfileSettings.defaults.onProfile,
      sex: _parseSex(data['sex'] as String?),
      birthdate: _coerceDate(data['birthdate']),
      measurementSystem: _measurementFromValue(data['measurementSystem']),
      height: (data['height'] as num?)?.toDouble(),
      weight: (data['weight'] as num?)?.toDouble(),
      bodyFatPercent: (data['bodyFatPercent'] as num?)?.toDouble(),
    );
  }

  MeasurementSystem _measurementFromValue(dynamic value) {
    if (value is String) {
      if (value == 'metric') return MeasurementSystem.metric;
      if (value == 'imperial') return MeasurementSystem.imperial;
    }
    if (value is num) return _measurementFromIndex(value.toInt());
    return DefaultProfileSettings.defaults.measurementSystem;
  }

  DateTime? _coerceDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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
    legacy.StateNotifierProvider<SettingsController, SettingsState>((ref) {
  return SettingsController(ref);
});
