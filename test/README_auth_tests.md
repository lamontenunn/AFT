# Auth Test Suite

Run
- `flutter test test/auth_providers_test.dart`
- `flutter test test/auth_gate_widget_test.dart`
- `flutter test test/auth_migration_test.dart`
- `flutter test`

What failures mean
- `firebaseAuthProvider returns null` failing: Firebase init assumptions changed; update provider or test.
- `aftRepositoryProvider returns DisabledAftRepository` failing: signed-out persistence may be leaking data.
- `AuthGate shows SignInPage`/`spinner` failures: auth routing regressions.
- `Continue as Guest records anonymous uid` failing: trackGuestUser not wired after anonymous sign-in.
- `Auth transition triggers migration exactly once` failing: migration hook missing or firing repeatedly.
- `GuestMigration moves anon sets` failing: migration durability or Firestore write path regression.
