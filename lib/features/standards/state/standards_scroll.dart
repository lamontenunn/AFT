import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' as legacy;

/// Persisted scroll offset for the Standards screen.
/// - Not autoDisposed so it survives route replacement.
/// - Stored as logical pixels from top.
final standardsScrollOffsetProvider =
    legacy.StateProvider<double>((Ref ref) => 0.0);
