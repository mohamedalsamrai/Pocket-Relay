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

  final binding = controller._liveBindingsByConnectionId[selectedConnectionId];
  if (binding == null) {
    return null;
  }

  final selectedThreadId = _normalizedWorkspaceThreadId(
    binding.sessionController.sessionState.currentThreadId ??
        binding.sessionController.sessionState.rootThreadId ??
        binding.sessionController.historicalConversationRestoreState?.threadId,
  );
  final diagnostics = controller._state.recoveryDiagnosticsFor(
    selectedConnectionId,
  );

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
