/**
 * MDL (3RM Deadlift) scoring table with per-age and per-sex columns and a densifier.
 * Columns (source CSV) are organized as alternating Male/Female columns for each age group:
 * Points, M17–21, F17–21, M22–26, F22–26, ..., M62+, F62+
 *
 * Higher-is-better domain fill rule (applied per age/sex column independently, top-down 100→0):
 * - If the requirement at points=P is -1 or missing, inherit the next HIGHER point’s published
 *   requirement (search P+1, P+2, … up to 100).
 * - If nothing is found by P=100, use the per-column minimum published requirement (or 0 if none).
 *
 * Implementation details:
 * - We build a dense 2D array for each sex over all points 100..0 for each age column (10 ages).
 * - Scoring scans from 100 down to 0 and returns the first (highest) point threshold met.
 */
library mdl_table;

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';

const int _numAges = 10; // 17–21, 22–26, 27–31, 32–36, 37–41, 42–46, 47–51, 52–56, 57–61, 62+


//// Mutable in-memory tables populated by CSV (20 columns).
Map<int, List<int>> _rawMale = <int, List<int>>{};
Map<int, List<int>> _rawFemale = <int, List<int>>{};

/// Dense tables for each sex: [P=100..0][ageIdx=0..9] -> lbs requirement (no -1 remain).
List<List<int>>? _denseMale;
List<List<int>>? _denseFemale;

/// Build dense table for all points 100..0 for a given raw sparse map.
List<List<int>> _buildDense(Map<int, List<int>> raw) {
  // Compute per-column minimum published requirement (ignore -1).
  final minPublished = List<int>.filled(_numAges, -1);
  for (final row in raw.values) {
    for (var c = 0; c < _numAges; c++) {
      final v = row[c];
      if (v >= 0) {
        if (minPublished[c] == -1 || v < minPublished[c]) {
          minPublished[c] = v;
        }
      }
    }
  }
  for (var c = 0; c < _numAges; c++) {
    if (minPublished[c] < 0) minPublished[c] = 0;
  }

  // Initialize dense with -1.
  final dense = List.generate(101, (_) => List<int>.filled(_numAges, -1));

  // Copy provided rows into dense at their point indices.
  for (var p = 100; p >= 0; p--) {
    final rawRow = raw[p];
    if (rawRow != null) {
      for (var c = 0; c < _numAges; c++) {
        dense[100 - p][c] = rawRow[c];
      }
    }
  }

  // Fill-down per column 100→0 (higher-is-better semantics):
  // If value at P is -1, inherit the next HIGHER provided point (search P+1..100).
  // If none found, leave as -1 (missing) so awarding will skip it.
  for (var c = 0; c < _numAges; c++) {
    for (var p = 100; p >= 0; p--) {
      final idx = 100 - p;
      if (dense[idx][c] != -1) continue;

      int? replacement;
      for (var p2 = p + 1; p2 <= 100; p2++) {
        final higher = raw[p2];
        if (higher == null) continue;
        final v = higher[c];
        if (v != -1) {
          replacement = v;
          break;
        }
      }
      dense[idx][c] = replacement ?? -1;
    }
  }

  return dense;
}

void _ensureBuilt() {
  _denseMale ??= _buildDense(_rawMale);
  _denseFemale ??= _buildDense(_rawFemale);
}

int _ageToIndex(int age) {
  if (age <= 21) return 0;
  if (age <= 26) return 1;
  if (age <= 31) return 2;
  if (age <= 36) return 3;
  if (age <= 41) return 4;
  if (age <= 46) return 5;
  if (age <= 51) return 6;
  if (age <= 56) return 7;
  if (age <= 61) return 8;
  return 9; // 62+
}

/// Compute MDL points (0–100) for given sex, age and lifted weight (lbs).
/// Returns the highest (topmost) point P where lbs >= requirement[P][ageIdx].
/// If none match, returns 0.
int mdlPointsForSex(AftSex sex, int age, int lbs) {
  _ensureBuilt();
  final dense = (sex == AftSex.female) ? _denseFemale! : _denseMale!;
  final ageIdx = _ageToIndex(age);

  // Scan from 100 down; award the first (highest) point whose requirement is met.
  // This favors the top of any plateau created by fill-down (common scoring convention).
  for (var p = 100; p >= 0; p--) {
    final req = dense[100 - p][ageIdx];
    if (req >= 0 && lbs >= req) {
      return p;
    }
  }
  return 0;
}

/// Backward-compat wrapper (assumes male).
int mdlPointsFor(int age, int lbs) => mdlPointsForSex(AftSex.male, age, lbs);

/// CSV loader (20 columns): Points, M17–21, F17–21, ..., M62+, F62+.
/// Values may be -1 and will be filled per-column by the densifier.
/// Replaces in-memory male/female raw maps and invalidates dense caches.
void loadMdlCsv(String csv) {
  final male = <int, List<int>>{};
  final female = <int, List<int>>{};
  final lines = csv.split(RegExp(r'\r?\n'));
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) continue;

    final parts = line.split(',').map((s) => s.trim()).toList();
    if (parts.length < 1 + (_numAges * 2)) continue;

    final p = int.tryParse(parts[0]);
    if (p == null) continue;

    final maleRow = List<int>.filled(_numAges, -1);
    final femaleRow = List<int>.filled(_numAges, -1);
    for (var ageIdx = 0; ageIdx < _numAges; ageIdx++) {
      final mIdx = 1 + ageIdx * 2;
      final fIdx = mIdx + 1;
      final mVal = int.tryParse(parts[mIdx]) ?? -1;
      final fVal = int.tryParse(parts[fIdx]) ?? -1;
      maleRow[ageIdx] = mVal;
      femaleRow[ageIdx] = fVal;
    }
    male[p] = maleRow;
    female[p] = femaleRow;
  }

  _rawMale = male;
  _rawFemale = female;

  // Invalidate dense caches so they rebuild on next lookup.
  _denseMale = null;
  _denseFemale = null;
}
