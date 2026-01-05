import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aft_firebase_app/features/proctor/proctor_screen.dart';

void main() {
  testWidgets('Proctor page dismisses keyboard on drag', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // The proctor screen uses Riverpod providers in its build; for this regression
    // test we only assert the widget configuration of the top-level ListView.
    // (We don’t need to pump provider state to validate this behavior.)
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ProctorScreen()),
        ),
      ),
    );

    final listViewFinder = find.descendant(
      of: find.byType(ProctorScreen),
      matching: find.byType(ListView),
    );
    final listView = tester.widget<ListView>(listViewFinder.first);
    expect(
      listView.keyboardDismissBehavior,
      ScrollViewKeyboardDismissBehavior.onDrag,
    );
  });

  testWidgets('Body fat tool fields support tap-outside to dismiss',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ProctorScreen()),
        ),
      ),
    );

    // Tap the "Tools" segmented button.
    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    // Ensure we are on the Body Fat tool.
    await tester.tap(find.text('Body Fat'));
    await tester.pumpAndSettle();

    // We should have 3 input fields.
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.length, greaterThanOrEqualTo(3));

    // At least the last 3 fields are the body fat calculator inputs. Assert they
    // support tap-outside (added to fix keypad dismissal).
    final last3 = fields.toList().sublist(fields.length - 3);
    for (final f in last3) {
      expect(f.onTapOutside, isNotNull);
    }
  });
}
