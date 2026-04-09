import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Builds widgets from the shared app lifecycle visibility listenable.
typedef AppLifecycleVisibilityWidgetBuilder =
    Widget Function(
      BuildContext context,
      ValueListenable<AppLifecycleVisibility> visibilityListenable,
    );

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

/// Publishes app lifecycle visibility to descendants through a listenable.
class AppLifecycleVisibilityBuilder extends StatefulWidget {
  const AppLifecycleVisibilityBuilder({super.key, required this.builder});

  /// Builds the child tree with the current app lifecycle visibility listenable.
  final AppLifecycleVisibilityWidgetBuilder builder;

  @override
  State<AppLifecycleVisibilityBuilder> createState() =>
      _AppLifecycleVisibilityBuilderState();
}

class _AppLifecycleVisibilityBuilderState
    extends State<AppLifecycleVisibilityBuilder>
    with WidgetsBindingObserver {
  late final ValueNotifier<AppLifecycleVisibility> _visibility;

  @override
  void initState() {
    super.initState();
    _visibility = ValueNotifier<AppLifecycleVisibility>(
      appLifecycleVisibilityForState(WidgetsBinding.instance.lifecycleState),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final nextVisibility = appLifecycleVisibilityForState(state);
    if (nextVisibility == _visibility.value) {
      return;
    }
    _visibility.value = nextVisibility;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _visibility);
  }
}
