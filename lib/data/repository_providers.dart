import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/data/aft_repository_local.dart';
import 'package:aft_firebase_app/data/aft_repository_firestore.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';

/// Bind the repository interface to local + Firestore implementations.
final aftRepositoryProvider = Provider<AftRepository>((ref) {
  final local = LocalAftRepository();
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return local;
  final user = ref.watch(authUserProvider);
  if (user == null) return DisabledAftRepository();
  final isGuest = user.isAnonymous;
  return HybridAftRepository(
    local: local,
    remote: FirestoreAftRepository(),
    isGuest: isGuest,
  );
});

class HybridAftRepository implements AftRepository {
  HybridAftRepository({
    required this.local,
    required this.remote,
    required this.isGuest,
  });

  final AftRepository local;
  final AftRepository remote;
  final bool isGuest;

  AftRepository _repoFor(String userId) {
    return isGuest ? local : remote;
  }

  @override
  Future<void> saveScoreSet({
    required String userId,
    required ScoreSet set,
  }) {
    return _repoFor(userId).saveScoreSet(userId: userId, set: set);
  }

  @override
  Future<void> updateScoreSet({
    required String userId,
    required ScoreSet set,
  }) {
    return _repoFor(userId).updateScoreSet(userId: userId, set: set);
  }

  @override
  Future<void> deleteScoreSet({
    required String userId,
    required String id,
  }) {
    return _repoFor(userId).deleteScoreSet(userId: userId, id: id);
  }

  @override
  Future<void> clearScoreSets({
    required String userId,
  }) {
    return _repoFor(userId).clearScoreSets(userId: userId);
  }

  @override
  Future<List<ScoreSet>> listScoreSets({
    required String userId,
  }) {
    return _repoFor(userId).listScoreSets(userId: userId);
  }
}

/// No-op repository used when signed out to prevent cross-account leakage.
class DisabledAftRepository implements AftRepository {
  @override
  Future<void> saveScoreSet({required String userId, required ScoreSet set}) async {}

  @override
  Future<void> updateScoreSet({required String userId, required ScoreSet set}) async {}

  @override
  Future<void> deleteScoreSet({required String userId, required String id}) async {}

  @override
  Future<void> clearScoreSets({required String userId}) async {}

  @override
  Future<List<ScoreSet>> listScoreSets({required String userId}) async => <ScoreSet>[];
}
