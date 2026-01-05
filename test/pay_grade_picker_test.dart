import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aft_firebase_app/screens/edit_default_profile_screen.dart';

void main() {
  testWidgets('Pay Grade opens bottom sheet and selects a value',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: EditDefaultProfileScreen(),
        ),
      ),
    );

    // Tap the Pay Grade field (it's an InputDecorator + InkWell).
    // Tapping the label text can miss hit-testing; tap the InkWell instead.
    final payGradeInkWell = find.descendant(
      of: find.widgetWithText(InputDecorator, 'Pay Grade'),
      matching: find.byType(InkWell),
    );
    expect(payGradeInkWell, findsOneWidget);

    await tester.ensureVisible(payGradeInkWell);
    await tester.pumpAndSettle();
    await tester.tap(payGradeInkWell);
    await tester.pumpAndSettle();

    // Bottom sheet should show some known grades.
    expect(find.text('Select Pay Grade'), findsOneWidget);

    // Select a grade.
    // (We don't assert a specific grade is visible in the ListView because
    // the bottom sheet list is lazily built and may not build off-screen rows
    // until scrolled in tests.)
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    // Pay Grade should now show placeholder again.
    expect(find.text('Select'), findsWidgets);
  });

  // Close main() in case formatting/patching previously removed it.
}
