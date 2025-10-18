/// MDL scoring table with per-age and per-sex columns and a fill-down rule.
/// Columns (source CSV) are organized as alternating Male/Female columns for each age group:
/// Points, M17–21, F17–21, M22–26, F22–26, ..., M62+, F62+
///
/// Fill rule (applied per age/sex column independently, top-down from 100→0):
/// - If the requirement at points=P is -1 or missing, replace it with the next LOWER
///   point’s requirement that is not -1 (search P-1, P-2, …).
/// - If you reach 0 with no requirement found, set it to the minimum published requirement
///   found anywhere in that column (or 0 if none).
///
/// Implementation details:
/// - We build a dense 2D array for each sex for all points 100..0 for each age column (10 ages).
/// - The fill search looks through the original raw rows (points that were provided) only,
///   per spec (inherit from the next LOWER point with a published requirement).
/// - Scoring scans from 100 down to 0 and returns the first (highest) point threshold met.
library mdl_table;

import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';

const int _numAges = 10; // 17–21, 22–26, 27–31, 32–36, 37–41, 42–46, 47–51, 52–56, 57–61, 62+

/// Default raw male table (single 10-column set used as fallback if CSV not loaded).
const Map<int, List<int>> _defaultRawMale = {
  100: [220, 230, 240, 230, 220, 210, 200, 190, 170, 170],
  99:  [-1,  -1, 230, 220, 210,  -1,  -1,  -1, 160, 160],
  98:  [210, 220, 220,  -1,  -1, 200, 190, 180,  -1,  -1],
  97:  [200, 210,  -1, 210, 200,  -1,  -1,  -1,  -1,  -1],
  96:  [ -1,  -1, 210,  -1,  -1, 190, 180,  -1,  -1,  -1],
  95:  [ -1, 200, 200, 200, 190,  -1,  -1, 170,  -1,  -1],
  94:  [190,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  93:  [ -1, 190,  -1, 190,  -1, 180, 170,  -1,  -1,  -1],
  92:  [ -1,  -1, 190,  -1, 180,  -1,  -1,  -1,  -1,  -1],
  91:  [180,  -1,  -1,  -1,  -1,  -1,  -1, 160,  -1,  -1],
  90:  [ -1,  -1,  -1, 180,  -1, 170,  -1,  -1, 150, 150],
  89:  [ -1, 180, 180,  -1, 170,  -1, 160,  -1,  -1,  -1],
  88:  [170,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  87:  [ -1,  -1,  -1, 170,  -1,  -1,  -1,  -1,  -1,  -1],
  86:  [ -1, 170, 170,  -1,  -1, 160,  -1,  -1,  -1,  -1],
  85:  [ -1,  -1,  -1,  -1, 160,  -1,  -1, 150,  -1,  -1],
  84:  [160,  -1,  -1,  -1,  -1,  -1, 150,  -1,  -1,  -1],
  83:  [ -1,  -1,  -1, 160,  -1,  -1,  -1,  -1,  -1,  -1],
  82:  [ -1, 160, 160,  -1,  -1, 150,  -1,  -1,  -1,  -1],
  81:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  80:  [150,  -1,  -1,  -1, 150,  -1,  -1,  -1, 140, 140],
  79:  [ -1,  -1,  -1, 150,  -1,  -1, 140, 140,  -1,  -1],
  78:  [ -1, 150, 150,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  77:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  76:  [ -1,  -1,  -1,  -1,  -1, 140,  -1,  -1,  -1,  -1],
  75:  [140,  -1,  -1,  -1, 140,  -1,  -1,  -1,  -1,  -1],
  74:  [ -1,  -1,  -1, 140,  -1,  -1,  -1,  -1,  -1,  -1],
  73:  [ -1, 140, 140,  -1,  -1,  -1, 130,  -1,  -1,  -1],
  72:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1, 130,  -1, 130],
  71:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1, 130,  -1],
  70:  [ -1,  -1,  -1,  -1,  -1, 130,  -1,  -1,  -1,  -1],
  69:  [ -1,  -1,  -1,  -1, 130,  -1,  -1,  -1,  -1,  -1],
  68:  [130,  -1,  -1, 130,  -1,  -1,  -1,  -1,  -1,  -1],
  67:  [ -1, 130, 130,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  66:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  65:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  64:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  63:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  62:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  61:  [ -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1,  -1],
  60:  [120, 120, 120, 120, 120, 120, 120, 120, 120, 120],
  50:  [110, 110, 110, 110, 110, 110, 110, 110, 110, 110],
  40:  [100, 100, 100, 100, 100, 100, 100, 100, 100, 100],
  30:  [ 90,  90,  90,  90,  90,  90,  90,  90,  90,  90],
  20:  [ 80,  80,  80,  80,  80,  80,  80,  80,  80,  80],
  10:  [ 70,  70,  70,  70,  70,  70,  70,  70,  70,  70],
  0:   [ 60,  60,  60,  60,  60,  60,  60,  60,  60,  60],
};

/// Mutable in-memory tables seeded from defaults; can be overridden by CSV (20 columns).
Map<int, List<int>> _rawMale = Map.of(_defaultRawMale);
Map<int, List<int>> _rawFemale = Map.of(_defaultRawMale);

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

  // Apply fill rule per column for all points 100..0:
  // If value at P is -1, look for next LOWER provided point with a published requirement.
  // If none by 0, use minPublished for that column.
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
      dense[idx][c] = replacement ?? minPublished[c];
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
    if (lbs >= req) {
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

  _rawMale = male.isEmpty ? Map.of(_defaultRawMale) : male;
  _rawFemale = female.isEmpty ? Map.of(_defaultRawMale) : female;

  // Invalidate dense caches so they rebuild on next lookup.
  _denseMale = null;
  _denseFemale = null;
}
