import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/auth/auth_state.dart';

/// Auth controller (stubbed for now). No SDK usage here.
/// Swap this implementation later to wrap FirebaseAuth or another provider.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Start signed out
    return const AuthState.signedOut();
  }

  /// Stub sign-in that toggles to a deterministic dummy user.
  Future<void> signIn() async {
    state = const AuthState.signedIn(
      userId: 'demo_user_123',
      displayName: 'Demo User',
      photoUrl: null,
    );
  }

  Future<void> signOut() async {
    state = const AuthState.signedOut();
  }
}

final authStateProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Convenience provider to expose actions without reading state directly.
final authActionsProvider = Provider<_AuthActions>((ref) {
  final notifier = ref.read(authStateProvider.notifier);
  return _AuthActions(
    signIn: notifier.signIn,
    signOut: notifier.signOut,
  );
});

class _AuthActions {
  const _AuthActions({
    required this.signIn,
    required this.signOut,
  });

  final Future<void> Function() signIn;
  final Future<void> Function() signOut;
}
