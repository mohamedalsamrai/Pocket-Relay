part of '../connection_workspace_controller.dart';

ConnectionWorkspaceRecoveryState? _selectedWorkspaceRecoveryStateSnapshot(
  ConnectionWorkspaceController controller, {
  DateTime? backgroundedAt,
  ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
}) {
  final selectedLaneId = controller._state.selectedLaneId;
  if (selectedLaneId == null || !controller._state.isLaneLive(selectedLaneId)) {
    return null;
  }

  final binding = controller._laneRoster.bindingForLaneId(selectedLaneId);
  if (binding == null) {
    return null;
  }

  final diagnostics = controller._state.recoveryDiagnosticsForLane(
    selectedLaneId,
  );
  final backgroundedLifecycleStateFromDiagnostics =
      diagnostics?.lastBackgroundedLifecycleState;
  final backgroundedAtFromDiagnostics =
      backgroundedLifecycleStateFromDiagnostics == null
      ? null
      : diagnostics?.lastBackgroundedAt;

  var selectedThreadId = _normalizedWorkspaceThreadId(
    binding.sessionController.sessionState.currentThreadId ??
        binding.sessionController.sessionState.rootThreadId ??
        binding.sessionController.historicalConversationRestoreState?.threadId,
  );
  final shouldRetainColdStartRecoveryThread =
      controller._state.requiresTransportReconnectForLane(selectedLaneId) &&
      diagnostics?.lastRecoveryOrigin ==
          ConnectionWorkspaceRecoveryOrigin.coldStart &&
      !binding.sessionController.suppressesTrackedThreadReuse &&
      diagnostics?.lastRecoveryStartedAt != null;
  if (selectedThreadId == null && shouldRetainColdStartRecoveryThread) {
    final latestRecoverySnapshot =
        controller._recoveryPersistenceController.latestSnapshot;
    selectedThreadId = _normalizedWorkspaceThreadId(
      latestRecoverySnapshot?.connectionId == binding.connectionId
          ? latestRecoverySnapshot?.selectedThreadId
          : null,
    );
  }

  return ConnectionWorkspaceRecoveryState(
    connectionId: binding.connectionId,
    selectedThreadId: selectedThreadId,
    draftText: binding.composerDraftHost.draft.text,
    backgroundedAt: backgroundedAt ?? backgroundedAtFromDiagnostics,
    backgroundedLifecycleState:
        backgroundedLifecycleState ?? backgroundedLifecycleStateFromDiagnostics,
  );
}
