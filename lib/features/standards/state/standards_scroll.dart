import 'package:flutter_riverpod/flutter_riverpod.dart';

class StandardsScrollOffsetNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
}

/// Persisted scroll offset for the Standards screen.
/// - Not autoDisposed so it survives route replacement.
/// - Stored as logical pixels from top.
final standardsScrollOffsetProvider =
    NotifierProvider<StandardsScrollOffsetNotifier, double>(
        StandardsScrollOffsetNotifier.new);
