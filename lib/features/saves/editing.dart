import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;

/// Minimal editing context to update an existing saved set in place.
class ScoreEditing {
  final String id;
  final DateTime createdAt;
  const ScoreEditing({required this.id, required this.createdAt});
}

/// Holds the current editing context, or null if not editing.
final editingSetProvider =
    legacy.StateProvider<ScoreEditing?>((Ref ref) => null);
