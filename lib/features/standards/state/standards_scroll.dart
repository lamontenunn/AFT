import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persisted scroll offset for the Standards screen.
/// - Not autoDisposed so it survives route replacement.
/// - Stored as logical pixels from top.
final standardsScrollOffsetProvider = StateProvider<double>((ref) => 0.0);
