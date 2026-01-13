# Authentication (Current Implementation)

This document explains how authentication works in the current codebase.
It is intended for internal developers and AI agents who need to understand the control-flow, providers, and persistence behavior (guest buckets + migration).

> Scope: This describes what exists today. It is not a perfect auth architecture; it documents the current behavior so changes can be made safely.

---

## TL;DR

- Auth is backed by FirebaseAuth.
- The source of truth is FirebaseAuth.userChanges().
- Routing is gated by AuthGate across app routes:
  - user == null -> SignInPage
  - user != null -> app shell
- Auth side effects live in authSideEffectsProvider:
  - resets user-scoped providers on auth changes
  - tracks anonymous uid for migration
  - migrates guest data when a non-anonymous user signs in
- Sign-in methods: email/password, Google, Apple (iOS/macOS), and anonymous (guest).
- OAuth sign-ins (Google/Apple) attempt to link anonymous users to preserve uid; if the credential is already in use, the app falls back to sign-in.
- Saved data routing:
  - signed-out user -> no saved sets (DisabledAftRepository)
  - anonymous user -> local bucket scoreSets:guest:{anonUid}
  - signed-in (non-anonymous) user -> Firestore users/{uid}/scoreSets
  - legacy signed-out bucket scoreSets:guest is migration-only
- Default profile settings are stored locally per user scope and sync to Firestore for signed-in users.
- When a guest upgrades to an account, profile data is migrated from guest scope to uid scope.
- Guest migration merges legacy local buckets and clears them only after a verified server write.

---

## Key files

### UI / flow

- lib/features/auth/auth_gate.dart
- lib/features/auth/sign_in_page.dart

### Providers / state

- lib/features/auth/providers.dart
- lib/features/auth/auth_state.dart

### Auth side effects

- lib/features/auth/auth_side_effects.dart
- lib/app.dart (watches authSideEffectsProvider)

### Guest migration

- lib/features/saves/guest_migration.dart

### Settings / profile sync

- lib/state/settings_state.dart

### Firebase init

- lib/main.dart
- lib/firebase_options.dart

---

## High-level flow diagram

```text
main.dart
  └─ Firebase.initializeApp()
  └─ ProviderScope
       └─ App
            ├─ authSideEffectsProvider (listens to auth changes)
            └─ AppRouter -> AuthGate(child: route)
                 └─ firebaseUserProvider (userChanges)
                      ├─ null  -> SignInPage
                      └─ User  -> App shell
```

---

## Providers (what they do and why)

All auth-related providers live in lib/features/auth/providers.dart.

### firebaseAuthProvider

```dart
final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance;
});
```

Purpose:

- Exposes FirebaseAuth.instance.
- Returns null when Firebase is not initialized (notably in tests), which prevents accidental Firebase calls.

### firebaseUserProvider

```dart
final firebaseUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return Stream<User?>.value(null);
  return auth.userChanges();
});
```

Purpose:

- Wraps userChanges() as a Riverpod StreamProvider.
- Includes anon -> email/password link upgrades (authStateChanges does not always emit).
- If Firebase is not initialized, the app behaves as signed out.

### authUserProvider

```dart
final authUserProvider = Provider<User?>((ref) {
  final asyncUser = ref.watch(firebaseUserProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return asyncUser.maybeWhen(
    data: (user) => user,
    orElse: () => auth?.currentUser,
  );
});
```

Purpose:

- Provides a non-async User? with a currentUser fallback while the stream is loading.

### authStateProvider

Maps the User? into a simple immutable AuthState for UI consumption.

Notes:

- Uses authUserProvider to avoid flicker during startup.

### isGuestUserProvider

True when the current user is anonymous.

### effectiveUserIdProvider

```dart
final effectiveUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authUserProvider);
  if (user == null) return 'signed-out';
  if (user.isAnonymous) return 'guest:${user.uid}';
  return user.uid;
});
```

Purpose:

- Defines the user-scoped bucket id used by persistence.

### authActionsProvider

