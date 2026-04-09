part of '../connection_workspace_controller.dart';

void _setWorkspaceDeviceContinuityWarning(
  ConnectionWorkspaceController controller,
  WorkspaceDeviceContinuityWarningTarget target,
  PocketUserFacingError? warning,
) {
  _updateWorkspaceDeviceContinuityWarnings(
    controller,
    (current) => switch (target) {
      WorkspaceDeviceContinuityWarningTarget.foregroundService =>
        current.copyWith(
          foregroundServiceWarning: warning,
          clearForegroundServiceWarning: warning == null,
        ),
      WorkspaceDeviceContinuityWarningTarget.backgroundGrace =>
        current.copyWith(
          backgroundGraceWarning: warning,
          clearBackgroundGraceWarning: warning == null,
        ),
      WorkspaceDeviceContinuityWarningTarget.wakeLock => current.copyWith(
        wakeLockWarning: warning,
        clearWakeLockWarning: warning == null,
      ),
      WorkspaceDeviceContinuityWarningTarget.turnCompletionAlert =>
        current.copyWith(
          turnCompletionAlertWarning: warning,
          clearTurnCompletionAlertWarning: warning == null,
        ),
    },
  );
}

void _updateWorkspaceDeviceContinuityWarnings(
  ConnectionWorkspaceController controller,
  ConnectionWorkspaceDeviceContinuityWarnings Function(
    ConnectionWorkspaceDeviceContinuityWarnings current,
  )
  update,
) {
  if (controller._isDisposed) {
    return;
  }

  final currentWarnings = controller._state.deviceContinuityWarnings;
  final nextWarnings = update(currentWarnings);
  if (nextWarnings == currentWarnings) {
    return;
  }

  controller._applyStateWithoutRecoveryPersistence(
    controller._state.copyWith(deviceContinuityWarnings: nextWarnings),
  );
}
