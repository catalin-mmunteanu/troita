import 'package:flutter/widgets.dart';

import 'app_state.dart';

/// Plain [InheritedNotifier] rather than a state-management package — the app
/// has one store, and a dependency for that would be noise.
///
/// Lives here rather than in main.dart so feature files don't have to import
/// the entrypoint to reach the store.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({required AppState state, required super.child, super.key})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above this widget');
    return scope!.notifier!;
  }
}
