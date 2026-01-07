import 'package:aft_firebase_app/features/home/home_screen.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Calculator greeting row shows only when lastName and rankAbbrev are set and supported',
      (tester) async {
    final container = _containerWithProfile(
      DefaultProfileSettings.defaults.copyWith(
        lastName: 'Nunn',
        rankAbbrev: 'SGT',
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: FeatureHomeScreen()),
        ),
      ),
    );

    expect(find.text('Hello, SGT Nunn'), findsOneWidget);
  });

  testWidgets('Calculator greeting row hides for truly unknown rank abbrev',
      (tester) async {
    final container = _containerWithProfile(
      DefaultProfileSettings.defaults.copyWith(
        lastName: 'Nunn',
        rankAbbrev: 'ZZZ', // truly unknown
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: FeatureHomeScreen()),
        ),
      ),
    );

    expect(find.textContaining('Hello,'), findsNothing);
  });

  testWidgets(
      'Calculator greeting row uses payGrade as fallback for rank (O-1 -> 2LT)',
      (tester) async {
    final container = _containerWithProfile(
      DefaultProfileSettings.defaults.copyWith(
        lastName: 'Nunn',
        payGrade: 'O-1',
        // rankAbbrev intentionally unset
      ),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: FeatureHomeScreen()),
        ),
      ),
    );

    expect(find.text('Hello, 2LT Nunn'), findsOneWidget);
  });
}

ProviderContainer _containerWithProfile(DefaultProfileSettings profile) {
  return ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) {
        return SettingsController(
          ref,
          initialState: SettingsState.defaults.copyWith(
            defaultProfile: profile,
          ),
          loadOnInit: false,
          listenToAuthChanges: false,
        );
      }),
    ],
  );
}