```dart
final authActionsProvider = Provider<_AuthActions>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  return _AuthActions(
    signInAnonymously: () {
      if (auth == null) {
        return Future.error(StateError('Auth not initialized'));
      }
      return auth.signInAnonymously();
    },
    signOut: () {
      if (auth == null) {
        return Future.error(StateError('Auth not initialized'));
      }
      return auth.signOut();
    },
  );
});
```

Purpose:

- Thin wrapper for auth actions with a safe null guard.
- Email/password flows use firebaseAuthProvider directly inside SignInPage.

---

## AuthGate behavior

File: lib/features/auth/auth_gate.dart

AuthGate reads firebaseUserProvider and renders:

- Loading state -> CircularProgressIndicator
- Error state -> simple error scaffold
- Data:
  - user == null -> SignInPage
  - else -> render the provided child

AuthGate does not trigger migration; side effects are centralized in authSideEffectsProvider.

---

## Auth side effects (migration + invalidation)

File: lib/features/auth/auth_side_effects.dart

This provider is watched in App, and listens to firebaseUserProvider:

- On auth uid change:
  - clears the current editing set
  - invalidates aftRepositoryProvider and settingsProvider
  - invalidates proctor session, inputs, timing, profile, and UI providers
- If the user is anonymous:
  - trackGuestUser(uid)
- If the user becomes non-anonymous (or the uid changes):
  - maybeMigrateGuestTo(uid)

---

## Sign-in UI behavior

File: lib/features/auth/sign_in_page.dart

Current sign-in methods:

1. Email + password
   - Sign in with email/password.
   - Create account uses createUserWithEmailAndPassword.
   - If the current user is anonymous, create account uses linkWithCredential to keep the same uid.
   - Password reset uses sendPasswordResetEmail.
   - When PasswordResetLinks is configured, sendPasswordResetEmail passes ActionCodeSettings to open the reset flow in-app.

2. Continue as Guest
   - Calls FirebaseAuth.signInAnonymously().
   - Tracks anon uid with GuestMigration.trackGuestUser so migration can find the bucket later.

3. Continue with Apple (iOS/macOS)
   - Uses sign_in_with_apple to obtain an Apple ID credential.
   - Generates a random nonce, hashes it with SHA-256, and passes it to Apple.
   - Builds an OAuth credential using idToken, rawNonce, and authorizationCode as accessToken when present.
   - If the current user is anonymous, linkWithCredential is attempted first to preserve the uid.
     If the credential is already in use, the app falls back to signInWithCredential.

4. Continue with Google
   - Uses google_sign_in to obtain Google tokens.
   - Builds a GoogleAuthProvider credential and signs in with FirebaseAuth.
   - If the current user is anonymous, linkWithCredential is attempted first to preserve the uid.
     If the credential is already in use, the app falls back to signInWithCredential.

Navigation:

- The page attempts to Navigator.pop() after successful sign-in.
- AuthGate will rebuild to the signed-in shell when userChanges() emits a user.

---

## In-app password reset (App Links / Universal Links)

Files:

- lib/features/auth/password_reset_links.dart
- lib/features/auth/reset_password_screen.dart
- lib/app.dart (app link handler)

Flow:

1. SignInPage sends sendPasswordResetEmail with ActionCodeSettings.
2. Firebase sends a link that opens the app (universal link/app link).
3. App listens for app links and routes to ResetPasswordScreen.
4. ResetPasswordScreen verifies the code and completes confirmPasswordReset.

Required configuration:

- Set PasswordResetLinks.appLinkDomain to your universal link domain.
- Update ios/Runner/Runner.entitlements with applinks:<your-domain>.
- Update android/app/src/main/AndroidManifest.xml intent filter host.
- Host Apple App Site Association (/.well-known/apple-app-site-association).
- Host Android assetlinks.json (/.well-known/assetlinks.json).
- Add the domain to Firebase Auth authorized domains.

---

## Persistence + guest buckets

Local score sets are stored by LocalAftRepository under the key (when local storage is used):

- scoreSets:{userId}

