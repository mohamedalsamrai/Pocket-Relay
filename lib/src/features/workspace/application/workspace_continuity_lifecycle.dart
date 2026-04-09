import 'package:flutter/widgets.dart';

typedef WorkspaceContinuityLifecycleStateChanged =
    Future<void> Function(AppLifecycleState state);

abstract interface class WorkspaceContinuityLifecycleSink {
  Future<void> handleAppLifecycleStateChanged(AppLifecycleState state);
}

final class WorkspaceContinuityLifecycleCallbacks {
  const WorkspaceContinuityLifecycleCallbacks({
    required WorkspaceContinuityLifecycleSink sink,
  }) : _sink = sink;

  final WorkspaceContinuityLifecycleSink _sink;

  WorkspaceContinuityLifecycleStateChanged get appLifecycle {
    return _sink.handleAppLifecycleStateChanged;
  }
}
