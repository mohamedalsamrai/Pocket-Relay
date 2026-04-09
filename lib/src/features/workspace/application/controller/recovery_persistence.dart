part of '../connection_workspace_controller.dart';

ConnectionWorkspaceRecoveryState? _selectedWorkspaceRecoveryStateSnapshot(
  ConnectionWorkspaceController controller, {
  DateTime? backgroundedAt,
  ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
}) {
  final selectedConnectionId = controller._state.selectedConnectionId;
  if (selectedConnectionId == null ||
      !controller._state.isConnectionLive(selectedConnectionId)) {
    return null;
  }

  final binding = controller._laneRoster.bindingFor(selectedConnectionId);
  if (binding == null) {
    return null;
  }

  final diagnostics = controller._state.recoveryDiagnosticsFor(
    selectedConnectionId,
  );

  var selectedThreadId = _normalizedWorkspaceThreadId(
    binding.sessionController.sessionState.currentThreadId ??
        binding.sessionController.sessionState.rootThreadId ??
        binding.sessionController.historicalConversationRestoreState?.threadId,
  );
  final coldStartRecoveryInFlight =
      controller._state.requiresTransportReconnect(selectedConnectionId) &&
      diagnostics?.lastRecoveryOrigin ==
          ConnectionWorkspaceRecoveryOrigin.coldStart &&
      diagnostics?.lastRecoveryStartedAt != null &&
      diagnostics?.lastRecoveryCompletedAt == null;
  if (selectedThreadId == null &&
      coldStartRecoveryInFlight) {
    final latestRecoverySnapshot =
        controller._recoveryPersistenceController.latestSnapshot;
    selectedThreadId = _normalizedWorkspaceThreadId(
      latestRecoverySnapshot?.connectionId == selectedConnectionId
          ? latestRecoverySnapshot?.selectedThreadId
          : null,
    );
  }

  return ConnectionWorkspaceRecoveryState(
    connectionId: selectedConnectionId,
    selectedThreadId: selectedThreadId,
    draftText: binding.composerDraftHost.draft.text,
    backgroundedAt: backgroundedAt ?? diagnostics?.lastBackgroundedAt,
    backgroundedLifecycleState:
        backgroundedLifecycleState ??
        diagnostics?.lastBackgroundedLifecycleState,
  );
}
