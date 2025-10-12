import 'package:flutter/material.dart';

/// App domains represented in the top app bar segmented control.
enum Domain {
  general,
  combat,
}

extension DomainLabel on Domain {
  String get label {
    switch (this) {
      case Domain.general:
        return 'General';
      case Domain.combat:
        return 'Combat';
    }
  }
}

/// AppState holds global UI state that should persist across routes/screens.
class AppState extends ChangeNotifier {
  Domain _domain = Domain.general;

  Domain get domain => _domain;

  void setDomain(Domain value) {
    if (value == _domain) return;
    _domain = value;
    notifyListeners();
  }
}

/// InheritedNotifier wrapper to provide AppState down the tree without
/// introducing an external dependency.
class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.notifier!;
  }

  /// Read without establishing a dependency (won't rebuild on changes).
  static AppState read(BuildContext context) {
    final element =
        context.getElementForInheritedWidgetOfExactType<AppStateScope>();
    final widget = element?.widget as AppStateScope?;
    assert(widget != null, 'AppStateScope not found in context');
    return widget!.notifier!;
  }
}
