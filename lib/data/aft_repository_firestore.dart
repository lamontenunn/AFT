import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';

Map<String, dynamic> scoreSetToFirestore(ScoreSet set) {
  final json = set.toJson();
  json['createdAt'] = Timestamp.fromDate(set.createdAt);

  final profile = Map<String, dynamic>.from(json['profile'] as Map);
  final testDate = profile['testDate'];
  if (testDate is String) {
    final parsed = DateTime.tryParse(testDate);
    if (parsed != null) {
      profile['testDate'] = Timestamp.fromDate(parsed);
    }
  }
  json['profile'] = profile;
  return json;
}

ScoreSet scoreSetFromFirestore(String id, Map<String, dynamic> data) {
  final json = Map<String, dynamic>.from(data);
  json['id'] = (json['id'] as String?) ?? id;

  final createdAt = _coerceDate(json['createdAt']);
  final fallbackCreatedAt = createdAt ??
      _createdAtFromId(json['id'] as String?) ??
      DateTime.now();
  json['createdAt'] = fallbackCreatedAt.toIso8601String();

  final profile = Map<String, dynamic>.from(json['profile'] as Map);
  final testDate = _coerceDate(profile['testDate']);
  profile['testDate'] = testDate?.toIso8601String();
  json['profile'] = profile;

  final inputs = Map<String, dynamic>.from(json['inputs'] as Map);
  json['inputs'] = inputs;

  final computedRaw = json['computed'];
  if (computedRaw != null) {
    json['computed'] = Map<String, dynamic>.from(computedRaw as Map);
  }

  return ScoreSet.fromJson(json);
}

DateTime? _coerceDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

DateTime? _createdAtFromId(String? id) {
  if (id == null || id.isEmpty) return null;
  final parts = id.split('-');
  if (parts.isNotEmpty) {
    final micros = int.tryParse(parts.first);
    if (micros != null) {
      return DateTime.fromMicrosecondsSinceEpoch(micros);
    }
  }
  return DateTime.tryParse(id);
}

class FirestoreAftRepository implements AftRepository {
  FirestoreAftRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collectionFor(String userId) {
    return _firestore.collection('users').doc(userId).collection('scoreSets');
  }

  @override
  Future<void> saveScoreSet({
    required String userId,
    required ScoreSet set,
  }) async {
    final doc = _collectionFor(userId).doc(set.id);
    await doc.set(scoreSetToFirestore(set), SetOptions(merge: true));
  }

  @override
  Future<void> updateScoreSet({
    required String userId,
    required ScoreSet set,
  }) async {
    final doc = _collectionFor(userId).doc(set.id);
    await doc.set(scoreSetToFirestore(set), SetOptions(merge: true));
  }

  @override
  Future<void> deleteScoreSet({
    required String userId,
    required String id,
  }) async {
    await _collectionFor(userId).doc(id).delete();
  }

  @override
  Future<void> clearScoreSets({
    required String userId,
  }) async {
    final snapshot = await _collectionFor(userId).get();
    if (snapshot.docs.isEmpty) return;

    WriteBatch batch = _firestore.batch();
    var count = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
      count += 1;
      if (count >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        count = 0;
      }
    }
    if (count > 0) {
      await batch.commit();
    }
  }

  @override
  Future<List<ScoreSet>> listScoreSets({
    required String userId,
  }) async {
    final snapshot = await _collectionFor(userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => scoreSetFromFirestore(doc.id, doc.data()))
        .toList();
  }
}
