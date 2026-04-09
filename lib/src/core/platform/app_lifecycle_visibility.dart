import 'package:flutter/widgets.dart';

/// App visibility projected from Flutter's lifecycle states.
enum AppLifecycleVisibility {
  /// The app is active enough for foreground-only work.
  foreground,

  /// The app is not foreground visible but the process may still be alive.
  background,

  /// The Flutter view has detached from the host platform.
  detached;

  /// Whether this visibility should be treated as foreground-visible.
  bool get isForegroundVisible => this == AppLifecycleVisibility.foreground;

  /// Whether this visibility should be treated as not foreground-visible.
  bool get isNotForegroundVisible => !isForegroundVisible;
}

/// Projects a Flutter [AppLifecycleState] into Pocket Relay visibility.
AppLifecycleVisibility appLifecycleVisibilityForState(
  AppLifecycleState? state,
) {
  switch (state) {
    case null:
    case AppLifecycleState.resumed:
      return AppLifecycleVisibility.foreground;
    case AppLifecycleState.inactive:
    case AppLifecycleState.hidden:
    case AppLifecycleState.paused:
      return AppLifecycleVisibility.background;
    case AppLifecycleState.detached:
      return AppLifecycleVisibility.detached;
  }
}

/// Returns whether [state] projects to foreground-visible app lifecycle.
bool appLifecycleStateIsForegroundVisible(AppLifecycleState? state) {
  return appLifecycleVisibilityForState(state).isForegroundVisible;
}

/// Returns whether [state] projects to non-foreground app lifecycle.
bool appLifecycleStateIsNotForegroundVisible(AppLifecycleState? state) {
  return appLifecycleVisibilityForState(state).isNotForegroundVisible;
}
