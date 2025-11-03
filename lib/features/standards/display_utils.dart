// Display utilities for Standards screen: mapping columns and collapsing duplicate runs.
//
// - toColumnMap: convert a List<String> (index 0..100 corresponds to points 100..0)
//                into a Map<int, String> keyed by points (100..0).
// - squashRunsDescending: given a by-point map (100..0) after down-fill, blank out
//                repeated values after their first/highest occurrence. Returns
//                Map<int, String?> where null indicates a blank cell for display.

library standards_display_utils;

/// Convert a 101-length column list (index 0..100 = points 100..0)
/// into a by-point map keyed by points 100..0.
/// If the list is shorter, remaining points will be filled with '---'.
Map<int, String> toColumnMap(List<String> col) {
  final out = <int, String>{};
  for (var i = 0; i <= 100; i++) {
    final pts = 100 - i;
    final v = (i < col.length) ? col[i] : '---';
    out[pts] = v;
  }
  return out;
}

/// Given a column map of thresholds for points 100..0 (after down-fill),
/// produce a display map where repeated values are blanked after their
/// first/highest occurrence. `---` remains visible by default.
///
/// Input:  col[pts] -> String (e.g., "6", "01:30", or "---")
/// Output: disp[pts] -> String? (null => render an empty cell)
Map<int, String?> squashRunsDescending(
  Map<int, String> col, {
  bool alsoBlankDashes = false,
}) {
  String? lastShown;
  final out = <int, String?>{};
  for (int pts = 100; pts >= 0; pts--) {
    final v = col[pts] ?? '---';
    final isDash = v == '---';
    final isRepeat = (lastShown != null && v == lastShown);
    final shouldBlank = isRepeat && (!isDash || alsoBlankDashes);
    out[pts] = shouldBlank ? null : v;
    if (!shouldBlank) lastShown = v;
  }
  return out;
}
