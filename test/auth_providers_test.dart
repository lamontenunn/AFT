import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth.dart';

void main() {
  test('firebaseAuthProvider returns null without Firebase init', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(firebaseAuthProvider), isNull);
  });

  test('aftRepositoryProvider returns DisabledAftRepository when signed out', () async {
    final auth = MockFirebaseAuth();
    final container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        authUserProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final repo = container.read(aftRepositoryProvider);
    expect(repo, isA<DisabledAftRepository>());

    final set = ScoreSet(
      profile: AftProfile(age: 20, sex: AftSex.male, standard: AftStandard.general),
      inputs: const AftInputs(),
      createdAt: DateTime(2024, 1, 1),
    );

    await repo.saveScoreSet(userId: 'signed-out', set: set);
    final list = await repo.listScoreSets(userId: 'signed-out');
    expect(list, isEmpty);
  });

  test('effectiveUserIdProvider returns guest:{uid} for anonymous user', () {
    final user = buildMockUser(uid: 'anon123', isAnonymous: true);
    final container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWithValue(user),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(effectiveUserIdProvider), 'guest:anon123');
  });

  test('effectiveUserIdProvider returns uid for signed-in user', () {
    final user = buildMockUser(uid: 'user456', isAnonymous: false);
    final container = ProviderContainer(
      overrides: [
        authUserProvider.overrideWithValue(user),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(effectiveUserIdProvider), 'user456');
  });

  test('authActionsProvider is null-safe when auth is null', () async {
    final container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    final actions = container.read(authActionsProvider);
    await expectLater(
      actions.signInAnonymously(),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      actions.signOut(),
      throwsA(isA<StateError>()),
    );
  });
}
