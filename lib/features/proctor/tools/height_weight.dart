import 'package:aft_firebase_app/features/aft/state/aft_profile.dart'
    show AftSex;

/// AR 600-9 height/weight screening (max allowable screening weight).
///
/// Data source: `lib/features/aft/logic/data/h-w.txt`.
///
/// Rounding rules (per user requirements):
/// - Height: round to nearest inch (<0.5 down, >=0.5 up)
/// - Weight: round to nearest lb (<0.5 down, >=0.5 up)

enum HwAgeBracket { a17_20, a21_27, a28_39, a40Plus }

HwAgeBracket ageBracketFor(int ageYears) {
  if (ageYears <= 20) return HwAgeBracket.a17_20;
  if (ageYears <= 27) return HwAgeBracket.a21_27;
  if (ageYears <= 39) return HwAgeBracket.a28_39;
  return HwAgeBracket.a40Plus;
}

int roundHeightInches(double inches) {
  // Round half up.
  final floor = inches.floor();
  final frac = inches - floor;
  return (frac >= 0.5 ? floor + 1 : floor).clamp(0, 200);
}

int roundWeightLbs(double lbs) {
  // Round half up.
  final floor = lbs.floor();
  final frac = lbs - floor;
  return (frac >= 0.5 ? floor + 1 : floor).clamp(0, 2000);
}

class HwScreeningRow {
  final int heightIn;
  final int minWeightLbs;
  final int max17_20;
  final int max21_27;
  final int max28_39;
  final int max40Plus;

  const HwScreeningRow({
    required this.heightIn,
    required this.minWeightLbs,
    required this.max17_20,
    required this.max21_27,
    required this.max28_39,
    required this.max40Plus,
  });

  int maxForBracket(HwAgeBracket b) {
    return switch (b) {
      HwAgeBracket.a17_20 => max17_20,
      HwAgeBracket.a21_27 => max21_27,
      HwAgeBracket.a28_39 => max28_39,
      HwAgeBracket.a40Plus => max40Plus,
    };
  }
}

class HwScreeningResult {
  final AftSex sex;
  final int ageYears;
  final HwAgeBracket bracket;
  final int roundedHeightIn;
  final int roundedWeightLbs;
  final HwScreeningRow row;

  const HwScreeningResult({
    required this.sex,
    required this.ageYears,
    required this.bracket,
    required this.roundedHeightIn,
    required this.roundedWeightLbs,
    required this.row,
  });

  int get maxAllowedLbs => row.maxForBracket(bracket);
  int get minAllowedLbs => row.minWeightLbs;

  bool get isWithinMin => roundedWeightLbs >= minAllowedLbs;
  bool get isWithinMax => roundedWeightLbs <= maxAllowedLbs;
  bool get isPass => isWithinMin && isWithinMax;
}

class HwTable {
  final Map<int, HwScreeningRow> male;
  final Map<int, HwScreeningRow> female;
  const HwTable({required this.male, required this.female});

  HwScreeningRow? rowFor({required AftSex sex, required int heightIn}) {
    return (sex == AftSex.male ? male : female)[heightIn];
  }
}

