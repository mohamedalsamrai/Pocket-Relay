import 'package:flutter/widgets.dart';

enum AppLifecycleVisibility {
  foreground,
  background,
  detached;

  bool get isForegroundVisible => this == AppLifecycleVisibility.foreground;

  bool get isNotForegroundVisible => !isForegroundVisible;
}

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

bool appLifecycleStateIsForegroundVisible(AppLifecycleState? state) {
  return appLifecycleVisibilityForState(state).isForegroundVisible;
}

bool appLifecycleStateIsNotForegroundVisible(AppLifecycleState? state) {
  return appLifecycleVisibilityForState(state).isNotForegroundVisible;
}
