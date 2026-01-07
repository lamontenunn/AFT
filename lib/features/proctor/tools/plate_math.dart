import 'package:flutter/foundation.dart';
import 'dart:collection';

@immutable
class PlateMathResult {
  final int targetTotalLbs;
  final int barLbs;
  final List<int> availablePlatesLbs;
  final bool isExact;
  final List<int> platesPerSide;
  final int remainderPerSideLbs;

  const PlateMathResult({
    required this.targetTotalLbs,
    required this.barLbs,
    required this.availablePlatesLbs,
    required this.isExact,
    required this.platesPerSide,
    required this.remainderPerSideLbs,
  });

  int get totalFromPlates {
    final perSide = platesPerSide.fold<int>(0, (a, b) => a + b);
    return barLbs + (perSide * 2);
  }
}

/// Formats a per-side plate list as "45 lb x2 + 25 lb + 10 lb x2".
String formatPlatesPerSide(List<int> plates) {
  if (plates.isEmpty) return 'None';
  final counts = <int, int>{};
  final order = <int>[];
  for (final p in plates) {
    if (!counts.containsKey(p)) order.add(p);
    counts[p] = (counts[p] ?? 0) + 1;
  }
  final parts = <String>[];
  for (final p in order) {
    final count = counts[p] ?? 0;
    final suffix = count > 1 ? ' x$count' : '';
    parts.add('$p lb$suffix');
  }
  return parts.join(' + ');
}

/// Plate math helper.
///
/// Assumptions for this app:
/// - symmetric loading
/// - only uses available plate sizes
/// - finds an exact combination if possible (prefers fewest plates)
PlateMathResult plateMath({
  required int targetTotalLbs,
  int barLbs = 60,
  List<int> availablePlatesLbs = const [45, 35, 25, 15, 10],
}) {
  if (targetTotalLbs < barLbs) {
    return PlateMathResult(
      targetTotalLbs: targetTotalLbs,
      barLbs: barLbs,
      availablePlatesLbs: availablePlatesLbs,
      isExact: false,
      platesPerSide: const [],
      remainderPerSideLbs: 0,
    );
  }

  final load = targetTotalLbs - barLbs;
  final perSide = load ~/ 2;
  final odd = load.isOdd;

  final sizes = [...availablePlatesLbs]..sort((a, b) => b.compareTo(a));

  // If the overall load isn't divisible by 2, we can never be exact.
  if (odd) {
    final greedy = _bestEffortGreedy(perSide, sizes);
    return PlateMathResult(
      targetTotalLbs: targetTotalLbs,
      barLbs: barLbs,
      availablePlatesLbs: sizes,
      isExact: false,
      platesPerSide: greedy.plates,
      remainderPerSideLbs: greedy.remainder,
    );
  }

  final exact = _fewestPlatesExact(perSide, sizes);
  if (exact != null) {
    return PlateMathResult(
      targetTotalLbs: targetTotalLbs,
      barLbs: barLbs,
      availablePlatesLbs: sizes,
      isExact: true,
      platesPerSide: exact,
      remainderPerSideLbs: 0,
    );
  }

  // No exact combo: return best-effort greedy + remainder.
  final greedy = _bestEffortGreedy(perSide, sizes);
  return PlateMathResult(
    targetTotalLbs: targetTotalLbs,
    barLbs: barLbs,
    availablePlatesLbs: sizes,
    isExact: false,
    platesPerSide: greedy.plates,
    remainderPerSideLbs: greedy.remainder,
  );
}

