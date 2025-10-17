import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/aft_inputs.dart';
import 'package:aft_firebase_app/features/aft/state/aft_standard.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart' show AftComputed;

@immutable
class ScoreSet {
  final AftProfile profile;
  final AftInputs inputs;
  final AftComputed? computed;
  final DateTime createdAt;

  const ScoreSet({
    required this.profile,
    required this.inputs,
    required this.createdAt,
    this.computed,
  });

  Map<String, dynamic> toJson() => {
        'profile': {
          'age': profile.age,
          'sex': profile.sex.name,
          'standard': profile.standard.name,
          'testDate': profile.testDate?.toIso8601String(),
        },
        'inputs': {
          'mdlLbs': inputs.mdlLbs,
          'pushUps': inputs.pushUps,
          'sdc': inputs.sdc?.inSeconds,
          'plank': inputs.plank?.inSeconds,
          'run2mi': inputs.run2mi?.inSeconds,
        },
        'computed': computed == null
            ? null
            : {
                'mdlScore': computed!.mdlScore,
                'pushUpsScore': computed!.pushUpsScore,
                'sdcScore': computed!.sdcScore,
                'plankScore': computed!.plankScore,
                'run2miScore': computed!.run2miScore,
                'total': computed!.total,
              },
        'createdAt': createdAt.toIso8601String(),
      };

  static ScoreSet fromJson(Map<String, dynamic> json) {
    final prof = json['profile'] as Map<String, dynamic>;
    final inp = json['inputs'] as Map<String, dynamic>;
    final comp = json['computed'] as Map<String, dynamic>?;

    final sex = AftSex.values.firstWhere(
      (e) => e.name == (prof['sex'] as String),
      orElse: () => AftSex.male,
    );
    final stdStr = prof['standard'] as String;
    final std = AftStandard.values.firstWhere(
      (e) => e.name == stdStr,
      orElse: () => AftStandard.general,
    );

    final profile = AftProfile(
      age: prof['age'] as int,
      sex: sex,
      standard: std,
      testDate: (prof['testDate'] as String?) == null
          ? null
          : DateTime.parse(prof['testDate'] as String),
    );

    final inputs = AftInputs(
      mdlLbs: inp['mdlLbs'] as int?,
      pushUps: inp['pushUps'] as int?,
      sdc: (inp['sdc'] as int?) == null
          ? null
          : Duration(seconds: inp['sdc'] as int),
      plank: (inp['plank'] as int?) == null
          ? null
          : Duration(seconds: inp['plank'] as int),
      run2mi: (inp['run2mi'] as int?) == null
          ? null
          : Duration(seconds: inp['run2mi'] as int),
    );

    final computed = comp == null
        ? null
        : AftComputed(
            mdlScore: comp['mdlScore'] as int?,
            pushUpsScore: comp['pushUpsScore'] as int?,
            sdcScore: comp['sdcScore'] as int?,
            plankScore: comp['plankScore'] as int?,
            run2miScore: comp['run2miScore'] as int?,
            total: comp['total'] as int?,
          );

    return ScoreSet(
      profile: profile,
      inputs: inputs,
      computed: computed,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Persistence boundary for AFT sets.
abstract class AftRepository {
  Future<void> saveScoreSet({
    required String userId,
    required ScoreSet set,
  });

  Future<List<ScoreSet>> listScoreSets({
    required String userId,
  });
}

// Helpers for encoding lists
String encodeScoreSets(List<ScoreSet> sets) =>
    jsonEncode(sets.map((e) => e.toJson()).toList());

List<ScoreSet> decodeScoreSets(String source) {
  final list = (jsonDecode(source) as List).cast<dynamic>();
  return list
      .map((e) => ScoreSet.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
}
