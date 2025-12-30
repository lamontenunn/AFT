import 'package:aft_firebase_app/features/home/home_screen.dart';
import 'package:aft_firebase_app/state/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Calculator greeting row shows only when lastName and rankAbbrev are set and supported',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) {
          // Stub controller with deterministic state.
          return _TestSettingsController(
            SettingsState.defaults.copyWith(
              defaultProfile: DefaultProfileSettings.defaults.copyWith(
                lastName: 'Nunn',
                rankAbbrev: 'SGT',
              ),
            ),
          );
        }),
      ],
    );

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
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) {
          return _TestSettingsController(
            SettingsState.defaults.copyWith(
              defaultProfile: DefaultProfileSettings.defaults.copyWith(
                lastName: 'Nunn',
                rankAbbrev: 'ZZZ', // truly unknown
              ),
            ),
          );
        }),
      ],
    );

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
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) {
          return _TestSettingsController(
            SettingsState.defaults.copyWith(
              defaultProfile: DefaultProfileSettings.defaults.copyWith(
                lastName: 'Nunn',
                payGrade: 'O-1',
                // rankAbbrev intentionally unset
              ),
            ),
          );
        }),
      ],
    );

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

class _TestSettingsController extends SettingsController {
  _TestSettingsController(SettingsState seed) : super(_FakeRef()) {
    state = seed;
  }

  @override
  Future<void> setDefaultProfile(DefaultProfileSettings profile) async {
    state = state.copyWith(defaultProfile: profile);
  }
}

// Minimal fake Ref so SettingsController constructor can run; we bypass _load.
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
