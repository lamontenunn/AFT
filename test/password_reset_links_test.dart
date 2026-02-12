import 'package:aft_firebase_app/features/auth/password_reset_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordResetLinks.extractOobCode', () {
    test('extracts from wrapped firebase link in `link` query param', () {
      final uri = Uri.parse(
        'https://links.nunntechnologies.com/reset'
        '?link=https%3A%2F%2Faft-firebase-app-1760071390.firebaseapp.com%2F__%2Fauth%2Faction%3Fmode%3DresetPassword%26oobCode%3DABC123',
      );

      expect(PasswordResetLinks.extractOobCode(uri), 'ABC123');
    });

    test('extracts when mode is omitted but oobCode exists', () {
      final uri = Uri.parse('https://links.nunntechnologies.com/reset?oobCode=XYZ999');

      expect(PasswordResetLinks.extractOobCode(uri), 'XYZ999');
    });

    test('returns null for non-reset action code mode', () {
      final uri = Uri.parse(
        'https://links.nunntechnologies.com/reset?mode=verifyEmail&oobCode=SHOULD_NOT_USE',
      );

      expect(PasswordResetLinks.extractOobCode(uri), isNull);
    });
  });
}
