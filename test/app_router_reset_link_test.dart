import 'package:aft_firebase_app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reset links are routed to reset password screen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute:
              'https://links.nunntechnologies.com/reset?'
              'link=https%3A%2F%2Faft-firebase-app-1760071390.firebaseapp.com%2F__%2Fauth%2Faction'
              '%3Fmode%3DresetPassword%26oobCode%3DTESTCODE123',
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Route not found'), findsNothing);
    expect(find.text('Reset password'), findsOneWidget);
  });
}
