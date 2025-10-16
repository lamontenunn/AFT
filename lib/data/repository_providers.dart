import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aft_firebase_app/data/aft_repository.dart';
import 'package:aft_firebase_app/data/aft_repository_local.dart';

/// Bind the repository interface to a concrete implementation (local for now).
final aftRepositoryProvider = Provider<AftRepository>((ref) {
  return LocalAftRepository();
});
