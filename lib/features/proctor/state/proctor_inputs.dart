import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;

@immutable
class ProctorInputsState {
  final Map<String, AftInputs> byParticipant;

  const ProctorInputsState({required this.byParticipant});

  factory ProctorInputsState.initial() => const ProctorInputsState(
        byParticipant: <String, AftInputs>{},
      );

  ProctorInputsState copyWith({Map<String, AftInputs>? byParticipant}) {
    return ProctorInputsState(
        byParticipant: byParticipant ?? this.byParticipant);
  }
}

class ProctorInputsController extends Notifier<ProctorInputsState> {
  @override
  ProctorInputsState build() => ProctorInputsState.initial();

  AftInputs inputsOf(String participantId) {
    return state.byParticipant[participantId] ?? AftInputs.initial();
  }

  void setInputs(String participantId, AftInputs inputs) {
    state = state.copyWith(
        byParticipant: {...state.byParticipant, participantId: inputs});
  }

  void setPushUps(String participantId, int? reps) {
    final cur = inputsOf(participantId);
    setInputs(participantId, cur.copyWith(pushUps: reps));
  }

  void setSdc(String participantId, Duration? time) {
    final cur = inputsOf(participantId);
    setInputs(participantId, cur.copyWith(sdc: time));
  }

  void setPlank(String participantId, Duration? time) {
    final cur = inputsOf(participantId);
    setInputs(participantId, cur.copyWith(plank: time));
  }

  void setRun2mi(String participantId, Duration? time) {
    final cur = inputsOf(participantId);
    setInputs(participantId, cur.copyWith(run2mi: time));
  }

  void clearEvent(String participantId, AftEvent event) {
    final cur = inputsOf(participantId);
    switch (event) {
      case AftEvent.pushUps:
        setInputs(participantId, cur.copyWith(pushUps: null));
        break;
      case AftEvent.sdc:
        setInputs(participantId, cur.copyWith(clearSdc: true));
        break;
      case AftEvent.plank:
        setInputs(participantId, cur.copyWith(clearPlank: true));
        break;
      case AftEvent.run2mi:
        setInputs(participantId, cur.copyWith(clearRun2mi: true));
        break;
      default:
        break;
    }
  }
}

final proctorInputsStateProvider =
    NotifierProvider<ProctorInputsController, ProctorInputsState>(
        ProctorInputsController.new);
