// Standards selection state (local to Standards screen)
// - sex: Male | Female
// - combat: Off | On (forces effectiveSex = male)
// - ageBand: one of the fixed AFT bands "17-21", "22-26", ..., "62+"
// Initializes from aftProfileProvider but changes are local to this screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/aft/state/aft_profile.dart';
import 'package:aft_firebase_app/features/aft/state/providers.dart';

@immutable
class StandardsSelection {
  final AftSex sex;
  final bool combat;
  final String ageBand;

  const StandardsSelection({
    required this.sex,
    required this.combat,
    required this.ageBand,
  });

  AftSex get effectiveSex => combat ? AftSex.male : sex;

  StandardsSelection copyWith({
    AftSex? sex,
    bool? combat,
    String? ageBand,
  }) {
    return StandardsSelection(
      sex: sex ?? this.sex,
      combat: combat ?? this.combat,
      ageBand: ageBand ?? this.ageBand,
    );
  }
}

// Fixed AFT age bands corresponding to the CSV columns order.
const List<String> kAftAgeBands = <String>[
  '17-21',
  '22-26',
  '27-31',
  '32-36',
  '37-41',
  '42-46',
  '47-51',
  '52-56',
  '57-61',
  '62+',
];

int bandIndexForAge(int age) {
  if (age <= 21) return 0;
  if (age <= 26) return 1;
  if (age <= 31) return 2;
  if (age <= 36) return 3;
  if (age <= 41) return 4;
  if (age <= 46) return 5;
  if (age <= 51) return 6;
  if (age <= 56) return 7;
  if (age <= 61) return 8;
  return 9;
}

class StandardsSelectionNotifier extends Notifier<StandardsSelection> {
  @override
  StandardsSelection build() {
    // Initialize from current profile, but keep changes local.
    final profile = ref.read(aftProfileProvider);
    final idx = bandIndexForAge(profile.age);
    return StandardsSelection(
      sex: profile.sex,
      combat: false,
      ageBand: kAftAgeBands[idx],
    );
  }

  void setSex(AftSex sex) {
    state = state.copyWith(sex: sex);
  }

  void setCombat(bool on) {
    // Combat standards force male scoring tables.
    // Keep the user's selected sex as-is (UI should not flip M/F).
    state = state.copyWith(combat: on);
  }

  void setAgeBand(String band) {
    state = state.copyWith(ageBand: band);
  }
}

final standardsSelectionProvider =
    NotifierProvider<StandardsSelectionNotifier, StandardsSelection>(() {
  return StandardsSelectionNotifier();
});
