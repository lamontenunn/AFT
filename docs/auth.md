# Authentication (Current Implementation)

This document explains how authentication works in the current codebase.
It is intended for internal developers and AI agents who need to understand the control-flow, providers, and the persistence implications (guest buckets + migration).

> **Scope:** This describes what exists today. It is not a “perfect” auth architecture; it documents the current behavior so changes can be made safely.

---

## TL;DR

- Auth is backed by **FirebaseAuth**.
- The **source of truth** is `FirebaseAuth.authStateChanges()`.
- Routing is gated by `AuthGate`:
  - user == `null` → `SignInPage`
  - user != `null` → `AftScaffold(child: FeatureHomeScreen())`
- “Guest” mode is supported via **Firebase anonymous sign-in**.
- Saved data uses a bucket key computed from auth state:
  - anonymous or null user → `guest`
  - signed-in (non-anonymous) user → `uid`
- When a user transitions from guest → non-anonymous, guest saved sets are migrated once.

---

## Key files

### UI / flow

- `lib/features/auth/auth_gate.dart`
- `lib/features/auth/sign_in_page.dart`

### Providers / state

- `lib/features/auth/providers.dart`
- `lib/features/auth/auth_state.dart`

### Guest migration

- `lib/features/saves/guest_migration.dart`

### Firebase init

- `lib/main.dart`
- `lib/firebase_options.dart`

---

## High-level flow diagram

```text
main.dart
  └─ Firebase.initializeApp()
  └─ ProviderScope
       └─ AppRouter -> AuthGate
             └─ firebaseUserProvider (authStateChanges)
                  ├─ null  -> SignInPage
                  └─ User  -> AftScaffold(FeatureHomeScreen)
                           └─ if non-anonymous -> GuestMigration.maybeMigrateGuestTo(uid)
```

---

## Providers (what they do and why)

All auth-related providers live in `lib/features/auth/providers.dart`.

### `firebaseAuthProvider`

```dart
final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance;
});
```

Purpose:

- Exposes `FirebaseAuth.instance`.
- Returns `null` when Firebase is not initialized (notably in tests), which prevents accidental Firebase calls.

Implication:

- Many auth flows must handle `auth == null` gracefully.

### `firebaseUserProvider`

```dart
final firebaseUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) return Stream<User?>.value(null);
  return auth.authStateChanges();
});
```

Purpose:

- Wraps `authStateChanges()` as a Riverpod `StreamProvider`.
- If Firebase isn’t initialized, the app behaves as signed out.

### `authStateProvider`

Maps the `User?` into a simple immutable `AuthState` for UI consumption.

Notes:

- This provider is **not async**; it reads the current value from `firebaseUserProvider.asData?.value`.
- This is convenient for UI that doesn’t want to do `.when(...)`.

### `effectiveUserIdProvider`

```dart
final effectiveUserIdProvider = Provider<String>((ref) {
  final asyncUser = ref.watch(firebaseUserProvider);
  final user = asyncUser.asData?.value;
  if (user == null || user.isAnonymous) return 'guest';
  return user.uid;
});
```

Purpose:

- Defines the “bucket” identifier used by persistence.

Behavior:

- `null user` → `guest`
- `anonymous user` → `guest`
- `non-anonymous user` → `uid`

This means anonymous sessions share the same saved-set bucket as “guest”.

### `authActionsProvider`

```dart
final authActionsProvider = Provider<_AuthActions>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  return _AuthActions(
    signInAnonymously: () => auth!.signInAnonymously(),
    signOut: () => auth!.signOut(),
  );
});
```

Purpose:

- Thin wrapper for auth actions.
- Note that it uses `auth!` (non-null assertion). UI must only call these actions when FirebaseAuth exists.

---

## AuthGate behavior

File: `lib/features/auth/auth_gate.dart`

AuthGate reads `firebaseUserProvider` and renders:

- Loading state → `CircularProgressIndicator`
- Error state → simple error scaffold
- Data:
  - `user == null` → `SignInPage`
  - else → `AftScaffold(showHeader: true, child: FeatureHomeScreen())`

