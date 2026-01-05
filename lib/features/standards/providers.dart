// Riverpod providers for Standards screen:
// - bandsProvider: list of age bands for dropdown
// - effectiveSexProvider: computed from selection (combat forces male)
// - Per-event column providers (List<String> of length 101 for P=100..0)
// - standardsTableProvider: List<Map<String,String>> rows with keys pts, mdl, hrp, sdc, plk, run2mi

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart'
    show AftEvent;
import 'package:aft_firebase_app/features/standards/state/standards_selection.dart';
import 'package:aft_firebase_app/features/standards/standards_loader.dart';
import 'package:aft_firebase_app/features/standards/display_utils.dart';

// Bands for UI
final bandsProvider = Provider<List<String>>((ref) {
  return listAgeBands();
});

// Effective sex (combat forces male)
final effectiveSexProvider = Provider<AftSex>((ref) {
  final sel = ref.watch(standardsSelectionProvider);
  return sel.effectiveSex;
});

// Current band label
final ageBandProvider = Provider<String>((ref) {
  final sel = ref.watch(standardsSelectionProvider);
  return sel.ageBand;
});

// Per-event columns
final mdlColumnProvider = Provider<List<String>>((ref) {
  final sex = ref.watch(effectiveSexProvider);
  final band = ref.watch(ageBandProvider);
  return loadEventColumn(event: AftEvent.mdl, effectiveSex: sex, ageBand: band);
});

final hrpColumnProvider = Provider<List<String>>((ref) {
  final sex = ref.watch(effectiveSexProvider);
  final band = ref.watch(ageBandProvider);
  return loadEventColumn(
      event: AftEvent.pushUps, effectiveSex: sex, ageBand: band);
});

final sdcColumnProvider = Provider<List<String>>((ref) {
  final sex = ref.watch(effectiveSexProvider);
  final band = ref.watch(ageBandProvider);
  return loadEventColumn(event: AftEvent.sdc, effectiveSex: sex, ageBand: band);
});

final plkColumnProvider = Provider<List<String>>((ref) {
  final sex = ref.watch(effectiveSexProvider);
  final band = ref.watch(ageBandProvider);
  return loadEventColumn(
      event: AftEvent.plank, effectiveSex: sex, ageBand: band);
});

final run2miColumnProvider = Provider<List<String>>((ref) {
  final sex = ref.watch(effectiveSexProvider);
  final band = ref.watch(ageBandProvider);
  return loadEventColumn(
      event: AftEvent.run2mi, effectiveSex: sex, ageBand: band);
});

// Full standards rows (101)
final standardsTableProvider = Provider<List<Map<String, String>>>((ref) {
  final sex = ref.watch(effectiveSexProvider);
  final band = ref.watch(ageBandProvider);
  return buildStandardsRows(effectiveSex: sex, ageBand: band);
});

/// Display-only mapping and deduping (collapse consecutive duplicates 100→0)
final mdlByPointProvider = Provider<Map<int, String>>((ref) {
  final col = ref.watch(mdlColumnProvider);
  return toColumnMap(col);
});
final hrpByPointProvider = Provider<Map<int, String>>((ref) {
  final col = ref.watch(hrpColumnProvider);
  return toColumnMap(col);
});
final sdcByPointProvider = Provider<Map<int, String>>((ref) {
  final col = ref.watch(sdcColumnProvider);
  return toColumnMap(col);
});
final plkByPointProvider = Provider<Map<int, String>>((ref) {
  final col = ref.watch(plkColumnProvider);
  return toColumnMap(col);
});
final run2miByPointProvider = Provider<Map<int, String>>((ref) {
  final col = ref.watch(run2miColumnProvider);
  return toColumnMap(col);
});

final mdlDisplayProvider = Provider<Map<int, String?>>((ref) {
  final col = ref.watch(mdlByPointProvider);
  return squashRunsDescending(col);
});
final hrpDisplayProvider = Provider<Map<int, String?>>((ref) {
  final col = ref.watch(hrpByPointProvider);
  return squashRunsDescending(col);
});
final sdcDisplayProvider = Provider<Map<int, String?>>((ref) {
  final col = ref.watch(sdcByPointProvider);
  return squashRunsDescending(col);
});
final plkDisplayProvider = Provider<Map<int, String?>>((ref) {
  final col = ref.watch(plkByPointProvider);
  return squashRunsDescending(col);
});
final runDisplayProvider = Provider<Map<int, String?>>((ref) {
  final col = ref.watch(run2miByPointProvider);
  return squashRunsDescending(col);
});

class StandardsRow {
  final int pts;
  final String? mdl, hrp, sdc, plk, run2mi;
  const StandardsRow({
    required this.pts,
    this.mdl,
    this.hrp,
    this.sdc,
    this.plk,
    this.run2mi,
  });
}

/// Deduped table for display (nullable cells are rendered blank)
final standardsDisplayTableProvider = Provider<List<StandardsRow>>((ref) {
  final mdl = ref.watch(mdlDisplayProvider);
  final hrp = ref.watch(hrpDisplayProvider);
  final sdc = ref.watch(sdcDisplayProvider);
  final plk = ref.watch(plkDisplayProvider);
  final run = ref.watch(runDisplayProvider);

  return List.generate(101, (i) {
    final pts = 100 - i;
    return StandardsRow(
      pts: pts,
      mdl: mdl[pts],
      hrp: hrp[pts],
      sdc: sdc[pts],
      plk: plk[pts],
      run2mi: run[pts],
    );
  });
});
