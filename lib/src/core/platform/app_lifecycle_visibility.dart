import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

typedef AppLifecycleVisibilityWidgetBuilder =
    Widget Function(
      BuildContext context,
      ValueListenable<AppLifecycleVisibility> visibilityListenable,
    );

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

class AppLifecycleVisibilityBuilder extends StatefulWidget {
  const AppLifecycleVisibilityBuilder({super.key, required this.builder});

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
