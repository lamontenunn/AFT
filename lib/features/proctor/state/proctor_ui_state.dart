import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;

@immutable
class ProctorUiState {
  final int topTabIndex; // 0 timing, 1 instructions, 2 tools
  final AftEvent timingEvent;

  const ProctorUiState({
    required this.topTabIndex,
    required this.timingEvent,
  });

  factory ProctorUiState.initial() => const ProctorUiState(
        topTabIndex: 0,
        timingEvent: AftEvent.sdc,
      );

  ProctorUiState copyWith({int? topTabIndex, AftEvent? timingEvent}) {
    return ProctorUiState(
      topTabIndex: topTabIndex ?? this.topTabIndex,
      timingEvent: timingEvent ?? this.timingEvent,
    );
  }
}

class ProctorUiController extends Notifier<ProctorUiState> {
  @override
  ProctorUiState build() => ProctorUiState.initial();

  void setTopTabIndex(int idx) => state = state.copyWith(topTabIndex: idx);
  void setTimingEvent(AftEvent e) => state = state.copyWith(timingEvent: e);
}

final proctorUiProvider = NotifierProvider<ProctorUiController, ProctorUiState>(
    ProctorUiController.new);
