/// HRP (Hand-Release Push-ups) scoring tables with per-age and per-sex columns
/// and a fill-down rule, analogous to MDL implementation.
///
/// Source CSV format (20 columns):
/// Points, M17–21, F17–21, M22–26, F22–26, ..., M62+, F62+
///
/// Fill rule (applied per age/sex column independently, top-down 100→0):
/// - If requirement at P is -1 or missing, inherit the next LOWER P's published requirement.
/// - If no requirement found by P=0, use the per-column minimum published requirement (or 0).
///
/// Awarding rule:
/// - Scan from 100 down; return the first (highest) point whose requirement is met
///   (top-of-plateau awarding). For HRP, input reps must be >= requirement.
///
/// This file exposes:
/// - void loadHrpCsv(String csv)
/// - void preloadHrpCsvOnce(String csv) in hrp_csv.dart (separate)
/// - int hrpPointsForSex(AftSex sex, int age, int reps)
library hrp_table;

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';

const int _numAges = 10; // 17–21, 22–26, 27–31, 32–36, 37–41, 42–46, 47–51, 52–56, 57–61, 62+

/// Raw tables (sparse: only provided points will exist). Populated via CSV loader.
Map<int, List<int>> _rawMale = <int, List<int>>{};
Map<int, List<int>> _rawFemale = <int, List<int>>{};

/// Dense tables for each sex: [P=100..0][ageIdx=0..9] -> reps requirement (no -1 remain).
List<List<int>>? _denseMale;
List<List<int>>? _denseFemale;

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

/// Build dense [101 x 10] table from a sparse raw map using the fill-down rule.
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

  // Fill-down per column 100→0:
  // If value at P is -1, inherit the next LOWER provided point (search P-1..0).
  // If none found, leave as -1 (missing) so awarding will skip it.
  for (var c = 0; c < _numAges; c++) {
    for (var p = 100; p >= 0; p--) {
      final idx = 100 - p;
      if (dense[idx][c] != -1) continue;

      int? replacement;
      for (var p2 = p - 1; p2 >= 0; p2--) {
        final lower = raw[p2];
        if (lower == null) continue;
        final v = lower[c];
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

/// CSV loader (20 columns): Points, M17–21, F17–21, ..., M62+, F62+.
/// Values may be -1 and will be filled per-column by the densifier.
/// Replaces in-memory male/female raw maps and invalidates dense caches.
void loadHrpCsv(String csv) {
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

/// Compute HRP points (0–100) for given sex, age and push-ups reps.
/// Returns the highest (topmost) point P where reps >= requirement[P][ageIdx].
int hrpPointsForSex(AftSex sex, int age, int reps) {
  _ensureBuilt();
  final dense = (sex == AftSex.female) ? _denseFemale! : _denseMale!;
  final ageIdx = _ageToIndex(age);

  for (var p = 100; p >= 0; p--) {
    final req = dense[100 - p][ageIdx];
    if (req >= 0 && reps >= req) {
      return p;
    }
  }
  return 0;
}
