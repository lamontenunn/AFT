import 'package:firebase_auth/firebase_auth.dart';

class PasswordResetLinks {
  // Universal link domain for reset flows.
  static const String appLinkDomain = 'https://links.nunntechnologies.com';
  static const String resetPath = '/reset/';
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
    Uri? target = link;
    final visited = <String>{};

    while (target != null) {
      final mode = target.queryParameters['mode'];
      final code = target.queryParameters['oobCode'];
      if (code != null && code.isNotEmpty) {
        // Some wrapped link formats omit `mode` after URL rewrites.
        if (mode == null || mode == 'resetPassword') {
          return code;
        }
      }

      final embedded = target.queryParameters['link'] ??
          target.queryParameters['deep_link_id'];
      if (embedded == null || embedded.isEmpty) break;
      final parsed = _parseEmbeddedUri(embedded, visited);
      if (parsed == null) break;
      target = parsed;
    }

    return null;
  }

  static Uri? _parseEmbeddedUri(String raw, Set<String> visited) {
    if (raw.isEmpty) return null;
    if (!visited.add(raw)) return null;

    final direct = Uri.tryParse(raw);
    if (direct != null) return direct;

    try {
      final decoded = Uri.decodeComponent(raw);
      if (!visited.add(decoded)) return null;
      return Uri.tryParse(decoded);
    } catch (_) {
      return null;
    }
  }
}
