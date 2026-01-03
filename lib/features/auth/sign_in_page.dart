import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  void _setStateIfMounted(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  String _friendlyAuthError(FirebaseAuthException e) {
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      _setStateIfMounted(() => _error = _friendlyAuthError(e));
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
      await auth.sendPasswordResetEmail(email: email);
      _setStateIfMounted(
        () => _info = 'Password reset email sent to $email',
      );
    } on FirebaseAuthException catch (e) {
      _setStateIfMounted(() => _error = _friendlyAuthError(e));
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
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      _setStateIfMounted(() => _error = _friendlyAuthError(e));
    } catch (e) {
      _setStateIfMounted(() => _error = 'Anonymous sign-in failed: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authUserProvider);
    final isSignedIn = user != null;
    final canSubmit = !_submitting && !_resetting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Email',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
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
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'name@example.com',
                      ),
                      validator: _validateEmail,
                      enabled: canSubmit,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      textInputAction:
                          _isRegistering ? TextInputAction.next : TextInputAction.done,
                      obscureText: !_showPassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          icon: Icon(
                            _showPassword ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _showPassword = !_showPassword);
                          },
                        ),
                      ),
                      validator: _validatePassword,
                      enabled: canSubmit,
                      onFieldSubmitted: (_) {
                        if (!_isRegistering) _submit();
                      },
                    ),
                    const SizedBox(height: 8),
                    if (_isRegistering)
                      TextFormField(
                        controller: _confirmController,
                        textInputAction: TextInputAction.done,
                        obscureText: !_showConfirm,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: 'Confirm password',
                          suffixIcon: IconButton(
                            tooltip: _showConfirm ? 'Hide password' : 'Show password',
                            icon: Icon(
                              _showConfirm ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _showConfirm = !_showConfirm);
                            },
                          ),
                        ),
                        validator: _validateConfirm,
                        enabled: canSubmit,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: canSubmit ? _submit : null,
                            icon: _submitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(_isRegistering
                                    ? Icons.person_add_alt_1
                                    : Icons.login),
                            label: Text(_isRegistering ? 'Create account' : 'Sign in'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: canSubmit
                              ? () {
                                  setState(() {
                                    _isRegistering = !_isRegistering;
                                    _error = null;
                                    _info = null;
                                  });
                                }
                              : null,
                          child: Text(
                            _isRegistering
                                ? 'Have an account? Sign in'
                                : 'Create an account',
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: (!_isRegistering && canSubmit) ? _sendPasswordReset : null,
                          child: _resetting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Forgot password?'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Guest',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _signInAnonymously,
              icon: const Icon(Icons.person_outline),
              label: const Text('Continue as Guest'),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_info != null)
              Text(
                _info!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            if (isSignedIn)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Signed in. You can close this page.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
