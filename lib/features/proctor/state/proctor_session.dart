import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';

@immutable
class ProctorParticipant {
  final String id;
  final String? name;
  final int age;
  final AftSex sex;

  const ProctorParticipant({
    required this.id,
    this.name,
    required this.age,
    required this.sex,
  });

  ProctorParticipant copyWith({
    String? id,
    Object? name = _unset,
    int? age,
    AftSex? sex,
  }) {
    return ProctorParticipant(
      id: id ?? this.id,
      name: identical(name, _unset) ? this.name : name as String?,
      age: age ?? this.age,
      sex: sex ?? this.sex,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'sex': sex == AftSex.male ? 'male' : 'female',
      };

  static ProctorParticipant? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'] as String;
      final name = json['name'] as String?;
      final age = (json['age'] as num).toInt();
      final sexStr = json['sex'] as String;
      final sex = sexStr == 'female' ? AftSex.female : AftSex.male;
      return ProctorParticipant(id: id, name: name, age: age, sex: sex);
    } catch (_) {
      return null;
    }
  }
}

const Object _unset = Object();

@immutable
class ProctorSessionState {
  final List<ProctorParticipant> roster;
  final String? selectedId;

  const ProctorSessionState({
    required this.roster,
    required this.selectedId,
  });

  factory ProctorSessionState.initial() => const ProctorSessionState(
        roster: <ProctorParticipant>[],
        selectedId: null,
      );

  ProctorSessionState copyWith({
    List<ProctorParticipant>? roster,
    Object? selectedId = _unset,
  }) {
    return ProctorSessionState(
      roster: roster ?? this.roster,
      selectedId: identical(selectedId, _unset)
          ? this.selectedId
          : selectedId as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'roster': roster.map((p) => p.toJson()).toList(growable: false),
        'selectedId': selectedId,
      };

  String toJsonString() => jsonEncode(toJson());

  static ProctorSessionState fromJsonString(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final rosterRaw = (map['roster'] as List?) ?? const [];
      final roster = <ProctorParticipant>[];
      for (final item in rosterRaw) {
        if (item is Map<String, dynamic>) {
          final p = ProctorParticipant.fromJson(item);
          if (p != null) roster.add(p);
        }
      }
      final selectedId = map['selectedId'] as String?;
      return ProctorSessionState(roster: roster, selectedId: selectedId);
    } catch (_) {
      return ProctorSessionState.initial();
    }
  }
}
