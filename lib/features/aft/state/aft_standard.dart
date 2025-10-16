/// Army Fitness Test standard domain.
enum AftStandard {
  general,
  combat,
}

extension AftStandardLabel on AftStandard {
  String get label {
    switch (this) {
      case AftStandard.general:
        return 'General';
      case AftStandard.combat:
        return 'Combat';
    }
  }
}