/// Table values copied from `h-w.txt`.
const HwTable hwTable = HwTable(
  male: {
    60: HwScreeningRow(
        heightIn: 60,
        minWeightLbs: 97,
        max17_20: 132,
        max21_27: 136,
        max28_39: 139,
        max40Plus: 141),
    61: HwScreeningRow(
        heightIn: 61,
        minWeightLbs: 100,
        max17_20: 136,
        max21_27: 140,
        max28_39: 144,
        max40Plus: 146),
    62: HwScreeningRow(
        heightIn: 62,
        minWeightLbs: 104,
        max17_20: 141,
        max21_27: 144,
        max28_39: 148,
        max40Plus: 150),
    63: HwScreeningRow(
        heightIn: 63,
        minWeightLbs: 107,
        max17_20: 145,
        max21_27: 149,
        max28_39: 153,
        max40Plus: 155),
    64: HwScreeningRow(
        heightIn: 64,
        minWeightLbs: 110,
        max17_20: 150,
        max21_27: 154,
        max28_39: 158,
        max40Plus: 160),
    65: HwScreeningRow(
        heightIn: 65,
        minWeightLbs: 114,
        max17_20: 155,
        max21_27: 159,
        max28_39: 163,
        max40Plus: 165),
    66: HwScreeningRow(
        heightIn: 66,
        minWeightLbs: 117,
        max17_20: 160,
        max21_27: 163,
        max28_39: 168,
        max40Plus: 170),
    67: HwScreeningRow(
        heightIn: 67,
        minWeightLbs: 121,
        max17_20: 165,
        max21_27: 169,
        max28_39: 174,
        max40Plus: 176),
    68: HwScreeningRow(
        heightIn: 68,
        minWeightLbs: 125,
        max17_20: 170,
        max21_27: 174,
        max28_39: 179,
        max40Plus: 181),
    69: HwScreeningRow(
        heightIn: 69,
        minWeightLbs: 128,
        max17_20: 175,
        max21_27: 179,
        max28_39: 184,
        max40Plus: 186),
    70: HwScreeningRow(
        heightIn: 70,
        minWeightLbs: 132,
        max17_20: 180,
        max21_27: 185,
        max28_39: 189,
        max40Plus: 192),
    71: HwScreeningRow(
        heightIn: 71,
        minWeightLbs: 136,
        max17_20: 185,
        max21_27: 189,
        max28_39: 194,
        max40Plus: 197),
    72: HwScreeningRow(
        heightIn: 72,
        minWeightLbs: 140,
        max17_20: 190,
        max21_27: 195,
        max28_39: 200,
        max40Plus: 203),
    73: HwScreeningRow(
        heightIn: 73,
        minWeightLbs: 144,
        max17_20: 195,
        max21_27: 200,
        max28_39: 205,
        max40Plus: 208),
    74: HwScreeningRow(
        heightIn: 74,
        minWeightLbs: 148,
        max17_20: 201,
        max21_27: 206,
        max28_39: 211,
        max40Plus: 214),
    75: HwScreeningRow(
        heightIn: 75,
        minWeightLbs: 152,
        max17_20: 206,
        max21_27: 212,
        max28_39: 217,
        max40Plus: 220),
    76: HwScreeningRow(
        heightIn: 76,
        minWeightLbs: 156,
        max17_20: 212,
        max21_27: 217,
        max28_39: 223,
        max40Plus: 226),
    77: HwScreeningRow(
        heightIn: 77,
        minWeightLbs: 160,
        max17_20: 218,
        max21_27: 223,
        max28_39: 229,
        max40Plus: 232),
    78: HwScreeningRow(
        heightIn: 78,
        minWeightLbs: 164,
        max17_20: 223,
        max21_27: 229,
        max28_39: 235,
        max40Plus: 238),
    79: HwScreeningRow(
        heightIn: 79,
        minWeightLbs: 168,
        max17_20: 229,
        max21_27: 235,
        max28_39: 241,
        max40Plus: 244),
    80: HwScreeningRow(
        heightIn: 80,
        minWeightLbs: 173,
        max17_20: 234,
        max21_27: 240,
        max28_39: 247,
        max40Plus: 250),
  },
  female: {
    58: HwScreeningRow(
        heightIn: 58,
        minWeightLbs: 91,
        max17_20: 119,
        max21_27: 121,
        max28_39: 122,
        max40Plus: 124),
    59: HwScreeningRow(
        heightIn: 59,
        minWeightLbs: 94,
        max17_20: 124,
        max21_27: 125,
        max28_39: 126,
        max40Plus: 128),
    60: HwScreeningRow(
        heightIn: 60,
        minWeightLbs: 97,
        max17_20: 128,
        max21_27: 129,
        max28_39: 131,
        max40Plus: 133),
    61: HwScreeningRow(
        heightIn: 61,
        minWeightLbs: 100,
        max17_20: 132,
        max21_27: 134,
        max28_39: 135,
        max40Plus: 137),
    62: HwScreeningRow(
        heightIn: 62,
        minWeightLbs: 104,
        max17_20: 136,
        max21_27: 138,
        max28_39: 140,
        max40Plus: 142),
    63: HwScreeningRow(
        heightIn: 63,
        minWeightLbs: 107,
        max17_20: 141,
        max21_27: 143,
        max28_39: 144,
        max40Plus: 146),
    64: HwScreeningRow(
        heightIn: 64,
        minWeightLbs: 110,
        max17_20: 145,
        max21_27: 147,
        max28_39: 149,
        max40Plus: 151),
    65: HwScreeningRow(
        heightIn: 65,
        minWeightLbs: 114,
        max17_20: 150,
        max21_27: 152,
        max28_39: 154,
        max40Plus: 156),
    66: HwScreeningRow(
        heightIn: 66,
        minWeightLbs: 117,
        max17_20: 155,
        max21_27: 156,
        max28_39: 158,
        max40Plus: 161),
    67: HwScreeningRow(
        heightIn: 67,
        minWeightLbs: 121,
        max17_20: 159,
        max21_27: 161,
        max28_39: 163,
        max40Plus: 166),
    68: HwScreeningRow(
        heightIn: 68,
        minWeightLbs: 125,
        max17_20: 164,
        max21_27: 166,
        max28_39: 168,
        max40Plus: 171),
    69: HwScreeningRow(
        heightIn: 69,
        minWeightLbs: 128,
        max17_20: 169,
        max21_27: 171,
        max28_39: 173,
        max40Plus: 176),
    70: HwScreeningRow(
        heightIn: 70,
        minWeightLbs: 132,
        max17_20: 174,
        max21_27: 176,
        max28_39: 178,
        max40Plus: 181),
    71: HwScreeningRow(
        heightIn: 71,
        minWeightLbs: 136,
        max17_20: 179,
        max21_27: 181,
        max28_39: 183,
        max40Plus: 186),
    72: HwScreeningRow(
        heightIn: 72,
        minWeightLbs: 140,
        max17_20: 184,
        max21_27: 186,
        max28_39: 188,
        max40Plus: 191),
    73: HwScreeningRow(
        heightIn: 73,
        minWeightLbs: 144,
        max17_20: 189,
        max21_27: 191,
        max28_39: 194,
        max40Plus: 197),
    74: HwScreeningRow(
        heightIn: 74,
        minWeightLbs: 148,
        max17_20: 194,
        max21_27: 197,
        max28_39: 199,
        max40Plus: 202),
    75: HwScreeningRow(
        heightIn: 75,
        minWeightLbs: 152,
        max17_20: 200,
        max21_27: 202,
        max28_39: 204,
        max40Plus: 208),
    76: HwScreeningRow(
        heightIn: 76,
        minWeightLbs: 156,
        max17_20: 205,
        max21_27: 207,
        max28_39: 210,
        max40Plus: 213),
    77: HwScreeningRow(
        heightIn: 77,
        minWeightLbs: 160,
        max17_20: 210,
        max21_27: 213,
        max28_39: 215,
        max40Plus: 219),
    78: HwScreeningRow(
        heightIn: 78,
        minWeightLbs: 164,
        max17_20: 216,
        max21_27: 218,
        max28_39: 221,
        max40Plus: 225),
    79: HwScreeningRow(
        heightIn: 79,
        minWeightLbs: 168,
        max17_20: 221,
        max21_27: 224,
        max28_39: 227,
        max40Plus: 230),
    80: HwScreeningRow(
        heightIn: 80,
        minWeightLbs: 173,
        max17_20: 227,
        max21_27: 230,
        max28_39: 233,
        max40Plus: 236),
  },
);

HwScreeningResult? evaluateHwScreening({
  required AftSex sex,
  required int ageYears,
  required double heightIn,
  required double weightLbs,
}) {
  final h = roundHeightInches(heightIn);
  final w = roundWeightLbs(weightLbs);
  final row = hwTable.rowFor(sex: sex, heightIn: h);
  if (row == null) return null;
  final bracket = ageBracketFor(ageYears);
  return HwScreeningResult(
    sex: sex,
    ageYears: ageYears,
    bracket: bracket,
    roundedHeightIn: h,
    roundedWeightLbs: w,
    row: row,
  );
}
