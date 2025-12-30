import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart'
    show AftComputed;
import 'package:aft_firebase_app/features/proctor/state/proctor_session.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';
import 'package:aft_firebase_app/features/proctor/state/proctor_inputs.dart';

class ProctorSessionNotifier extends Notifier<ProctorSessionState> {
  static const _kPrefsKey = 'proctor_session_v1';

  @override
  ProctorSessionState build() {
    // Start empty; async load will replace.
    _load();
    return ProctorSessionState.initial();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final loaded = ProctorSessionState.fromJsonString(raw);
    state = loaded;
  }

  Future<void> _persist(ProctorSessionState next) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefsKey, next.toJsonString());
  }

  Future<void> addParticipant(ProctorParticipant p) async {
    final nextRoster = [...state.roster, p];
    final next = state.copyWith(
      roster: nextRoster,
      selectedId: state.selectedId ?? p.id,
    );
    state = next;
    await _persist(next);
  }

  Future<void> removeParticipant(String id) async {
    final nextRoster = state.roster.where((e) => e.id != id).toList();
    String? nextSelected = state.selectedId;
    if (nextSelected == id) {
      nextSelected = nextRoster.isEmpty ? null : nextRoster.first.id;
    }
    final next =
        ProctorSessionState(roster: nextRoster, selectedId: nextSelected);
    state = next;
    await _persist(next);
  }

  Future<void> selectParticipant(String id) async {
    final next = state.copyWith(selectedId: id);
    state = next;
    await _persist(next);
  }

  Future<void> updateParticipant(ProctorParticipant updated) async {
    final idx = state.roster.indexWhere((e) => e.id == updated.id);
    if (idx < 0) return;
    final nextRoster = [...state.roster];
    nextRoster[idx] = updated;
    final next = state.copyWith(roster: nextRoster);
    state = next;
    await _persist(next);
  }
}

final proctorSessionProvider =
    NotifierProvider<ProctorSessionNotifier, ProctorSessionState>(
        ProctorSessionNotifier.new);

final selectedProctorParticipantProvider = Provider<ProctorParticipant?>((ref) {
  final s = ref.watch(proctorSessionProvider);
  final id = s.selectedId;
  if (id == null) return null;
  for (final p in s.roster) {
    if (p.id == id) return p;
  }
  return null;
});

/// Proctor-local profile (age/sex/standard).
class ProctorProfileNotifier extends Notifier<AftProfile> {
  @override
  AftProfile build() {
    final selected = ref.watch(selectedProctorParticipantProvider);
    if (selected == null) return AftProfile.initial();
    // IMPORTANT: do not reset standard when participant changes.
    // Preserve current standard selection (default to General at app start).
    final currentStandard = stateOrNull?.standard ?? AftStandard.general;
    return AftProfile(
      age: selected.age,
      sex: selected.sex,
      standard: currentStandard,
    );
  }

  void setStandard(AftStandard s) => state = state.copyWith(standard: s);

  /// Called when roster selection changes.
  void syncFromParticipant(ProctorParticipant p) {
    state = state.copyWith(age: p.age, sex: p.sex);
  }
}

final proctorProfileProvider =
    NotifierProvider<ProctorProfileNotifier, AftProfile>(
        ProctorProfileNotifier.new);

/// Computed scores from the current proctor profile/inputs via ScoringService.
final proctorComputedProvider = Provider<AftComputed>((ref) {
  final profile = ref.watch(proctorProfileProvider);
  final selected = ref.watch(selectedProctorParticipantProvider);
  final selectedId = selected?.id;
  final inputsState = ref.watch(proctorInputsStateProvider);
  final inputs = selectedId == null
      ? const AftInputs()
      : (inputsState.byParticipant[selectedId] ?? const AftInputs());
  final svc = ScoringService();

  final mdl =
      svc.scoreEvent(profile.standard, profile, AftEvent.mdl, inputs.mdlLbs);
  final pu = svc.scoreEvent(
      profile.standard, profile, AftEvent.pushUps, inputs.pushUps);
  final sdc =
      svc.scoreEvent(profile.standard, profile, AftEvent.sdc, inputs.sdc);
  final plank =
      svc.scoreEvent(profile.standard, profile, AftEvent.plank, inputs.plank);
  final run2mi =
      svc.scoreEvent(profile.standard, profile, AftEvent.run2mi, inputs.run2mi);
  final total =
      svc.totalScore(profile.standard, profile, mdl, pu, sdc, plank, run2mi);

  return AftComputed(
    mdlScore: mdl,
    pushUpsScore: pu,
    sdcScore: sdc,
    plankScore: plank,
    run2miScore: run2mi,
    total: total,
  );
});
