import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aft_firebase_app/features/auth/providers.dart';
import 'package:aft_firebase_app/features/saves/guest_migration.dart';
import 'package:aft_firebase_app/features/saves/editing.dart';
import 'package:aft_firebase_app/data/repository_providers.dart';
import 'package:aft_firebase_app/features/proctor/state/providers.dart';
import 'package:aft_firebase_app/features/proctor/state/proctor_inputs.dart';
import 'package:aft_firebase_app/features/proctor/state/proctor_ui_state.dart';
import 'package:aft_firebase_app/features/proctor/timing/timer_controller.dart';

/// Auth transition listener for migration and user-scoped state resets.
final authSideEffectsProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(
    firebaseUserProvider,
    (previous, next) {
      final prevUser = previous?.asData?.value;
      final user = next.asData?.value;

      if (prevUser?.uid != user?.uid) {
        ref.read(editingSetProvider.notifier).clearEditing();
        ref.invalidate(aftRepositoryProvider);
        ref.invalidate(proctorSessionProvider);
        ref.invalidate(proctorInputsStateProvider);
        ref.invalidate(proctorTimingProvider);
        ref.invalidate(proctorProfileProvider);
        ref.invalidate(proctorUiProvider);
      }

      if (user == null) return;

      if (user.isAnonymous) {
        ref.read(guestMigrationProvider).trackGuestUser(user.uid);
        return;
      }

      final prevWasAnon = prevUser?.isAnonymous ?? false;
      if (prevWasAnon || prevUser?.uid != user.uid) {
        ref.read(guestMigrationProvider).maybeMigrateGuestTo(user.uid);
      }
    },
    fireImmediately: true,
  );
});
