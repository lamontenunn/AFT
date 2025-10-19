import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Minimal editing context to update an existing saved set in place.
class ScoreEditing {
  final String id;
  final DateTime createdAt;
  const ScoreEditing({required this.id, required this.createdAt});
}

/// Holds the current editing context, or null if not editing.
final editingSetProvider = StateProvider<ScoreEditing?>((ref) => null);
