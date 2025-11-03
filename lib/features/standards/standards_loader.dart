// Standards loader: turns embedded CSV-like strings into 101-value columns
// for a selected (effectiveSex, ageBand), applying "fill-down" per column.
//
// Rules implemented (display mode, not awarding):
// - Columns = age/sex bands. Column order: Points, M17-21, F17-21, M22-26, F22-26, ..., M62+, F62+
// - Gaps are filled downward per column: scanning from 100 -> 0, if a cell is missing/-1,
//   inherit the most recent higher-point (above) published threshold.
// - Formatting:
//   * MDL/HRP: integers (no units)
//   * SDC/PLK/2MR: mm:ss (two-digit minutes/seconds), or '---' if missing
//
// Public API:
// - List<String> loadEventColumn({required AftEvent event, required AftSex effectiveSex, required String ageBand})
//     -> 101 rows for P=100..0 inclusive, strings formatted as above (or '---')
// - List<String> listAgeBands() -> canonical band labels for UI dropdown
//
// Notes:
// - Effective sex is applied by the caller (Combat On forces male).
// - We do not mutate app-wide profile/settings; selection is local to Standards screen.

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/logic/scoring_service.dart' show AftEvent;
import 'package:aft_firebase_app/features/standards/state/standards_selection.dart';
import 'package:aft_firebase_app/features/aft/utils/formatters.dart';

import 'package:aft_firebase_app/features/aft/logic/data/mdl_csv.dart' as mdl;
import 'package:aft_firebase_app/features/aft/logic/data/hrp_csv.dart' as hrp;
import 'package:aft_firebase_app/features/aft/logic/data/sdc_csv.dart' as sdc;
import 'package:aft_firebase_app/features/aft/logic/data/plk_csv.dart' as plk;
import 'package:aft_firebase_app/features/aft/logic/data/run2mi_csv.dart' as run2mi;

List<String> listAgeBands() => List<String>.from(kAftAgeBands);

// Utility: robust band label comparison (normalize hyphen/en dash)
String _normBand(String s) => s.replaceAll('–', '-').trim();

int _bandIndexFromLabel(String band) {
  final target = _normBand(band);
  for (var i = 0; i < kAftAgeBands.length; i++) {
    if (_normBand(kAftAgeBands[i]) == target) return i;
  }
  // Fallback to first band if unknown
  return 0;
}

bool _isTimeEvent(AftEvent e) {
  return e == AftEvent.sdc || e == AftEvent.plank || e == AftEvent.run2mi;
}

String _csvForEvent(AftEvent e) {
  switch (e) {
    case AftEvent.mdl:
      return mdl.mdlCsv;
    case AftEvent.pushUps:
      return hrp.hrpCsv;
    case AftEvent.sdc:
      return sdc.sdcCsv;
    case AftEvent.plank:
      return plk.plkCsv;
    case AftEvent.run2mi:
      return run2mi.run2miCsv;
  }
}

// Parse CSV-like matrix into map<int points, List<String> rowParts>
Map<int, List<String>> _parseCsvToRows(String csv) {
  final rows = <int, List<String>>{};
  final lines = csv.split(RegExp(r'\r?\n'));
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;
    final parts = line.split(',').map((s) => s.trim()).toList();
    if (parts.isEmpty) continue;
    final p = int.tryParse(parts[0]);
    if (p == null) continue;
    rows[p] = parts;
  }
  return rows;
}

// Extract cell string for sex/band index from a row or return null if missing/-1/out of range.
String? _cellFor(List<String> parts, AftSex sex, int bandIdx) {
  final mIdx = 1 + bandIdx * 2;
  final fIdx = mIdx + 1;
  final idx = (sex == AftSex.male) ? mIdx : fIdx;
  if (idx >= parts.length) return null;
  final token = parts[idx];
  if (token.isEmpty || token == '-1') return null;
  return token;
}

// For time events, format to mm:ss; for int events, strip to integer as string.
// Returns null for unparsable.
String? _normalizeToken(AftEvent event, String token) {
  if (_isTimeEvent(event)) {
    final d = parseMmSs(token);
    if (d == null) return null;
    final secs = d.inSeconds;
    // Reformat to mm:ss using formatMmSs helper over seconds domain
    return formatMmSs(Duration(seconds: secs));
  } else {
    // Numeric integer only
    final v = int.tryParse(token);
    if (v == null) return null;
    return '$v';
  }
}

// Core loader: one column of 101 values for P=100..0
List<String> loadEventColumn({
  required AftEvent event,
  required AftSex effectiveSex,
  required String ageBand,
}) {
  final csv = _csvForEvent(event);
  final rows = _parseCsvToRows(csv);
  final bandIdx = _bandIndexFromLabel(ageBand);

  final out = List<String>.filled(101, '---', growable: false);
  String? lastSeen; // last valid higher-point value

  for (int p = 100; p >= 0; p--) {
    final parts = rows[p];
    String? value;
    if (parts != null) {
      final cell = _cellFor(parts, effectiveSex, bandIdx);
      if (cell != null) {
        value = _normalizeToken(event, cell);
      }
    }
    if (value != null) {
      lastSeen = value;
      out[100 - p] = value;
    } else {
      // fill-down: inherit last seen (higher-point) value if present
      out[100 - p] = lastSeen ?? '---';
    }
  }

  return out;
}

// Convenience builder for the whole table row set.
// Returns a list of maps with keys: pts, mdl, hrp, sdc, plk, run2mi
List<Map<String, String>> buildStandardsRows({
  required AftSex effectiveSex,
  required String ageBand,
}) {
  final mdlCol = loadEventColumn(event: AftEvent.mdl, effectiveSex: effectiveSex, ageBand: ageBand);
  final hrpCol = loadEventColumn(event: AftEvent.pushUps, effectiveSex: effectiveSex, ageBand: ageBand);
  final sdcCol = loadEventColumn(event: AftEvent.sdc, effectiveSex: effectiveSex, ageBand: ageBand);
  final plkCol = loadEventColumn(event: AftEvent.plank, effectiveSex: effectiveSex, ageBand: ageBand);
  final runCol = loadEventColumn(event: AftEvent.run2mi, effectiveSex: effectiveSex, ageBand: ageBand);

  final rows = <Map<String, String>>[];
  for (int i = 0; i <= 100; i++) {
    final p = 100 - i;
    rows.add({
      'pts': '$p',
      'mdl': mdlCol[i],
      'hrp': hrpCol[i],
      'sdc': sdcCol[i],
      'plk': plkCol[i],
      'run2mi': runCol[i],
    });
  }
  return rows;
}
