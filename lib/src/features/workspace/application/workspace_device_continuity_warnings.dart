import 'package:pocket_relay/src/core/errors/pocket_error.dart';

typedef WorkspaceDeviceContinuityWarningChanged =
    void Function(PocketUserFacingError? warning);

enum WorkspaceDeviceContinuityWarningTarget {
  foregroundService,
  backgroundGrace,
  wakeLock,
  turnCompletionAlert,
}

abstract interface class WorkspaceDeviceContinuityWarningSink {
  void setDeviceContinuityWarning(
    WorkspaceDeviceContinuityWarningTarget target,
    PocketUserFacingError? warning,
  );
}

final class WorkspaceDeviceContinuityWarningCallbacks {
  const WorkspaceDeviceContinuityWarningCallbacks({
    required WorkspaceDeviceContinuityWarningSink sink,
  }) : _sink = sink;

  final WorkspaceDeviceContinuityWarningSink _sink;

  WorkspaceDeviceContinuityWarningChanged get foregroundService {
    return (warning) => _sink.setDeviceContinuityWarning(
      WorkspaceDeviceContinuityWarningTarget.foregroundService,
      warning,
    );
  }

  WorkspaceDeviceContinuityWarningChanged get backgroundGrace {
    return (warning) => _sink.setDeviceContinuityWarning(
      WorkspaceDeviceContinuityWarningTarget.backgroundGrace,
      warning,
    );
  }

  WorkspaceDeviceContinuityWarningChanged get wakeLock {
    return (warning) => _sink.setDeviceContinuityWarning(
      WorkspaceDeviceContinuityWarningTarget.wakeLock,
      warning,
    );
  }

  WorkspaceDeviceContinuityWarningChanged get turnCompletionAlert {
    return (warning) => _sink.setDeviceContinuityWarning(
      WorkspaceDeviceContinuityWarningTarget.turnCompletionAlert,
      warning,
    );
  }
}
