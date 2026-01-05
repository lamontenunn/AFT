import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aft_firebase_app/features/proctor/proctor_screen.dart';
import 'package:aft_firebase_app/features/proctor/tools/plate_math_chart_screen.dart';

void main() {
  testWidgets('Plate Math Full chart button opens chart screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ProctorScreen()),
        ),
      ),
    );

    // Proctor opens on Timing; switch to Tools.
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    // Plate Math is the default tool.
    expect(find.text('Plate Math'), findsWidgets);

    final fullChartFinder = find.text('Full chart');
    await tester.ensureVisible(fullChartFinder);
    await tester.pumpAndSettle();
    await tester.tap(fullChartFinder);
    await tester.pumpAndSettle();

    expect(find.byType(PlateMathChartScreen), findsOneWidget);
    expect(find.text('Plate Math Chart'), findsWidgets); // app bar
  });
}
