/// Rank abbreviation -> SVG asset path map.
///
/// Notes:
/// - Keys are abbreviations ("SGT", "SSG", "CPT", "PV1", etc.)
/// - Values are SVG asset paths under `assets/icons/ranks/`.
/// - PV1 has no insignia in this app, so it maps to null.
/// - Unknown abbrev should be treated as unsupported (don’t guess).
const Map<String, String?> rankAssetByAbbrev = <String, String?>{
  // Enlisted
  'PV1': null,
  'PV2': 'assets/icons/ranks/army_e2_pv2.svg',
  'PFC': 'assets/icons/ranks/army_e3_pfc.svg',
  'SPC': 'assets/icons/ranks/army_e4_spc.svg',
  'CPL': 'assets/icons/ranks/army_e4_cpl.svg',
  'SGT': 'assets/icons/ranks/army_e5_sgt.svg',
  'SSG': 'assets/icons/ranks/army_e6_ssg.svg',
  'SFC': 'assets/icons/ranks/army_e7_sfc.svg',
  'MSG': 'assets/icons/ranks/army_e8_msg.svg',
  '1SG': 'assets/icons/ranks/army_e8_1sg.svg',
  'SGM': 'assets/icons/ranks/army_e9_sgm.svg',
  'CSM': 'assets/icons/ranks/army_e9_csm.svg',
  'SMA': 'assets/icons/ranks/army_e9_sma.svg',

  // Warrant Officer
  'WO1': 'assets/icons/ranks/army_w1_wo1.svg',
  'CW2': 'assets/icons/ranks/army_w2_cw2.svg',
  'CW3': 'assets/icons/ranks/army_w3_cw3.svg',
  'CW4': 'assets/icons/ranks/army_w4_cw4.svg',
  'CW5': 'assets/icons/ranks/army_w5_cw5.svg',

  // Officer
  '2LT': 'assets/icons/ranks/army_o1_2lt.svg',
  '1LT': 'assets/icons/ranks/army_o2_1lt.svg',
  'CPT': 'assets/icons/ranks/army_o3_cpt.svg',
  'MAJ': 'assets/icons/ranks/army_o4_maj.svg',
  'LTC': 'assets/icons/ranks/army_o5_ltc.svg',
  'COL': 'assets/icons/ranks/army_o6_col.svg',
  'BG': 'assets/icons/ranks/army_o7_bg.svg',
  'MG': 'assets/icons/ranks/army_o8_mg.svg',
  'LTG': 'assets/icons/ranks/army_o9_ltg.svg',
  'GEN': 'assets/icons/ranks/army_o10_gen.svg',
};

/// Pay grade (e.g. "O-1", "W-2", "E-5") -> rank abbreviation (e.g. "2LT", "CW2", "SGT").
///
/// Used as a fallback when the user hasn’t explicitly set `rankAbbrev`.
const Map<String, String?> rankAbbrevByPayGrade = <String, String?>{
  // Enlisted
  'E-1': 'PV1',
  'E-2': 'PV2',
  'E-3': 'PFC',
  'E-4': 'SPC',
  'E-5': 'SGT',
  'E-6': 'SSG',
  'E-7': 'SFC',
  'E-8': 'MSG',
  'E-9': 'SGM',

  // Warrant
  'W-1': 'WO1',
  'W-2': 'CW2',
  'W-3': 'CW3',
  'W-4': 'CW4',
  'W-5': 'CW5',

  // Officer
  'O-1': '2LT',
  'O-2': '1LT',
  'O-3': 'CPT',
  'O-4': 'MAJ',
  'O-5': 'LTC',
  'O-6': 'COL',
  'O-7': 'BG',
  'O-8': 'MG',
  'O-9': 'LTG',
  'O-10': 'GEN',

  // Prior-enlisted officer (use officer insignia)
  'O-1E': '2LT',
  'O-2E': '1LT',
  'O-3E': 'CPT',
};
