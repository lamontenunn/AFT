import 'package:shared_preferences/shared_preferences.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';

/// Local implementation backed by shared_preferences.
/// Stores score sets under key: "scoreSets:{userId}" as a JSON list.
class LocalAftRepository implements AftRepository {
  String _keyFor(String userId) => 'scoreSets:$userId';

  @override
  Future<void> saveScoreSet({
    required String userId,
    required ScoreSet set,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    final existing = prefs.getString(key);
    final list = existing == null ? <ScoreSet>[] : decodeScoreSets(existing);
    list.insert(0, set); // prepend newest
    await prefs.setString(key, encodeScoreSets(list));
  }

  @override
  Future<void> updateScoreSet({
    required String userId,
    required ScoreSet set,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    final existing = prefs.getString(key);
    final list = existing == null ? <ScoreSet>[] : decodeScoreSets(existing);

    final idx = list.indexWhere((e) => e.id == set.id);
    if (idx >= 0) {
      // Replace in place to preserve list ordering and createdAt
      list[idx] = set;
    } else {
      // Fallback: if not found, insert as newest
      list.insert(0, set);
    }
    await prefs.setString(key, encodeScoreSets(list));
  }

  @override
  Future<void> deleteScoreSet({
    required String userId,
    required String id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    final existing = prefs.getString(key);
    if (existing == null) return;
    final list = decodeScoreSets(existing);
    list.removeWhere((e) => e.id == id);
    await prefs.setString(key, encodeScoreSets(list));
  }

  @override
  Future<void> clearScoreSets({
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    // Remove the key entirely; listScoreSets will treat null as empty.
    await prefs.remove(key);
  }

  @override
  Future<List<ScoreSet>> listScoreSets({
    required String userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    final existing = prefs.getString(key);
    if (existing == null) return <ScoreSet>[];
    return decodeScoreSets(existing);
  }
}
