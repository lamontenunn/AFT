import 'dart:async';

import 'package:aft_firebase_app/features/auth/auth_gate.dart';
import 'package:aft_firebase_app/features/auth/sign_in_page.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/fake_auth.dart';

void main() {
  Widget _wrap(Widget child, List<Override> overrides) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: child),
    );
  }

  testWidgets('AuthGate shows SignInPage when user is null', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const AuthGate(child: Text('app-shell')),
        [
          firebaseUserProvider.overrideWith((ref) => Stream.value(null)),
        ],
      ),
    );

    await tester.pump();
    expect(find.byType(SignInPage), findsOneWidget);
    expect(find.text('app-shell'), findsNothing);
  });

  testWidgets('AuthGate shows child when user exists', (tester) async {
    final user = buildMockUser(uid: 'u1', isAnonymous: false);
    await tester.pumpWidget(
      _wrap(
        const AuthGate(child: Text('app-shell')),
        [
          firebaseUserProvider.overrideWith((ref) => Stream.value(user)),
        ],
      ),
    );

    await tester.pump();
    expect(find.text('app-shell'), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
  });

  testWidgets('AuthGate shows spinner while loading', (tester) async {
    final controller = StreamController<User?>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        const AuthGate(child: Text('app-shell')),
        [
          firebaseUserProvider.overrideWith((ref) => controller.stream),
        ],
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AuthGate does not flicker SignInPage on quick user load',
      (tester) async {
    final controller = StreamController<User?>();
    addTearDown(controller.close);

    await tester.pumpWidget(
      _wrap(
        const AuthGate(child: Text('app-shell')),
        [
          firebaseUserProvider.overrideWith((ref) => controller.stream),
        ],
      ),
    );

    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);

    controller.add(buildMockUser(uid: 'u2', isAnonymous: false));
    await tester.pump();

    expect(find.text('app-shell'), findsOneWidget);
    expect(find.byType(SignInPage), findsNothing);
  });
}
