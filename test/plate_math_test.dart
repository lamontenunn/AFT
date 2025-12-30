import 'package:flutter_test/flutter_test.dart';

import 'package:aft_firebase_app/features/proctor/tools/plate_math.dart';

void main() {
  group('plateMath (60 lb bar, 45/35/25/15/10 plates)', () {
    test('Exact match example: 180 lb => 45+15 per side', () {
      final res = plateMath(targetTotalLbs: 180, barLbs: 60);
      expect(res.isExact, true);
      final sorted = [...res.platesPerSide]..sort();
      expect(sorted, [15, 45]);
      expect(res.remainderPerSideLbs, 0);
      expect(res.totalFromPlates, 180);
    });

    test('Non-exact when (target - bar) is odd', () {
      final res = plateMath(targetTotalLbs: 175, barLbs: 60);
      expect(res.isExact, false);
      // load=115 => perSide=57 => 45+10 remainder 2
      expect(res.platesPerSide, [45, 10]);
      expect(res.remainderPerSideLbs, 2);
      expect(res.totalFromPlates, 170);
    });

    test('Exact match example: 340 lb => 45+45+25+25 per side', () {
      final combos = plateMathExactCombos(targetTotalLbs: 340, barLbs: 60);
      expect(combos, isNotEmpty);

      // We should surface at least these two intuitive 4-plate combos:
      // 45+45+25+25 and 45+45+35+15 (order isn't important)
      final normalized = combos.map((c) => ([...c]..sort()).join(',')).toSet();
      expect(normalized.contains('25,25,45,45'), true);
      expect(normalized.contains('15,35,45,45'), true);

      // All returned combos should be exact
      for (final c in combos) {
        final perSide = c.fold<int>(0, (a, b) => a + b);
        expect(60 + perSide * 2, 340);
      }
    });

    test('Target below bar returns empty plates', () {
      final res = plateMath(targetTotalLbs: 50, barLbs: 60);
      expect(res.isExact, false);
      expect(res.platesPerSide, isEmpty);
      expect(res.totalFromPlates, 60);
    });
  });
}
