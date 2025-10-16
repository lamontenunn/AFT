import 'package:flutter/foundation.dart';

@immutable
class AuthState {
  final bool isSignedIn;
  final String? userId;
  final String? displayName;
  final String? photoUrl;

  const AuthState({
    required this.isSignedIn,
    this.userId,
    this.displayName,
    this.photoUrl,
  });

  const AuthState.signedOut()
      : isSignedIn = false,
        userId = null,
        displayName = null,
        photoUrl = null;

  const AuthState.signedIn({
    required String userId,
    String? displayName,
    String? photoUrl,
  })  : isSignedIn = true,
        userId = userId,
        displayName = displayName,
        photoUrl = photoUrl;

  AuthState copyWith({
    bool? isSignedIn,
    String? userId,
    String? displayName,
    String? photoUrl,
  }) {
    return AuthState(
      isSignedIn: isSignedIn ?? this.isSignedIn,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
