import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;

@immutable
class ProctorStopwatchState {
  final Duration elapsedBefore;
  final DateTime? runningSince;
  final List<Duration> lapsCumulative;

  const ProctorStopwatchState({
    required this.elapsedBefore,
    required this.runningSince,
    required this.lapsCumulative,
  });

  factory ProctorStopwatchState.initial() => const ProctorStopwatchState(
        elapsedBefore: Duration.zero,
        runningSince: null,
        lapsCumulative: <Duration>[],
      );

  bool get isRunning => runningSince != null;

  Duration elapsedNow(DateTime now) {
    final rs = runningSince;
    if (rs == null) return elapsedBefore;
    final delta = now.difference(rs);
    return elapsedBefore + delta;
  }

  static const _unset = Object();

  ProctorStopwatchState copyWith({
    Duration? elapsedBefore,
    Object? runningSince = _unset,
    List<Duration>? lapsCumulative,
  }) {
    return ProctorStopwatchState(
      elapsedBefore: elapsedBefore ?? this.elapsedBefore,
      runningSince: identical(runningSince, _unset)
          ? this.runningSince
          : runningSince as DateTime?,
      lapsCumulative: lapsCumulative ?? this.lapsCumulative,
    );
  }
}

@immutable
class ProctorHrpState {
  final Duration elapsedBefore;
  final DateTime? runningSince;
  final int reps;

  const ProctorHrpState({
    required this.elapsedBefore,
    required this.runningSince,
    required this.reps,
  });

  static const Duration total = Duration(minutes: 2);

  factory ProctorHrpState.initial() => const ProctorHrpState(
        elapsedBefore: Duration.zero,
        runningSince: null,
        reps: 0,
      );

  bool get isRunning => runningSince != null;

  Duration elapsedNow(DateTime now) {
    final rs = runningSince;
    if (rs == null) return elapsedBefore;
    final delta = now.difference(rs);
    return elapsedBefore + delta;
  }

  Duration remainingNow(DateTime now) {
    final rem = total - elapsedNow(now);
    if (rem.isNegative) return Duration.zero;
    return rem;
  }

  bool get isFinished {
    // Only accurate if you computed via remainingNow(); used mostly for UI.
    // Stored state can be normalized by notifier.
    return elapsedBefore >= total;
  }

  static const _unset = Object();

  ProctorHrpState copyWith({
    Duration? elapsedBefore,
    Object? runningSince = _unset,
    int? reps,
  }) {
    return ProctorHrpState(
      elapsedBefore: elapsedBefore ?? this.elapsedBefore,
      runningSince: identical(runningSince, _unset)
          ? this.runningSince
          : runningSince as DateTime?,
      reps: reps ?? this.reps,
    );
  }
}

@immutable
class ProctorTimingPerParticipant {
  final Map<AftEvent, ProctorStopwatchState> stopwatches;
  final ProctorHrpState hrp;

  const ProctorTimingPerParticipant({
    required this.stopwatches,
    required this.hrp,
  });

  factory ProctorTimingPerParticipant.initial() => ProctorTimingPerParticipant(
        stopwatches: <AftEvent, ProctorStopwatchState>{
          AftEvent.sdc: ProctorStopwatchState.initial(),
          AftEvent.plank: ProctorStopwatchState.initial(),
          AftEvent.run2mi: ProctorStopwatchState.initial(),
        },
        hrp: ProctorHrpState.initial(),
      );

  ProctorTimingPerParticipant copyWith({
    Map<AftEvent, ProctorStopwatchState>? stopwatches,
    ProctorHrpState? hrp,
  }) {
    return ProctorTimingPerParticipant(
      stopwatches: stopwatches ?? this.stopwatches,
      hrp: hrp ?? this.hrp,
    );
  }
}

@immutable
class ProctorTimingState {
  final Map<String, ProctorTimingPerParticipant> byParticipant;

  const ProctorTimingState({required this.byParticipant});

  factory ProctorTimingState.initial() => const ProctorTimingState(
        byParticipant: <String, ProctorTimingPerParticipant>{},
      );

  ProctorTimingState copyWith({
    Map<String, ProctorTimingPerParticipant>? byParticipant,
  }) {
    return ProctorTimingState(
      byParticipant: byParticipant ?? this.byParticipant,
    );
  }
}

class ProctorTimingController extends Notifier<ProctorTimingState> {
  @override
  ProctorTimingState build() => ProctorTimingState.initial();

  ProctorTimingPerParticipant _ensure(String participantId) {
    final existing = state.byParticipant[participantId];
    if (existing != null) return existing;
    final next = ProctorTimingPerParticipant.initial();
    state = state
        .copyWith(byParticipant: {...state.byParticipant, participantId: next});
    return next;
  }

  ProctorStopwatchState stopwatchOf(String participantId, AftEvent event) {
    final per = _ensure(participantId);
    return per.stopwatches[event] ?? ProctorStopwatchState.initial();
  }

  ProctorHrpState hrpOf(String participantId) {
    final per = _ensure(participantId);
    return per.hrp;
  }

  void startStopwatch(String participantId, AftEvent event) {
    final per = _ensure(participantId);
    final sw = stopwatchOf(participantId, event);
    if (sw.isRunning) return;
    final nextSw = sw.copyWith(runningSince: DateTime.now());
    _setStopwatch(participantId, per, event, nextSw);
  }

