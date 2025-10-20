import 'package:shared_preferences/shared_preferences.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';

/// Keys:
/// - Guest bucket: scoreSets:guest
/// - Per-user bucket: scoreSets:{uid}
/// - Migration flag per target uid: guestMigrated:{uid}
class GuestMigration {
  static String guestKey() => 'scoreSets:guest';
  static String userKey(String uid) => 'scoreSets:$uid';
  static String migratedFlag(String uid) => 'guestMigrated:$uid';

  /// Migrates guest bucket into the target uid bucket if:
  /// - Guest bucket has data
  /// - Not already migrated for this uid (flag)
  ///
  /// After migration:
  /// - Guest bucket cleared
  /// - Flag guestMigrated:{uid} set = true
  static Future<void> maybeMigrateGuestTo(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final flagKey = migratedFlag(uid);
    final already = prefs.getBool(flagKey) ?? false;
    if (already) return;

    final guest = prefs.getString(guestKey());
    if (guest == null || guest.isEmpty) {
      // Nothing to migrate; set flag to avoid repeated checks
      await prefs.setBool(flagKey, true);
      return;
    }

    final guestSets = decodeScoreSets(guest);
    if (guestSets.isEmpty) {
      await prefs.remove(guestKey());
      await prefs.setBool(flagKey, true);
      return;
    }

    final targetKey = userKey(uid);
    final existing = prefs.getString(targetKey);
    final existingSets = existing == null ? <ScoreSet>[] : decodeScoreSets(existing);

    // Merge and sort by createdAt descending
    final merged = <ScoreSet>[...guestSets, ...existingSets]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    await prefs.setString(targetKey, encodeScoreSets(merged));
    await prefs.remove(guestKey());
    await prefs.setBool(flagKey, true);
  }
}
