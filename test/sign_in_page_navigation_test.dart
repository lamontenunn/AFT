import 'package:aft_firebase_app/features/auth/sign_in_page.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'fakes/fake_auth.dart';

class FakeGuestMigrationService implements GuestMigrationService {
  @override
  Future<void> maybeMigrateGuestTo(String uid) async {}

  @override
  Future<void> trackGuestUser(String uid) async {}
}

void main() {
  testWidgets('SignInPage pops after guest sign-in', (tester) async {
    final auth = MockFirebaseAuth();
    final user = buildMockUser(uid: 'anon-1', isAnonymous: true);
    final cred = buildMockCredential(user);
    when(() => auth.signInAnonymously()).thenAnswer((_) async => cred);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          authUserProvider.overrideWithValue(null),
          guestMigrationProvider
              .overrideWithValue(FakeGuestMigrationService()),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Column(
                children: [
                  const Text('home-screen'),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SignInPage(),
                        ),
                      );
                    },
                    child: const Text('open-sign-in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('home-screen'), findsOneWidget);

    await tester.tap(find.text('open-sign-in'));
    await tester.pumpAndSettle();
    expect(find.byType(SignInPage), findsOneWidget);

    final guestButton = find.text('Continue as Guest');
    await tester.scrollUntilVisible(
      guestButton,
      200,
      scrollable: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(guestButton);
    await tester.pumpAndSettle();

    expect(find.byType(SignInPage), findsNothing);
    expect(find.text('home-screen'), findsOneWidget);
  });
}
