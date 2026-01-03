import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:aft_firebase_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches to sign-in or home', (tester) async {
    await app.main();
    await tester.pumpAndSettle();

    final hasSignIn = find.text('Sign in').evaluate().isNotEmpty;
    final hasHome = find.text('Home').evaluate().isNotEmpty;

    expect(hasSignIn || hasHome, isTrue);
  });
}
