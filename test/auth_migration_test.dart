import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/data/aft_repository_local.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/auth/auth_side_effects.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/auth/sign_in_page.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes/fake_auth.dart';
import 'fakes/guest_migration_spy.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  ScoreSet _makeSet(DateTime createdAt) {
    return ScoreSet(
      profile: const AftProfile(
        age: 20,
        sex: AftSex.male,
        standard: AftStandard.general,
      ),
      inputs: const AftInputs(),
      createdAt: createdAt,
    );
  }

  test('Anonymous saves locally under scoreSets:guest:{anonUid}', () async {
    const userId = 'guest:anon1';
    final local = LocalAftRepository();
    await local.saveScoreSet(
        userId: userId, set: _makeSet(DateTime(2024, 1, 1)));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('scoreSets:$userId');
    expect(raw, isNotNull);
    final sets = decodeScoreSets(raw!);
    expect(sets, hasLength(1));
  });

  test('Auth transition triggers migration exactly once', () async {
    final controller = FakeAuthController();
    final spy = GuestMigrationSpy();
    final container = ProviderContainer(
      overrides: [
        firebaseAuthProvider.overrideWithValue(controller.auth),
        guestMigrationProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(controller.dispose);

    container.read(authSideEffectsProvider);

    final anon = buildMockUser(uid: 'anon1', isAnonymous: true);
    final user = buildMockUser(uid: 'userA', isAnonymous: false);

    controller.emit(anon);
    await Future<void>.delayed(Duration.zero);
    controller.emit(user);
    await Future<void>.delayed(Duration.zero);

    expect(spy.trackedUids, contains('anon1'));
    expect(spy.migratedUids.where((id) => id == 'userA'), hasLength(1));
  });

  testWidgets('Continue as Guest records anonymous uid', (tester) async {
    final auth = MockFirebaseAuth();
    final user = buildMockUser(uid: 'anon42', isAnonymous: true);
    final cred = buildMockCredential(user);
    when(() => auth.signInAnonymously()).thenAnswer((_) async => cred);

    final spy = GuestMigrationSpy();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          firebaseUserProvider.overrideWith((ref) => Stream<User?>.value(null)),
          guestMigrationProvider.overrideWithValue(spy),
        ],
        child: const MaterialApp(home: SignInPage()),
      ),
    );

    await tester.tap(find.text('Continue as Guest'));
    await tester.pump();

    expect(spy.trackedUids, ['anon42']);
  });

  test('GuestMigration moves anon sets to Firestore and clears local',
      () async {
    final firestore = FakeFirebaseFirestore();
    await GuestMigration.trackGuestUser('anon1');

    final local = LocalAftRepository();
    await local.saveScoreSet(
      userId: 'guest:anon1',
      set: _makeSet(DateTime(2024, 1, 1)),
    );

    await GuestMigration.maybeMigrateGuestTo('userA', firestore: firestore);

    final remote = await firestore
        .collection('users')
        .doc('userA')
        .collection('scoreSets')
        .get();
    expect(remote.docs, hasLength(1));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('scoreSets:guest:anon1'), isNull);
  });

  test('GuestMigration is idempotent on rerun', () async {
    final firestore = FakeFirebaseFirestore();
    await GuestMigration.trackGuestUser('anon1');

    final local = LocalAftRepository();
    await local.saveScoreSet(
      userId: 'guest:anon1',
      set: _makeSet(DateTime(2024, 1, 1)),
    );

    await GuestMigration.maybeMigrateGuestTo('userA', firestore: firestore);
    await GuestMigration.maybeMigrateGuestTo('userA', firestore: firestore);

    final remote = await firestore
        .collection('users')
        .doc('userA')
        .collection('scoreSets')
        .get();
    expect(remote.docs, hasLength(1));
  });
}
