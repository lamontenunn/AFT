import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserMetadata extends Mock implements UserMetadata {}

class MockUserCredential extends Mock implements UserCredential {}

MockUser buildMockUser({
  required String uid,
  required bool isAnonymous,
}) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.isAnonymous).thenReturn(isAnonymous);
  when(() => user.providerData).thenReturn(const <UserInfo>[]);
  final meta = MockUserMetadata();
  when(() => meta.creationTime).thenReturn(null);
  when(() => meta.lastSignInTime).thenReturn(null);
  when(() => user.metadata).thenReturn(meta);
  return user;
}

MockUserCredential buildMockCredential(User? user) {
  final cred = MockUserCredential();
  when(() => cred.user).thenReturn(user);
  return cred;
}

class FakeAuthController {
  FakeAuthController({User? initialUser}) {
    _currentUser = initialUser;
    _controller = StreamController<User?>.broadcast(
      onListen: () {
        if (_currentUser != null) {
          _controller.add(_currentUser);
        }
      },
    );
    auth = MockFirebaseAuth();
    when(() => auth.authStateChanges()).thenAnswer((_) => _controller.stream);
    when(() => auth.userChanges()).thenAnswer((_) => _controller.stream);
    when(() => auth.currentUser).thenAnswer((_) => _currentUser);
  }

  late final MockFirebaseAuth auth;
  late final StreamController<User?> _controller;
  User? _currentUser;

  void emit(User? user) {
    _currentUser = user;
    _controller.add(user);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