  void stopStopwatch(String participantId, AftEvent event) {
    final per = _ensure(participantId);
    final sw = stopwatchOf(participantId, event);
    if (!sw.isRunning) return;
    final now = DateTime.now();
    final elapsed = sw.elapsedNow(now);
    final nextSw = sw.copyWith(elapsedBefore: elapsed, runningSince: null);
    _setStopwatch(participantId, per, event, nextSw);
  }

  void resetStopwatch(String participantId, AftEvent event) {
    final per = _ensure(participantId);
    if (stopwatchOf(participantId, event).isRunning) return;
    _setStopwatch(participantId, per, event, ProctorStopwatchState.initial());
  }

  void lapStopwatch({
    required String participantId,
    required AftEvent event,
    required int cap,
    bool autoStopOnCapReached = false,
  }) {
    final per = _ensure(participantId);
    final sw = stopwatchOf(participantId, event);
    if (!sw.isRunning) return;
    if (sw.lapsCumulative.length >= cap) return;
    final now = DateTime.now();
    final elapsed = sw.elapsedNow(now);
    final nextLaps = [...sw.lapsCumulative, elapsed];

    // Persist the lap
    _setStopwatch(
        participantId, per, event, sw.copyWith(lapsCumulative: nextLaps));

    // Optionally auto-stop when the final lap is recorded.
    if (autoStopOnCapReached && nextLaps.length >= cap) {
      stopStopwatch(participantId, event);
    }
  }

  void stopAllForParticipant(String participantId) {
    final per = state.byParticipant[participantId];
    if (per == null) return;
    final now = DateTime.now();

    final nextStopwatches = <AftEvent, ProctorStopwatchState>{};
    for (final e in per.stopwatches.keys) {
      final sw = per.stopwatches[e] ?? ProctorStopwatchState.initial();
      nextStopwatches[e] = sw.isRunning
          ? sw.copyWith(elapsedBefore: sw.elapsedNow(now), runningSince: null)
          : sw;
    }

    final hrp = per.hrp;
    final nextHrp = hrp.isRunning
        ? _normalizeHrp(hrp.copyWith(
            elapsedBefore: hrp.elapsedNow(now), runningSince: null))
        : hrp;

    _setPerParticipant(participantId,
        per.copyWith(stopwatches: nextStopwatches, hrp: nextHrp));
  }

  void startHrp(String participantId) {
    final per = _ensure(participantId);
    final h = per.hrp;
    if (h.isRunning) return;
    if (h.elapsedBefore >= ProctorHrpState.total) return;
    final next = h.copyWith(runningSince: DateTime.now());
    _setHrp(participantId, per, next);
  }

  void stopHrp(String participantId) {
    final per = _ensure(participantId);
    final h = per.hrp;
    if (!h.isRunning) return;
    final now = DateTime.now();
    final next = _normalizeHrp(
      h.copyWith(elapsedBefore: h.elapsedNow(now), runningSince: null),
    );
    _setHrp(participantId, per, next);
  }

  void resetHrp(String participantId) {
    final per = _ensure(participantId);
    if (per.hrp.isRunning) return;
    _setHrp(participantId, per, ProctorHrpState.initial());
  }

  void incHrpReps(String participantId) {
    final per = _ensure(participantId);
    final h = per.hrp;
    _setHrp(participantId, per, h.copyWith(reps: h.reps + 1));
  }

  void decHrpReps(String participantId) {
    final per = _ensure(participantId);
    final h = per.hrp;
    if (h.reps <= 0) return;
    _setHrp(participantId, per, h.copyWith(reps: h.reps - 1));
  }

  /// Called by UI tickers to clamp HRP to 2:00 and stop it if finished.
  void normalizeHrpIfFinished(String participantId) {
    final per = state.byParticipant[participantId];
    if (per == null) return;
    final h = per.hrp;
    if (!h.isRunning) return;
    final now = DateTime.now();
    final elapsed = h.elapsedNow(now);
    if (elapsed < ProctorHrpState.total) return;
    final next =
        _normalizeHrp(h.copyWith(elapsedBefore: elapsed, runningSince: null));
    _setHrp(participantId, per, next);
  }

  ProctorHrpState _normalizeHrp(ProctorHrpState h) {
    if (h.elapsedBefore >= ProctorHrpState.total) {
      return h.copyWith(
          elapsedBefore: ProctorHrpState.total, runningSince: null);
    }
    return h;
  }

  void _setStopwatch(
    String participantId,
    ProctorTimingPerParticipant per,
    AftEvent event,
    ProctorStopwatchState nextSw,
  ) {
    final nextStopwatches = {...per.stopwatches, event: nextSw};
    _setPerParticipant(
        participantId, per.copyWith(stopwatches: nextStopwatches));
  }

  void _setHrp(
    String participantId,
    ProctorTimingPerParticipant per,
    ProctorHrpState next,
  ) {
    _setPerParticipant(participantId, per.copyWith(hrp: next));
  }

  void _setPerParticipant(
      String participantId, ProctorTimingPerParticipant next) {
    state = state
        .copyWith(byParticipant: {...state.byParticipant, participantId: next});
  }
}

final proctorTimingProvider =
    NotifierProvider<ProctorTimingController, ProctorTimingState>(
        ProctorTimingController.new);