where userId is the value from effectiveUserIdProvider. Signed-out users use DisabledAftRepository,
so no local writes happen when signed out.

Buckets in use:

- signed-out -> no saved sets (DisabledAftRepository)
- anonymous -> scoreSets:guest:{anonUid}
- legacy signed-out -> scoreSets:guest (migration only)
- legacy local signed-in -> scoreSets:{uid} (migration only)
- tracking keys -> scoreSets:lastAnonUid, scoreSets:guestOwnerUid

Firestore:

- User data lives in users/{uid}/scoreSets (document id = ScoreSet.id).
- Default profile settings live in users/{uid} under defaultProfile.
- Firestore rules enforce schema validation and prevent changes to createdAt after creation.

---

## Guest migration details

Guest migration lives in lib/features/saves/guest_migration.dart.

Algorithm (maybeMigrateGuestTo(uid)):

1. Read legacy guest bucket (scoreSets:guest), last anon guest bucket, and legacy local user bucket.
2. Prevent cross-account migration of the legacy signed-out bucket using scoreSets:guestOwnerUid.
3. Merge sets by id and write to Firestore users/{uid}/scoreSets using batched writes.
4. Write a migration marker (users/{uid}.migration) and verify it against the server.
5. If verified, clear local buckets; otherwise mark migration pending and keep local data.

Notes:

- Uses an in-flight lock to prevent concurrent migrations for the same uid.
- Uses migrationPending keys to retry later when offline or on failure.

---

## Default profile settings sync

SettingsController (lib/state/settings_state.dart) manages default profile settings.

Behavior:

- Local profile data is stored in SharedPreferences, scoped per user:
  - signed-out
  - guest:{anonUid}
  - uid
- On auth change, the controller loads the scoped profile.
- When a guest upgrades to a real account (same uid), guest-scoped profile data
  is copied into the uid scope before Firestore sync.
- For signed-in users, it syncs with Firestore users/{uid}.
- updatedAt is used for last-write-wins resolution.

---

## Common flows (step-by-step)

### Flow A: Fresh install -> Email sign-in

1. App starts.
2. firebaseUserProvider emits null.
3. AuthGate shows SignInPage.
4. Email sign-in succeeds.
5. firebaseUserProvider emits User(uid, isAnonymous=false).
6. authSideEffectsProvider invalidates user-scoped providers and triggers migration.
7. AuthGate shows the app shell.

### Flow B: Fresh install -> Continue as Guest

1. App starts.
2. User selects Continue as Guest.
3. Firebase signs in anonymously.
4. firebaseUserProvider emits User(isAnonymous=true).
5. authSideEffectsProvider tracks anon uid.
6. AuthGate shows the app shell; persistence uses scoreSets:guest:{anonUid}.

### Flow C: Guest (anonymous) -> Email sign-in later

1. User uses app as guest; saved sets exist in guest:{anonUid}.
2. User registers while anonymous; credentials are linked (uid preserved).
3. SettingsController migrates guest-scoped profile data into the uid scope.
4. authSideEffectsProvider sees anon -> non-anon and migrates guest data into Firestore.

---

## Troubleshooting

### "Auth not initialized"

The SignInPage shows this error when firebaseAuthProvider returns null.

Typical causes:

- Firebase initialization did not run.
- Running a widget test without Firebase.

### Email auth issues

- email-already-in-use means the user should use the Sign in flow instead of Create account.
- wrong-password or user-not-found indicates invalid credentials.

---

## Extension points / how to change auth safely

Common changes you might make:

1. Add new sign-in methods (Google/Apple/email)
   - Implement in SignInPage (or a new auth UI).
   - Keep AuthGate routing based on firebaseUserProvider.

2. Change guest semantics
   - Update effectiveUserIdProvider.
   - Review guest migration keys and logic.

3. Change profile sync
   - Update SettingsController sync logic in settings_state.dart.

4. Route differently after sign-in
   - AuthGate renders the provided child, and AppRouter wires it per route.
   - If you add onboarding, branch here.
