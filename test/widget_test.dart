import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aft_firebase_app/app.dart';
import 'package:aft_firebase_app/theme/army_colors.dart';
import 'package:flutter_riverpod/legacy.dart';

void main() {
  testWidgets('App renders with dark Army theme', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();

    // Basic structure exists
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);

    // Verify dark theme and Army brand primary color (gold)
    final scaffoldElement = tester.element(find.byType(Scaffold));
    final theme = Theme.of(scaffoldElement);
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, ArmyColors.gold);
  });
}
