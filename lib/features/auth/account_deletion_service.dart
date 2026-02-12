import 'dart:convert';
import 'dart:math' as math;

import 'package:aft_firebase_app/data/aft_repository_local.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

enum AccountDeletionReauthMethod {
  password,
  google,
  apple,
  unsupported,
}

class AccountDeletionException implements Exception {
  const AccountDeletionException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  @override
  String toString() => 'AccountDeletionException($code): $message';
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return AccountDeletionService(
    auth: auth,
    firestore: FirebaseFirestore.instance,
  );
});

class AccountDeletionService {
  AccountDeletionService({
    required FirebaseAuth? auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  final FirebaseAuth? _auth;
  final FirebaseFirestore _firestore;

  AccountDeletionReauthMethod requiredReauthMethodFor(User user) {
    final providerIds = user.providerData
        .map((e) => e.providerId)
        .where((id) => id != 'firebase')
        .toSet();
    if (providerIds.contains('password')) {
      return AccountDeletionReauthMethod.password;
    }
    if (providerIds.contains('google.com')) {
      return AccountDeletionReauthMethod.google;
    }
    if (providerIds.contains('apple.com')) {
      return AccountDeletionReauthMethod.apple;
    }
    return AccountDeletionReauthMethod.unsupported;
  }

  Future<void> deleteCurrentUserAccount({String? password}) async {
    final auth = _auth;
    if (auth == null) {
      throw const AccountDeletionException(
        code: 'auth-not-initialized',
        message: 'Authentication is not initialized.',
      );
    }

    final user = auth.currentUser;
    if (user == null) {
      throw const AccountDeletionException(
        code: 'not-signed-in',
        message: 'No signed-in account found.',
      );
    }
    if (user.isAnonymous) {
      throw const AccountDeletionException(
        code: 'anonymous-account',
        message: 'Guest sessions do not support account deletion.',
      );
    }

    final uid = user.uid;
    await _reauthenticate(user, password: password);
    await _deleteCloudData(uid);

    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        code: e.code,
        message: e.message ?? 'Unable to delete account.',
      );
    }

    await _deleteLocalData(uid);
  }

  Future<void> _reauthenticate(
    User user, {
    String? password,
  }) async {
    final method = requiredReauthMethodFor(user);
    switch (method) {
      case AccountDeletionReauthMethod.password:
        await _reauthWithPassword(user, password: password);
      case AccountDeletionReauthMethod.google:
        await _reauthWithGoogle(user);
      case AccountDeletionReauthMethod.apple:
        await _reauthWithApple(user);
      case AccountDeletionReauthMethod.unsupported:
        throw const AccountDeletionException(
          code: 'unsupported-provider',
          message: 'This sign-in provider is not currently supported.',
        );
    }
  }

  Future<void> _reauthWithPassword(
    User user, {
    String? password,
  }) async {
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw const AccountDeletionException(
        code: 'missing-email',
        message: 'Unable to verify account email for reauthentication.',
      );
    }
    final secret = password?.trim() ?? '';
    if (secret.isEmpty) {
      throw const AccountDeletionException(
        code: 'password-required',
        message: 'Enter your current password.',
      );
    }

    try {
      final credential =
          EmailAuthProvider.credential(email: email, password: secret);
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        code: e.code,
        message: e.message ?? 'Reauthentication failed.',
      );
    }
  }

  Future<void> _reauthWithGoogle(User user) async {
    final googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) {
      throw const AccountDeletionException(
        code: 'reauth-cancelled',
        message: 'Google reauthentication was canceled.',
      );
    }

    try {
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        code: e.code,
        message: e.message ?? 'Google reauthentication failed.',
      );
    }
  }

  Future<void> _reauthWithApple(User user) async {
    if (!_isAppleSupported) {
      throw const AccountDeletionException(
        code: 'apple-not-supported',
        message: 'Apple Sign-In is not available on this device.',
      );
    }

    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw const AccountDeletionException(
        code: 'apple-not-available',
        message: 'Apple Sign-In is not available on this device.',
      );
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw const AccountDeletionException(
          code: 'apple-missing-token',
          message: 'Apple Sign-In failed to return an identity token.',
        );
      }
      final authorizationCode = appleCredential.authorizationCode;
      final credential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: authorizationCode.isNotEmpty ? authorizationCode : null,
      );
      await user.reauthenticateWithCredential(credential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AccountDeletionException(
          code: 'reauth-cancelled',
          message: 'Apple reauthentication was canceled.',
        );
      }
      throw AccountDeletionException(
        code: 'apple-reauth-failed',
        message: 'Apple reauthentication failed (${e.code.name}).',
      );
    } on SignInWithAppleException catch (e) {
      throw AccountDeletionException(
        code: 'apple-reauth-failed',
        message: 'Apple reauthentication failed: $e',
      );
    } on FirebaseAuthException catch (e) {
      throw AccountDeletionException(
        code: e.code,
        message: e.message ?? 'Apple reauthentication failed.',
      );
    }
  }

  Future<void> _deleteCloudData(String uid) async {
    final userDoc = _firestore.collection('users').doc(uid);
    await _deleteCollection(userDoc.collection('scoreSets'));

    try {
      await userDoc.delete();
    } on FirebaseException catch (e) {
      if (e.code == 'not-found') return;
      throw AccountDeletionException(
        code: e.code,
        message: e.message ?? 'Unable to delete cloud profile data.',
      );
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) return;
    }
  }

  Future<void> _deleteLocalData(String uid) async {
    await LocalAftRepository().clearScoreSets(userId: uid);

    final prefs = await SharedPreferences.getInstance();
    final profileSuffix = ':$uid';
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('settings_defaultProfile_') &&
          key.endsWith(profileSuffix)) {
        await prefs.remove(key);
      }
    }

    await prefs.remove(GuestMigration.userKey(uid));
    await prefs.remove(GuestMigration.guestKeyForUid(uid));
    await prefs.remove(GuestMigration.migrationPendingKey(uid));
    await prefs.remove(GuestMigration.migrationMarkerKey(uid));
    await prefs.remove(GuestMigration.migrationExpectedKey(uid));

    final lastAnonUid = prefs.getString(GuestMigration.lastAnonUidKey());
    if (lastAnonUid == uid) {
      await prefs.remove(GuestMigration.lastAnonUidKey());
    }
    final guestOwnerUid = prefs.getString(GuestMigration.guestOwnerKey());
    if (guestOwnerUid == uid) {
      await prefs.remove(GuestMigration.guestOwnerKey());
    }
  }

  bool get _isAppleSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
