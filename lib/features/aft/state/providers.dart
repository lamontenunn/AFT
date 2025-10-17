import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart';

/// Profile state (age, sex, test date, selected standard)
class ProfileNotifier extends Notifier<AftProfile> {
  @override
  AftProfile build() => AftProfile.initial();

  void setAge(int age) => state = state.copyWith(age: age);
  void setSex(AftSex sex) => state = state.copyWith(sex: sex);
  void setStandard(AftStandard s) => state = state.copyWith(standard: s);
  void setTestDate(DateTime? date) => state = state.copyWith(testDate: date);
}

final aftProfileProvider =
    NotifierProvider<ProfileNotifier, AftProfile>(ProfileNotifier.new);

/// Inputs state for active attempt (first three events for now)
class InputsNotifier extends Notifier<AftInputs> {
  @override
  AftInputs build() => AftInputs.initial();

  void setMdlLbs(int? lbs) => state = state.copyWith(mdlLbs: lbs);
  void setPushUps(int? reps) => state = state.copyWith(pushUps: reps);
  void setSdc(Duration? time) => state = state.copyWith(sdc: time);
  void setPlank(Duration? time) => state = state.copyWith(plank: time);
  void setRun2mi(Duration? time) => state = state.copyWith(run2mi: time);

  void clearAll() => state = const AftInputs();
}

final aftInputsProvider =
    NotifierProvider<InputsNotifier, AftInputs>(InputsNotifier.new);

/// Computed scores from the current profile/inputs via ScoringService.
class AftComputed {
  final int? mdlScore;
  final int? pushUpsScore;
  final int? sdcScore;
  final int? plankScore;
  final int? run2miScore;
  final int? total;

  const AftComputed({
    required this.mdlScore,
    required this.pushUpsScore,
    required this.sdcScore,
    required this.plankScore,
    required this.run2miScore,
    required this.total,
  });
}

final aftComputedProvider = Provider<AftComputed>((ref) {
  final profile = ref.watch(aftProfileProvider);
  final inputs = ref.watch(aftInputsProvider);
  final svc = ScoringService();

  final mdl = svc.scoreEvent(
    profile.standard,
    profile,
    AftEvent.mdl,
    inputs.mdlLbs,
  );
  final pu = svc.scoreEvent(
    profile.standard,
    profile,
    AftEvent.pushUps,
    inputs.pushUps,
  );
  final sdc = svc.scoreEvent(
    profile.standard,
    profile,
    AftEvent.sdc,
    inputs.sdc,
  );
  final plank = svc.scoreEvent(
    profile.standard,
    profile,
    AftEvent.plank,
    inputs.plank,
  );
  final run2mi = svc.scoreEvent(
    profile.standard,
    profile,
    AftEvent.run2mi,
    inputs.run2mi,
  );

  final total = svc.totalScore(profile.standard, profile, mdl, pu, sdc);

  return AftComputed(
    mdlScore: mdl,
    pushUpsScore: pu,
    sdcScore: sdc,
    plankScore: plank,
    run2miScore: run2mi,
    total: total,
  );
});
