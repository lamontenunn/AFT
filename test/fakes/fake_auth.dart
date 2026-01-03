import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

MockUser buildMockUser({
  required String uid,
  required bool isAnonymous,
}) {
  final user = MockUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.isAnonymous).thenReturn(isAnonymous);
  return user;
}

MockUserCredential buildMockCredential(User? user) {
  final cred = MockUserCredential();
  when(() => cred.user).thenReturn(user);
  return cred;
}

class FakeAuthController {
  FakeAuthController({User? initialUser}) {
    _controller = StreamController<User?>.broadcast();
    auth = MockFirebaseAuth();
    when(() => auth.authStateChanges()).thenAnswer((_) => _controller.stream);
    when(() => auth.currentUser).thenAnswer((_) => _currentUser);
    _currentUser = initialUser;
    if (initialUser != null) {
      _controller.add(initialUser);
    }
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
