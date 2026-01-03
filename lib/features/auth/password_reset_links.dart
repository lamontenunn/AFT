import 'package:firebase_auth/firebase_auth.dart';
import 'package:aft_firebase_app/firebase_options.dart';

class PasswordResetLinks {
  // Set to your universal link domain, e.g. "https://reset.example.com".
  static const String appLinkDomain = '';
  static const String resetPath = '/reset';
  static const String androidPackageName = 'com.example.aft_firebase_app';
  // Optional Firebase Hosting custom domain for email action links.
  static const String linkDomain = '';

  static bool get isConfigured =>
      appLinkDomain.isNotEmpty && appLinkDomain.startsWith('https://');

  static Uri continueUri() {
    final base = Uri.parse(appLinkDomain);
    return base.replace(path: resetPath);
  }

  static ActionCodeSettings? buildActionCodeSettings() {
    if (!isConfigured) return null;
    final iosBundleId = DefaultFirebaseOptions.ios.iosBundleId;
    return ActionCodeSettings(
      url: continueUri().toString(),
      handleCodeInApp: true,
      iOSBundleId: iosBundleId,
      androidPackageName: androidPackageName,
      androidInstallApp: true,
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