/// Returns up to [maxCombos] exact plate combinations per side.
///
/// Combinations are ordered by:
/// 1) fewest plates
/// 2) prefer larger plates (more "intuitive")
///
/// This enables UI to cycle among multiple valid exact configurations.
List<List<int>> plateMathExactCombos({
  required int targetTotalLbs,
  int barLbs = 60,
  List<int> availablePlatesLbs = const [45, 35, 25, 15, 10],
  int maxCombos = 8,
}) {
  if (targetTotalLbs < barLbs) return const [];
  final load = targetTotalLbs - barLbs;
  if (load.isOdd) return const [];
  final perSide = load ~/ 2;

  final sizes = [...availablePlatesLbs]..sort((a, b) => b.compareTo(a));

  // Find the minimum number of plates needed for an exact match.
  final minCount = _minPlateCountExact(perSide, sizes);
  if (minCount == null) return const [];

  // Enumerate only combos with minCount (fewest plates). This is a good
  // "intuitive cap" because it avoids generating a huge number of solutions.
  final out = <List<int>>[];
  void dfs({
    required int startIdx,
    required int remaining,
    required int slotsLeft,
    required List<int> cur,
  }) {
    if (out.length >= maxCombos) return;
    if (slotsLeft == 0) {
      if (remaining == 0) out.add(List<int>.from(cur));
      return;
    }

    // Prune: even if we use the smallest plate for all remaining slots,
    // can we still hit remaining? Likewise for the largest plate allowed.
    final smallest = sizes.last;
    final largestAllowed = sizes[startIdx];
    final minPossible = smallest * slotsLeft;
    final maxPossible = largestAllowed * slotsLeft;
    if (remaining < minPossible || remaining > maxPossible) return;

    for (int i = startIdx; i < sizes.length; i++) {
      final p = sizes[i];
      if (p > remaining) continue;
      cur.add(p);
      dfs(
        startIdx: i,
        remaining: remaining - p,
        slotsLeft: slotsLeft - 1,
        cur: cur,
      );
      cur.removeLast();
      if (out.length >= maxCombos) return;
    }
  }

  dfs(startIdx: 0, remaining: perSide, slotsLeft: minCount, cur: <int>[]);
  return out;
}

class _GreedyResult {
  final List<int> plates;
  final int remainder;
  const _GreedyResult(this.plates, this.remainder);
}

_GreedyResult _bestEffortGreedy(int perSideTarget, List<int> sizesDesc) {
  int remaining = perSideTarget;
  final plates = <int>[];
  for (final p in sizesDesc) {
    while (remaining >= p) {
      plates.add(p);
      remaining -= p;
    }
  }
  return _GreedyResult(plates, remaining);
}

/// Finds an exact per-side plate combination that sums to [perSideTarget].
///
/// Returns the combination using the *fewest plates*.
/// Tie-breaker: prefer larger plates (based on [sizesDesc] order).
List<int>? _fewestPlatesExact(int perSideTarget, List<int> sizesDesc) {
  // BFS over sums guarantees the first time we reach a sum, it's with
  // the fewest plates.
  final queue = <int>[0];
  final visited = <int>{0};

  // For backtracking: sum -> (prevSum, plateUsed)
  final prevSum = <int, int>{};
  final prevPlate = <int, int>{};

  while (queue.isNotEmpty) {
    final cur = queue.removeAt(0);
    for (final p in sizesDesc) {
      final next = cur + p;
      if (next > perSideTarget) continue;
      if (visited.contains(next)) continue;
      visited.add(next);
      prevSum[next] = cur;
      prevPlate[next] = p;
      if (next == perSideTarget) {
        // reconstruct
        final out = <int>[];
        int s = next;
        while (s != 0) {
          out.add(prevPlate[s]!);
          s = prevSum[s]!;
        }
        // Reconstructed is already in the order we added plates, which
        // favors larger plates because we iterate sizesDesc.
        return out;
      }
      queue.add(next);
    }
  }
  return null;
}

int? _minPlateCountExact(int perSideTarget, List<int> sizesDesc) {
  // Classic shortest path / coin change (fewest coins) with unlimited plates.
  // All edges have weight 1, so BFS-like relaxation is fine.
  const inf = 1 << 30;
  final dist = List<int>.filled(perSideTarget + 1, inf);
  dist[0] = 0;

  final q = Queue<int>()..add(0);
  while (q.isNotEmpty) {
    final cur = q.removeFirst();
    final curD = dist[cur];
    for (final p in sizesDesc) {
      final next = cur + p;
      if (next > perSideTarget) continue;
      if (curD + 1 < dist[next]) {
        dist[next] = curD + 1;
        q.add(next);
      }
    }
  }

  final d = dist[perSideTarget];
  return d >= inf ? null : d;
}
