import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:aft_firebase_app/features/auth/password_reset_links.dart';
import 'package:aft_firebase_app/features/auth/login_showcase_carousel.dart';
import 'package:aft_firebase_app/widgets/aft_svg_icon.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isRegistering = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _submitting = false;
  bool _resetting = false;
  String? _error;
  String? _info;
  StateSetter? _emailSheetSetState;
  BuildContext? _emailSheetContext;

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    final sheetContext = _emailSheetContext;
    if (sheetContext != null && sheetContext.mounted) {
      _emailSheetSetState?.call(() {});
    } else {
      _emailSheetSetState = null;
      _emailSheetContext = null;
    }
  }

  String _friendlyAuthError(FirebaseAuthException e,
      {bool includeCode = false}) {
    final message = () {
      switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'credential-already-in-use':
        return 'That email is already linked to another account.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this Firebase project.';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed.';
      }
    }();
    if (!includeCode) return message;
    return '$message (code: ${e.code})';
  }

  String? _validateEmail(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email';
    if (!text.contains('@') || !text.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Enter your password';
    if (text.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? value) {
    if (!_isRegistering) return null;
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _closeAuthOverlays() {
    final sheetContext = _emailSheetContext;
    if (sheetContext != null && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    _emailSheetSetState = null;
    _emailSheetContext = null;

    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _submit() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      _setStateIfMounted(() => _error = 'Auth not initialized');
      return;
    }
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    _setStateIfMounted(() {
      _submitting = true;
      _error = null;
      _info = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final currentUser = auth.currentUser;
      if (_isRegistering) {
        if (currentUser != null && currentUser.isAnonymous) {
          final credential = EmailAuthProvider.credential(
            email: email,
            password: password,
          );
          await currentUser.linkWithCredential(credential);
        } else {
          await auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      _closeAuthOverlays();
    } on FirebaseAuthException catch (e) {
      _setStateIfMounted(
          () => _error = _friendlyAuthError(e, includeCode: true));
    } catch (e) {
      _setStateIfMounted(() => _error = 'Authentication failed: $e');
    } finally {
      _setStateIfMounted(() => _submitting = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      _setStateIfMounted(() => _error = 'Auth not initialized');
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _setStateIfMounted(() => _error = 'Enter your email to reset password');
      return;
    }

    _setStateIfMounted(() {
      _resetting = true;
      _error = null;
      _info = null;
    });
    FocusScope.of(context).unfocus();
    try {
      final settings = PasswordResetLinks.buildActionCodeSettings();
      if (settings == null) {
        await auth.sendPasswordResetEmail(email: email);
      } else {
        await auth.sendPasswordResetEmail(
          email: email,
          actionCodeSettings: settings,
        );
      }
      _setStateIfMounted(
        () => _info =
            'Password reset request sent to $email. If you do not receive it, '
            'check spam/junk or try a different email provider.',
      );
    } on FirebaseAuthException catch (e) {
      _setStateIfMounted(
          () => _error = _friendlyAuthError(e, includeCode: true));
    } catch (e) {
      _setStateIfMounted(() => _error = 'Failed to send reset email: $e');
    } finally {
      _setStateIfMounted(() => _resetting = false);
    }
  }

  Future<void> _signInAnonymously() async {
    _setStateIfMounted(() {
      _error = null;
      _info = null;
    });
    try {
      final cred = await ref.read(authActionsProvider).signInAnonymously();
      final user = cred.user;
      if (user != null) {
        await ref.read(guestMigrationProvider).trackGuestUser(user.uid);
      }
      _closeAuthOverlays();
    } on FirebaseAuthException catch (e) {
      _setStateIfMounted(() => _error = _friendlyAuthError(e));
    } catch (e) {
      _setStateIfMounted(() => _error = 'Anonymous sign-in failed: $e');
    }
  }

  void _showSocialComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in is coming soon.')),
    );
  }

  void _showSocialUnavailable(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider sign-in is unavailable on this device.')),
    );
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = math.Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  void _debugLogAppleIdTokenClaims(String idToken, String expectedNonce) {
    assert(() {
      try {
        final parts = idToken.split('.');
        if (parts.length != 3) {
          debugPrint('Apple idToken malformed: ${parts.length} parts');
          return true;
        }
        final normalized = base64Url.normalize(parts[1]);
        final payload = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> claims = jsonDecode(payload);
        final aud = claims['aud'];
        final iss = claims['iss'];
        final sub = claims['sub'];
        final nonce = claims['nonce'];
        debugPrint('Apple idToken claims: aud=$aud iss=$iss sub=$sub nonce=$nonce');
        debugPrint('Expected hashed nonce: $expectedNonce');
      } catch (e) {
        debugPrint('Failed to decode Apple idToken claims: $e');
      }
      return true;
    }());
  }

  bool get _isAppleSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> _signInWithApple() async {
    if (_submitting || _resetting) return;
    if (!_isAppleSupported) {
      _showSocialUnavailable('Apple');
      return;
    }

    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      _setStateIfMounted(() => _error = 'Auth not initialized');
      return;
    }

    assert(() {
      final app = auth.app;
      debugPrint(
        'Firebase app: name=${app.name} projectId=${app.options.projectId} bundleId=${app.options.iosBundleId}',
      );
      return true;
    }());

    _setStateIfMounted(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    try {
      final available = await SignInWithApple.isAvailable();
      if (!available) {
        _setStateIfMounted(() =>
            _error = 'Apple Sign-In is not available on this device.');
        return;
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        _setStateIfMounted(
            () => _error = 'Apple Sign-In failed to return a token.');
        return;
      }
      _debugLogAppleIdTokenClaims(idToken, nonce);

      final authorizationCode = appleCredential.authorizationCode;
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken:
            (authorizationCode != null && authorizationCode.isNotEmpty)
                ? authorizationCode
                : null,
      );

      final currentUser = auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          await currentUser.linkWithCredential(oauthCredential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            await auth.signInWithCredential(oauthCredential);
          } else {
            rethrow;
          }
        }
      } else {
        await auth.signInWithCredential(oauthCredential);
      }

      _closeAuthOverlays();
    } on SignInWithAppleAuthorizationException catch (e) {
      assert(() {
        debugPrint('Apple sign-in authorization error: ${e.code} ${e.message}');
        return true;
      }());
      if (e.code == AuthorizationErrorCode.canceled) {
        _setStateIfMounted(() => _info = 'Apple sign-in canceled.');
      } else {
        _setStateIfMounted(() => _error =
            'Apple sign-in failed (${e.code.name}): ${e.message}');
      }
    } on SignInWithAppleException catch (e) {
      assert(() {
        debugPrint('Apple sign-in error: $e');
        return true;
      }());
      _setStateIfMounted(() => _error = 'Apple sign-in failed: $e');
    } on FirebaseAuthException catch (e) {
      assert(() {
        debugPrint('Firebase auth error: ${e.code} ${e.message}');
        return true;
      }());
      _setStateIfMounted(
          () => _error = _friendlyAuthError(e, includeCode: true));
    } catch (e) {
      _setStateIfMounted(() => _error = 'Apple sign-in failed: $e');
    } finally {
      _setStateIfMounted(() => _submitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_submitting || _resetting) return;

    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      _setStateIfMounted(() => _error = 'Auth not initialized');
      return;
    }

    _setStateIfMounted(() {
      _submitting = true;
      _error = null;
      _info = null;
    });

    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _setStateIfMounted(() => _info = 'Google sign-in canceled.');
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final currentUser = auth.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            await auth.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        await auth.signInWithCredential(credential);
      }

      _closeAuthOverlays();
    } on FirebaseAuthException catch (e) {
      _setStateIfMounted(() => _error = _friendlyAuthError(e));
    } catch (e) {
      _setStateIfMounted(() => _error = 'Google sign-in failed: $e');
    } finally {
      _setStateIfMounted(() => _submitting = false);
    }
  }

  void _toggleRegistering() {
    _setStateIfMounted(() {
      _isRegistering = !_isRegistering;
      _showConfirm = false;
      _confirmController.clear();
      _error = null;
      _info = null;
    });
  }

  Future<void> _showEmailAuthSheet() async {
    FocusScope.of(context).unfocus();
    _setStateIfMounted(() {
      _error = null;
      _info = null;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            _emailSheetSetState = sheetSetState;
            _emailSheetContext = context;
            final media = MediaQuery.of(context);
            final isCompact = media.size.height < 700;
            final textTheme = Theme.of(context).textTheme;
            final fieldPadding = EdgeInsets.symmetric(
              horizontal: 12,
              vertical: isCompact ? 10 : 12,
            );
            final buttonPadding = EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isCompact ? 10 : 12,
            );
            final textButtonPadding = EdgeInsets.symmetric(
              horizontal: 8,
              vertical: isCompact ? 0 : 4,
            );
            final canSubmit = !_submitting && !_resetting;
            final titleStyle =
                isCompact ? textTheme.titleMedium : textTheme.titleLarge;
            final description = _isRegistering
                ? 'Create an account to sync scores and save sessions.'
                : 'Use your email and password to continue.';

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + media.viewInsets.bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SheetHandle(),
                      const SizedBox(height: 12),
                      Text(
                        _isRegistering
                            ? 'Create account'
                            : 'Sign in with email',
                        style: titleStyle,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: AutofillGroup(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.none,
                                autofillHints: const [AutofillHints.email],
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  hintText: 'name@example.com',
                                  isDense: true,
                                  contentPadding: fieldPadding,
                                ),
                                validator: _validateEmail,
                                enabled: canSubmit,
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                textInputAction: _isRegistering
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                obscureText: !_showPassword,
                                autocorrect: false,
                                enableSuggestions: false,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  isDense: true,
                                  contentPadding: fieldPadding,
                                  suffixIcon: IconButton(
                                    tooltip: _showPassword
                                        ? 'Hide password'
                                        : 'Show password',
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    onPressed: () {
                                      _setStateIfMounted(
                                          () => _showPassword = !_showPassword);
                                    },
                                  ),
                                ),
                                validator: _validatePassword,
                                enabled: canSubmit,
                                onFieldSubmitted: (_) {
                                  if (!_isRegistering) _submit();
                                },
                              ),
                              if (_isRegistering) ...[
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _confirmController,
                                  textInputAction: TextInputAction.done,
                                  obscureText: !_showConfirm,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  autofillHints: const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: 'Confirm password',
                                    isDense: true,
                                    contentPadding: fieldPadding,
                                    suffixIcon: IconButton(
                                      tooltip: _showConfirm
                                          ? 'Hide password'
                                          : 'Show password',
                                      icon: Icon(
                                        _showConfirm
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        _setStateIfMounted(() =>
                                            _showConfirm = !_showConfirm);
                                      },
                                    ),
                                  ),
                                  validator: _validateConfirm,
                                  enabled: canSubmit,
                                  onFieldSubmitted: (_) => _submit(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: buttonPadding,
                              ),
                              onPressed: canSubmit ? () => _submit() : null,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(_isRegistering
                                      ? Icons.person_add_alt_1
                                      : Icons.login),
                              label: Text(_isRegistering
                                  ? 'Create account'
                                  : 'Sign in'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: textButtonPadding,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: canSubmit ? _toggleRegistering : null,
                            child: Text(
                              _isRegistering
                                  ? 'Have an account? Sign in'
                                  : 'Create an account',
                            ),
                          ),
                          if (!_isRegistering)
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: textButtonPadding,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: (!_isRegistering && canSubmit)
                                  ? () => _sendPasswordReset()
                                  : null,
                              child: _resetting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('Forgot password?'),
                            ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (_info != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _info!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    _emailSheetSetState = null;
    _emailSheetContext = null;
  }

  @override
  void dispose() {
    final sheetContext = _emailSheetContext;
    if (sheetContext != null && sheetContext.mounted) {
      Navigator.of(sheetContext).pop();
    }
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailSheetSetState = null;
    _emailSheetContext = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final isSignedIn = user != null;
    final screenHeight = MediaQuery.of(context).size.height;
    final compactAppBar = screenHeight < 760;
    final tightAppBar = screenHeight < 650;
    final canStartAuth = !_submitting && !_resetting;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sign in',
          style: compactAppBar
              ? (tightAppBar
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.titleMedium)
              : null,
        ),
        toolbarHeight: compactAppBar ? (tightAppBar ? 44 : 48) : null,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final isShort = height < 760;
            final isTight = height < 700;
            final ultraCompact = height < 620;
            final baseWidthFactor = isTight
                ? 0.9
                : isShort
                    ? 0.95
                    : 0.98;
            final heightCapFactor = ultraCompact
                ? 0.4
                : isTight
                    ? 0.46
                    : isShort
                        ? 0.5
                        : 0.54;
            final heightBasedFactor =
                (heightCapFactor * height) / constraints.maxWidth;
            final carouselWidthFactor = math
                .min(baseWidthFactor, heightBasedFactor)
                .clamp(0.6, baseWidthFactor)
                .toDouble();
            final verticalPadding = ultraCompact ? 4.0 : isTight ? 6.0 : 8.0;
            final sectionGap = ultraCompact ? 6.0 : isTight ? 8.0 : 10.0;
            final smallGap = ultraCompact ? 4.0 : isTight ? 6.0 : 8.0;
            final buttonPadding = EdgeInsets.symmetric(
              horizontal: 16,
              vertical: ultraCompact ? 8 : isTight ? 9 : 11,
            );
            final socialButtonPadding = EdgeInsets.symmetric(
              horizontal: 10,
              vertical: ultraCompact ? 6 : isTight ? 7 : 9,
            );
            final textTheme = Theme.of(context).textTheme;
            final sectionLabelStyle = textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: isTight ? 12 : null,
            );
            final showLabels = !ultraCompact;
            final guestButtonStyle = TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: 8,
                vertical: ultraCompact ? 0 : 2,
              ),
              visualDensity: ultraCompact
                  ? const VisualDensity(horizontal: -2, vertical: -2)
                  : isTight
                      ? const VisualDensity(horizontal: -1, vertical: -1)
                      : null,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );

            return GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: verticalPadding,
                ),
                children: [
                  LoginShowcaseCarousel(
                    widthFactor: carouselWidthFactor,
                    showSkip: false,
                  ),
                  SizedBox(height: sectionGap),
                  if (showLabels) Text('Continue with', style: sectionLabelStyle),
                  if (showLabels) SizedBox(height: smallGap),
                  Row(
                    children: [
                      Expanded(
                        child: _SocialAuthButton(
                          label: 'Apple',
                          asset: 'assets/icons/apple.svg',
                          iconColor: Colors.white,
                          onPressed:
                              canStartAuth ? () => _signInWithApple() : null,
                          padding: socialButtonPadding,
                          compact: isTight,
                        ),
                      ),
                      SizedBox(width: isTight ? 8 : 10),
                      Expanded(
                        child: _SocialAuthButton(
                          label: 'Google',
                          asset: 'assets/icons/google.svg',
                          onPressed:
                              canStartAuth ? () => _signInWithGoogle() : null,
                          padding: socialButtonPadding,
                          compact: isTight,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: smallGap),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: buttonPadding,
                      visualDensity: ultraCompact
                          ? const VisualDensity(horizontal: -2, vertical: -2)
                          : isTight
                              ? const VisualDensity(horizontal: -1, vertical: -1)
                              : null,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed:
                        canStartAuth ? () => _showEmailAuthSheet() : null,
                    icon: Icon(
                      Icons.email_outlined,
                      size: ultraCompact ? 16 : 18,
                    ),
                    label: const Text('Continue with Email'),
                  ),
                  SizedBox(height: smallGap),
                  TextButton.icon(
                    style: guestButtonStyle,
                    onPressed:
                        canStartAuth ? () => _signInAnonymously() : null,
                    icon: Icon(
                      Icons.person_outline,
                      size: ultraCompact ? 14 : 16,
                    ),
                    label: const Text('Continue as Guest'),
                  ),
                  if (_error != null) ...[
                    SizedBox(height: smallGap),
                    Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_info != null) ...[
                    SizedBox(height: smallGap),
                    Text(
                      _info!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.primary),
                    ),
                  ],
                  if (isSignedIn)
                    Padding(
                      padding: EdgeInsets.only(top: smallGap),
                      child: Text(
                        'Signed in. You can close this page.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SocialAuthButton extends StatelessWidget {
  const _SocialAuthButton({
    required this.label,
    required this.asset,
    this.iconColor,
    required this.onPressed,
    this.padding,
    this.compact = false,
  });

  final String label;
  final String asset;
  final Color? iconColor;
  final VoidCallback? onPressed;
  final EdgeInsets? padding;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = AftSvgIcon(
      asset,
      size: compact ? 16 : 18,
      padding: EdgeInsets.zero,
      colorFilter: iconColor == null
          ? null
          : ColorFilter.mode(iconColor!, BlendMode.srcIn),
      semanticLabel: '$label logo',
    );

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        backgroundColor: colorScheme.onPrimary,
        foregroundColor: Colors.white,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        visualDensity: compact
            ? const VisualDensity(horizontal: -1, vertical: -1)
            : null,
        tapTargetSize:
            compact ? MaterialTapTargetSize.shrinkWrap : null,
        side: BorderSide(
          color: colorScheme.primary.withOpacity(0.65),
          width: 1,
        ),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontSize: compact ? 12 : null,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline.withOpacity(0.5);
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
