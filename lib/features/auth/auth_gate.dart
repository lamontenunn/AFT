import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/auth/sign_in_page.dart';

/// AuthGate renders the appropriate screen depending on auth state:
/// - Loading: progress indicator
/// - Signed out: SignInPage
/// - Signed in: provided child
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(firebaseUserProvider);

    return asyncUser.when(
      data: (user) {
        if (user == null) {
          // Not signed in -> show Sign In/Sign Up first screen
          return const SignInPage();
        }
        // Signed in -> render the intended child
        return child;
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 28),
              const SizedBox(height: 8),
              Text('Failed to load auth state', style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
