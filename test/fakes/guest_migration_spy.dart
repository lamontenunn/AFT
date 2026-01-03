import 'package:aft_firebase_app/features/saves/guest_migration.dart';

class GuestMigrationSpy implements GuestMigrationService {
  final List<String> migratedUids = [];
  final List<String> trackedUids = [];

  @override
  Future<void> maybeMigrateGuestTo(String uid) async {
    migratedUids.add(uid);
  }

  @override
  Future<void> trackGuestUser(String uid) async {
    trackedUids.add(uid);
  }
}
