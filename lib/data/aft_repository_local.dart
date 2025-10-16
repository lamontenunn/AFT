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
