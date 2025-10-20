import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/shell/aft_scaffold.dart';
import 'package:aft_firebase_app/features/home/home_screen.dart';
import 'package:aft_firebase_app/features/auth/sign_in_page.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AuthGate renders the appropriate first screen depending on auth state:
/// - Loading: progress indicator
/// - Signed out: SignInPage
/// - Signed in: AftScaffold + FeatureHomeScreen
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(firebaseUserProvider);

    return asyncUser.when(
      data: (user) {
        if (user == null) {
          // Not signed in -> show Sign In/Sign Up first screen
          return const SignInPage();
        }
        // If signed-in non-anonymous, migrate any guest data once for this uid.
        if (!(user as User).isAnonymous) {
          // Fire and forget; guarded by SharedPreferences flag internally.
          Future.microtask(() => GuestMigration.maybeMigrateGuestTo(user.uid));
        }
        // Signed in -> main app shell
        return const AftScaffold(child: FeatureHomeScreen());
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
