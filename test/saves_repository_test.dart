import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/data/aft_repository_local.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';

void main() {
  const userId = 'u1';
  String keyFor(String uid) => 'scoreSets:$uid';

  ScoreSet makeSet({
    required DateTime createdAt,
    int age = 25,
    AftSex sex = AftSex.male,
    AftStandard standard = AftStandard.general,
    AftInputs inputs = const AftInputs(),
  }) {
    return ScoreSet(
      profile: AftProfile(age: age, sex: sex, standard: standard),
      inputs: inputs,
      createdAt: createdAt,
      computed: null,
    );
  }

  setUp(() async {
    // Ensure a clean preferences store before each test
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('updateScoreSet replaces in-place and preserves id/createdAt', () async {
    final repo = LocalAftRepository();

    final created = DateTime(2025, 1, 1, 12, 0);
    final original = makeSet(createdAt: created, inputs: const AftInputs(mdlLbs: 200));
    final initialJson = encodeScoreSets([original]);

    // Seed storage with one set
    SharedPreferences.setMockInitialValues({keyFor(userId): initialJson});

    // Verify seed
    final before = await repo.listScoreSets(userId: userId);
    expect(before.length, 1);
    expect(before.first.id, original.id);
    expect(before.first.createdAt, original.createdAt);
    expect(before.first.inputs.mdlLbs, 200);

    // Update: change inputs, keep same id/createdAt
    final updated = ScoreSet(
      id: original.id,
      profile: original.profile.copyWith(age: 30),
      inputs: const AftInputs(mdlLbs: 225, pushUps: 40),
      createdAt: original.createdAt,
      computed: null,
    );

    await repo.updateScoreSet(userId: userId, set: updated);

    final after = await repo.listScoreSets(userId: userId);
    expect(after.length, 1);
    final s0 = after.first;
    expect(s0.id, original.id);
    expect(s0.createdAt, original.createdAt);
    expect(s0.profile.age, 30);
    expect(s0.inputs.mdlLbs, 225);
    expect(s0.inputs.pushUps, 40);
  });

  test('deleteScoreSet removes only the matching id', () async {
    final repo = LocalAftRepository();

    final a = makeSet(createdAt: DateTime(2025, 1, 1, 12, 0), inputs: const AftInputs(mdlLbs: 185));
    final b = makeSet(createdAt: DateTime(2025, 1, 2, 8, 30), inputs: const AftInputs(mdlLbs: 205));
    SharedPreferences.setMockInitialValues({
      keyFor(userId): encodeScoreSets([a, b]),
    });

    var sets = await repo.listScoreSets(userId: userId);
    expect(sets.length, 2);

    await repo.deleteScoreSet(userId: userId, id: a.id);

    sets = await repo.listScoreSets(userId: userId);
    expect(sets.length, 1);
    expect(sets.first.id, b.id);
  });

  test('clearScoreSets removes all sets for the user', () async {
    final repo = LocalAftRepository();

    final a = makeSet(createdAt: DateTime(2025, 1, 1, 12, 0));
    final b = makeSet(createdAt: DateTime(2025, 1, 2, 8, 30));
    SharedPreferences.setMockInitialValues({
      keyFor(userId): encodeScoreSets([a, b]),
    });

    var sets = await repo.listScoreSets(userId: userId);
    expect(sets.length, 2);

    await repo.clearScoreSets(userId: userId);

    sets = await repo.listScoreSets(userId: userId);
    expect(sets, isEmpty);
  });
}
