import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/data/aft_repository_firestore.dart';

abstract class GuestMigrationService {
  Future<void> maybeMigrateGuestTo(String uid);
  Future<void> trackGuestUser(String uid);
}

class DefaultGuestMigrationService implements GuestMigrationService {
  const DefaultGuestMigrationService();

  @override
  Future<void> maybeMigrateGuestTo(String uid) {
    return GuestMigration.maybeMigrateGuestTo(uid);
  }

  @override
  Future<void> trackGuestUser(String uid) {
    return GuestMigration.trackGuestUser(uid);
  }
}

final guestMigrationProvider = Provider<GuestMigrationService>((ref) {
  return const DefaultGuestMigrationService();
});

class GuestMigration {
  // Prevent overlapping migrations from merging guest data twice.
  static final Map<String, Future<void>> _inFlight = {};

  /// Keys:
  /// - Guest bucket (legacy signed-out): scoreSets:guest
  /// - Guest bucket (anonymous): scoreSets:guest:{anonUid}
  /// - Legacy signed-in bucket (local): scoreSets:{uid}
  static String guestKey() => 'scoreSets:guest';
  static String guestKeyForUid(String uid) => 'scoreSets:guest:$uid';
  static String guestOwnerKey() => 'scoreSets:guestOwnerUid';
  static String lastAnonUidKey() => 'scoreSets:lastAnonUid';
  static String userKey(String uid) => 'scoreSets:$uid';
  static String migrationPendingKey(String uid) =>
      'scoreSets:migrationPending:$uid';
  static String migrationMarkerKey(String uid) =>
      'scoreSets:migrationMarker:$uid';
  static String migrationExpectedKey(String uid) =>
      'scoreSets:migrationExpected:$uid';
  static final Random _markerRng = Random();

  /// Migrates guest bucket into Firestore for the target uid if guest data exists.
  /// After migration, the guest bucket is cleared.
  static Future<void> maybeMigrateGuestTo(
    String uid, {
    FirebaseFirestore? firestore,
  }) {
    final existing = _inFlight[uid];
    if (existing != null) return existing;
    final future = _runMigration(uid, firestore: firestore);
    _inFlight[uid] = future;
    return future.whenComplete(() => _inFlight.remove(uid));
  }

  static Future<void> trackGuestUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastAnonUidKey(), uid);
  }

  static Future<void> _runMigration(
    String uid, {
    FirebaseFirestore? firestore,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final guest = prefs.getString(guestKey());
    final existingUser = prefs.getString(userKey(uid));
    if ((guest == null || guest.isEmpty) &&
        (existingUser == null || existingUser.isEmpty)) {
      final anonUid = prefs.getString(lastAnonUidKey());
      if (anonUid == null || anonUid.isEmpty) return;
      final anonGuest = prefs.getString(guestKeyForUid(anonUid));
      if (anonGuest == null || anonGuest.isEmpty) return;
    }

    var guestSets =
        guest == null || guest.isEmpty ? <ScoreSet>[] : decodeScoreSets(guest);
    final userSets = existingUser == null || existingUser.isEmpty
        ? <ScoreSet>[]
        : decodeScoreSets(existingUser);
    final anonUid = prefs.getString(lastAnonUidKey());
    final anonGuest = anonUid == null ? null : prefs.getString(guestKeyForUid(anonUid));
    final anonSets = anonGuest == null || anonGuest.isEmpty
        ? <ScoreSet>[]
        : decodeScoreSets(anonGuest);
    final owner = prefs.getString(guestOwnerKey());
    if (guestSets.isNotEmpty && owner != null && owner != uid) {
      // Prevent cross-account migration of guest data on this device.
      guestSets = <ScoreSet>[];
    } else if (guestSets.isNotEmpty && owner == null) {
      await prefs.setString(guestOwnerKey(), uid);
    }
    final allSets = <String, ScoreSet>{};
    for (final set in guestSets) {
      allSets[set.id] = set;
    }
    for (final set in anonSets) {
      allSets[set.id] = set;
    }
    for (final set in userSets) {
      allSets[set.id] = set;
    }
    if (allSets.isEmpty) {
      if (guestSets.isEmpty) {
        await prefs.remove(guestKey());
      }
      if (anonSets.isEmpty && anonUid != null) {
        await prefs.remove(guestKeyForUid(anonUid));
        await prefs.remove(lastAnonUidKey());
      }
      if (userSets.isEmpty) {
        await prefs.remove(userKey(uid));
      }
      await _clearPending(prefs, uid);
      return;
    }

    final markerId = _newMarkerId();
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final userDoc = db.collection('users').doc(uid);
      final collection = userDoc.collection('scoreSets');

      WriteBatch batch = db.batch();
      var count = 0;
      for (final set in allSets.values) {
        final doc = collection.doc(set.id);
        batch.set(doc, scoreSetToFirestore(set), SetOptions(merge: true));
        count += 1;
        if (count >= 400) {
          await batch.commit();
          batch = db.batch();
          count = 0;
        }
      }
      batch.set(
        userDoc,
        {
          'migration': {
            'markerId': markerId,
            'expectedCount': allSets.length,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        },
        SetOptions(merge: true),
      );
      await batch.commit();

      final verified = await _verifyMarker(uid, markerId, firestore: db);
      if (!verified) {
        await _markPending(prefs, uid, markerId, allSets.length);
        return;
      }

      if (guestSets.isNotEmpty) {
        await prefs.remove(guestKey());
        await prefs.remove(guestOwnerKey());
      }
      if (anonSets.isNotEmpty && anonUid != null) {
        await prefs.remove(guestKeyForUid(anonUid));
        await prefs.remove(lastAnonUidKey());
      }
      await prefs.remove(userKey(uid));
      await _clearPending(prefs, uid);
    } catch (_) {
      await _markPending(prefs, uid, markerId, allSets.length);
      // Keep guest data so migration can retry later.
    }
  }

  static String _newMarkerId() {
    final micros = DateTime.now().microsecondsSinceEpoch;
    final nonce = _markerRng.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return '$micros-$nonce';
  }

  static Future<bool> _verifyMarker(
    String uid,
    String markerId, {
    FirebaseFirestore? firestore,
  }) async {
    try {
      final db = firestore ?? FirebaseFirestore.instance;
      final doc = await db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final data = doc.data();
      if (data == null) return false;
      final migration = data['migration'];
      if (migration is Map) {
        return migration['markerId'] == markerId;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> _markPending(
    SharedPreferences prefs,
    String uid,
    String markerId,
    int expectedCount,
  ) async {
    await prefs.setBool(migrationPendingKey(uid), true);
    await prefs.setString(migrationMarkerKey(uid), markerId);
    await prefs.setInt(migrationExpectedKey(uid), expectedCount);
  }

  static Future<void> _clearPending(
    SharedPreferences prefs,
    String uid,
  ) async {
    await prefs.remove(migrationPendingKey(uid));
    await prefs.remove(migrationMarkerKey(uid));
    await prefs.remove(migrationExpectedKey(uid));
  }
}
