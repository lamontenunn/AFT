import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _sending = false;
  bool _verifying = false;
  bool _codeSent = false;
  String? _verificationId;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String? _normalizePhone(String input) {
    // Accept E.164 or US local numbers. Strip formatting, add +1 if needed.
    final raw = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (raw.startsWith('+')) return raw; // already E.164
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) return '+1$digits';
    if (digits.length == 11 && digits.startsWith('1')) return '+1${digits.substring(1)}';
    return null; // invalid
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      setState(() {
        _error = 'Auth not initialized';
        _sending = false;
      });
      return;
    }
    try {
      final phone = _normalizePhone(_phoneController.text.trim());
      if (phone == null) {
        setState(() {
          _error = 'Enter a valid 10-digit US number or E.164 (+...)';
          _sending = false;
        });
        return;
      }
      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // On Android, may auto-complete. Perform sign-in for a seamless flow.
          try {
            await auth.signInWithCredential(credential);
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pop(); // back to previous screen
            }
          } catch (e) {
            setState(() => _error = 'Auto-verification failed: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _error = e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() {
            _verificationId = verificationId;
          });
        },
      );
    } catch (e) {
      setState(() => _error = 'Failed to send code: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationId == null) {
      setState(() => _error = 'No verification in progress. Send code first.');
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    final auth = ref.read(firebaseAuthProvider);
    if (auth == null) {
      setState(() {
        _error = 'Auth not initialized';
        _verifying = false;
      });
      return;
    }
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _codeController.text.trim(),
      );
      await auth.signInWithCredential(credential);
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Invalid code');
    } catch (e) {
      setState(() => _error = 'Failed to verify code: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _error = null);
    try {
      await ref.read(authActionsProvider).signInAnonymously();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Anonymous sign-in failed');
    } catch (e) {
      setState(() => _error = 'Anonymous sign-in failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncUser = ref.watch(firebaseUserProvider);
    final isSignedIn = asyncUser.asData?.value != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign in'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Phone section
            Text(
              'Phone',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '555-555-0100',
                    ),
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Enter phone number';
                      final digits = t.replaceAll(RegExp(r'\\D'), '');
                      final looksUs10 = digits.length == 10;
                      final looksUs11 = digits.length == 11 && digits.startsWith('1');
                      final looksE164 = t.startsWith('+');
                      if (!(looksE164 || looksUs10 || looksUs11)) {
                        return 'Enter 10-digit US number or +countrycode number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sending
                              ? null
                              : () async {
                                  if (_formKey.currentState?.validate() ?? false) {
                                    await _sendCode();
                                  }
                                },
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sms_outlined),
                          label: const Text('Send code'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_codeSent) ...[
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'SMS code',
                        hintText: '6-digit code',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _verifying ? null : _verifyCode,
                            icon: _verifying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.verified_outlined),
                            label: const Text('Verify'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Guest section
            Text(
              'Guest',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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

            if (isSignedIn)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Signed in. You can close this page.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),

            const SizedBox(height: 24),
            Text(
              kIsWeb
                  ? 'reCAPTCHA may be shown by Firebase to verify phone sign-in on Web.'
                  : 'On Android, SMS auto-retrieval may complete automatically.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }
}
