import 'package:pocket_relay/src/features/workspace/application/workspace_continuity_lifecycle.dart';

import 'controller/controller_test_support.dart';

void main() {
  test(
    'continuity lifecycle callbacks forward app lifecycle states to sink',
    () async {
      final sink = _RecordingLifecycleSink();
      final callbacks = WorkspaceContinuityLifecycleCallbacks(sink: sink);

      await callbacks.appLifecycle(AppLifecycleState.paused);

      expect(sink.states, <AppLifecycleState>[AppLifecycleState.paused]);
    },
  );
}

final class _RecordingLifecycleSink
    implements WorkspaceContinuityLifecycleSink {
  final states = <AppLifecycleState>[];

  @override
  Future<void> handleAppLifecycleStateChanged(AppLifecycleState state) async {
    states.add(state);
  }
}
