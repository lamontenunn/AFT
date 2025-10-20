import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:aft_firebase_app/features/auth/auth_state.dart';

/// Expose FirebaseAuth instance
final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  // In tests (or before Firebase.initializeApp), avoid touching FirebaseAuth.
  if (Firebase.apps.isEmpty) return null;
  return FirebaseAuth.instance;
});

/// Firebase user stream
final firebaseUserProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  // If Firebase isn't initialized (e.g., tests), appear signed out.
  if (auth == null) return Stream<User?>.value(null);
  return auth.authStateChanges();
});

/// Map Firebase user to our AuthState (non-async for easy consumption in UI)
final authStateProvider = Provider<AuthState>((ref) {
  final asyncUser = ref.watch(firebaseUserProvider);
  final user = asyncUser.asData?.value;
  if (user == null) {
    return const AuthState.signedOut();
  }
  return AuthState.signedIn(
    userId: user.uid,
    displayName: user.displayName,
    photoUrl: user.photoURL,
  );
});

/// Convenience provider to expose auth actions
final effectiveUserIdProvider = Provider<String>((ref) {
  final asyncUser = ref.watch(firebaseUserProvider);
  final user = asyncUser.asData?.value;
  if (user == null || user.isAnonymous) return 'guest';
  return user.uid;
});

final authActionsProvider = Provider<_AuthActions>((ref) {
  final auth = ref.read(firebaseAuthProvider);
  return _AuthActions(
    signInAnonymously: () => auth!.signInAnonymously(),
    signOut: () => auth!.signOut(),
  );
});

class _AuthActions {
  const _AuthActions({
    required this.signInAnonymously,
    required this.signOut,
  });

  final Future<UserCredential> Function() signInAnonymously;
  final Future<void> Function() signOut;
}