### Guest migration trigger

When the user is **non-anonymous**, AuthGate triggers:

```dart
Future.microtask(() => GuestMigration.maybeMigrateGuestTo(user.uid));
```

Notes:

- “Fire and forget” call.
- The migration is guarded by a SharedPreferences flag, so it should only happen once per uid.

---

## Sign-in UI behavior

File: `lib/features/auth/sign_in_page.dart`

Current sign-in methods:

1. **Phone auth (SMS)**

   - Normalizes phone numbers to E.164 (assumes US +1 for 10-digit input).
   - `verifyPhoneNumber(...)` sends code.
   - On Android, may auto-complete (`verificationCompleted`).
   - On verify success → `signInWithCredential`.

2. **Continue as Guest**
   - Calls `FirebaseAuth.signInAnonymously()`.

Navigation:

- The page attempts to `Navigator.pop()` after successful sign-in.
- However, note that `AuthGate` will typically handle routing by rebuilding to the signed-in shell once `authStateChanges()` emits a user.

---

## Persistence + guest buckets

Guest migration lives in `lib/features/saves/guest_migration.dart`.

Keys:

- Guest bucket: `scoreSets:guest`
- User bucket: `scoreSets:{uid}`
- Migration flag: `guestMigrated:{uid}`

Algorithm (`maybeMigrateGuestTo(uid)`):

1. If `guestMigrated:{uid}` is true → stop.
2. Read guest bucket; if empty:
   - set `guestMigrated:{uid}` true
   - stop
3. Decode guest sets and existing user sets.
4. Merge lists and sort `createdAt` descending.
5. Save merged list to user bucket.
6. Clear guest bucket.
7. Set migration flag.

Important behavior:

- Migration is only triggered for **non-anonymous** users.
- Anonymous users are treated as `guest` by `effectiveUserIdProvider`.

---

## Common flows (step-by-step)

### Flow A: Fresh install → Phone sign-in

1. App starts.
2. `firebaseUserProvider` emits `null`.
3. `AuthGate` shows `SignInPage`.
4. Phone verification succeeds → Firebase signs in.
5. `firebaseUserProvider` emits `User(uid, isAnonymous=false)`.
6. `AuthGate`:
   - triggers guest migration (usually no-op)
   - shows `AftScaffold(...FeatureHomeScreen)`.

### Flow B: Fresh install → Continue as Guest

1. App starts.
2. User selects “Continue as Guest”.
3. Firebase signs in anonymously.
4. `firebaseUserProvider` emits `User(isAnonymous=true)`.
5. `AuthGate` shows `AftScaffold` (no migration).
6. Persistence uses effective user id = `guest`.

### Flow C: Guest (anonymous) → Phone sign-in later

1. User uses app as guest; saved sets exist in guest bucket.
2. User phone signs in.
3. `firebaseUserProvider` emits non-anonymous user.
4. `AuthGate` triggers migration:
   - `scoreSets:guest` merged into `scoreSets:{uid}`
   - `guestMigrated:{uid}` set

---

## Troubleshooting

### “Auth not initialized”

The SignInPage shows this error when `firebaseAuthProvider` returns null.

Typical causes:

- Firebase initialization didn’t run.
- You’re running a widget test without Firebase.

### Phone auth issues

- On Web, Firebase may present a reCAPTCHA.
- On Android, SMS auto-retrieval may complete without manual code entry.

### Emulator usage

If you’re developing auth flows, it can be useful to point to the Auth emulator in debug builds.

---

## Extension points / how to change auth safely

Common changes you might make:

1. Add new sign-in methods (Google/Apple/email)

   - Implement in `SignInPage` (or a new auth UI)
   - Ensure AuthGate still routes based on `firebaseUserProvider`.

2. Change “guest” semantics

   - Update `effectiveUserIdProvider`.
   - Review guest migration behavior and keys.

3. Route differently after sign-in
   - Currently AuthGate always routes to `FeatureHomeScreen` inside `AftScaffold`.
   - If you add onboarding, this is where you would branch.
