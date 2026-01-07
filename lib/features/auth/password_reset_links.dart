import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetLinks {
  // Universal link domain for reset flows.
  static const String appLinkDomain = 'https://links.nunntechnologies.com';
  static const String resetPath = '/reset';
  static const String androidPackageName = 'com.lamontenunn.aftpro';
  static const String androidMinimumVersion = '1';
  static const String iosBundleId = 'com.lamontenunn.aftpro';
  // Optional Firebase Hosting custom domain for email action links.
  static const String linkDomain = 'links.nunntechnologies.com';

  static bool get isConfigured =>
      appLinkDomain.isNotEmpty && appLinkDomain.startsWith('https://');

  static Uri continueUri() {
    final base = Uri.parse(appLinkDomain);
    return base.replace(path: resetPath);
  }

  static ActionCodeSettings? buildActionCodeSettings() {
    if (!isConfigured) return null;
    return ActionCodeSettings(
      url: continueUri().toString(),
      handleCodeInApp: true,
      iOSBundleId: iosBundleId,
      androidPackageName: androidPackageName,
      androidInstallApp: true,
      androidMinimumVersion: androidMinimumVersion,
      linkDomain: linkDomain.isNotEmpty ? linkDomain : null,
    );
  }

  static String? extractOobCode(Uri link) {
    Uri target = link;
    final embedded = link.queryParameters['link'];
    if (embedded != null) {
      final decoded = Uri.decodeFull(embedded);
      final parsed = Uri.tryParse(decoded);
      if (parsed != null) {
        target = parsed;
      }
    }

    final mode = target.queryParameters['mode'];
    if (mode != 'resetPassword') return null;
    return target.queryParameters['oobCode'];
  }
}
