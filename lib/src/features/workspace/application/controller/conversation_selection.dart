part of '../connection_workspace_controller.dart';

Future<void> _resumeWorkspaceConversation(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required String threadId,
}) async {
  final liveLaneId = controller._state.primaryLiveLaneIdForConnection(
    connectionId,
  );
  if (liveLaneId != null) {
    final previousBinding = controller._laneRoster.bindingForLaneId(liveLaneId);
    if (previousBinding == null) {
      return;
    }
    if (previousBinding.sessionController.sessionState.isBusy) {
      return;
    }

    final shouldReconnectTransport = controller._state
        .requiresTransportReconnect(connectionId);
    final nextBinding = await _loadWorkspaceLaneBinding(
      controller,
      connectionId: connectionId,
      laneId: liveLaneId,
    );
    if (controller._isDisposed) {
      nextBinding.dispose();
      return;
    }
    controller._laneRoster.putBinding(liveLaneId, nextBinding);
    controller._unregisterLiveBinding(liveLaneId);
    controller._registerLiveBinding(liveLaneId, nextBinding);
    final didNotifyStateChange = controller._applyState(
      controller._state.copyWith(
        selectedLaneId: liveLaneId,
        viewport: ConnectionWorkspaceViewport.liveLane,
        savedSettingsReconnectRequiredConnectionIds:
            _sanitizeWorkspaceReconnectRequiredIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                ...controller
                    ._state
                    .savedSettingsReconnectRequiredConnectionIds,
              }..remove(connectionId),
            ),
        transportReconnectRequiredLaneIds: shouldReconnectTransport
            ? controller._state.transportReconnectRequiredLaneIds
            : _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
                liveLaneIds: controller._state.liveLaneIds,
                transportReconnectRequiredLaneIds: <String>{
                  ...controller._state.transportReconnectRequiredLaneIds,
                }..remove(liveLaneId),
              ),
        transportRecoveryPhasesByLaneId: shouldReconnectTransport
            ? _sanitizeWorkspaceTransportRecoveryPhases(
                liveLaneIds: controller._state.liveLaneIds,
                transportRecoveryPhasesByLaneId:
                    <String, ConnectionWorkspaceTransportRecoveryPhase>{
                      ...controller._state.transportRecoveryPhasesByLaneId,
                      liveLaneId: ConnectionWorkspaceTransportRecoveryPhase
                          .reconnecting,
                    },
              )
            : _sanitizeWorkspaceTransportRecoveryPhases(
                liveLaneIds: controller._state.liveLaneIds,
                transportRecoveryPhasesByLaneId:
                    <String, ConnectionWorkspaceTransportRecoveryPhase>{
                      for (final entry
                          in controller
                              ._state
                              .transportRecoveryPhasesByLaneId
                              .entries)
                        if (entry.key != liveLaneId) entry.key: entry.value,
                    },
              ),
        liveReattachPhasesByLaneId: shouldReconnectTransport
            ? _sanitizeWorkspaceLiveReattachPhases(
                liveLaneIds: controller._state.liveLaneIds,
                liveReattachPhasesByLaneId:
                    <String, ConnectionWorkspaceLiveReattachPhase>{
                      ...controller._state.liveReattachPhasesByLaneId,
                      liveLaneId:
                          ConnectionWorkspaceLiveReattachPhase.reconnecting,
                    },
              )
            : _sanitizeWorkspaceLiveReattachPhases(
                liveLaneIds: controller._state.liveLaneIds,
                liveReattachPhasesByLaneId:
                    <String, ConnectionWorkspaceLiveReattachPhase>{
                      for (final entry
                          in controller
                              ._state
                              .liveReattachPhasesByLaneId
                              .entries)
                        if (entry.key != liveLaneId) entry.key: entry.value,
                    },
              ),
        recoveryDiagnosticsByLaneId: _sanitizeWorkspaceRecoveryDiagnostics(
          liveLaneIds: controller._state.liveLaneIds,
          recoveryDiagnosticsByLaneId:
              controller._state.recoveryDiagnosticsByLaneId,
        ),
      ),
    );
    previousBinding.dispose();
    if (!didNotifyStateChange) {
      controller._notifyBindingChange();
    }
    await nextBinding.sessionController.initialize();
    if (controller._isDisposed) {
      return;
    }
    await nextBinding.sessionController.selectConversationForResume(threadId);
    return;
  }

  await _instantiateWorkspaceConnection(controller, connectionId);
  if (controller._isDisposed) {
    return;
  }

  final laneId = controller._state.primaryLiveLaneIdForConnection(connectionId);
  if (laneId == null) {
    return;
  }
  final binding = controller._laneRoster.bindingForLaneId(laneId);
  if (binding == null) {
    return;
  }

  await binding.sessionController.selectConversationForResume(threadId);
}

({String? threadId, String draftText}) _preservedWorkspaceLaneState(
  ConnectionLaneBinding binding,
) {
  return (
    threadId: _normalizedWorkspaceThreadId(
      binding.sessionController.sessionState.currentThreadId ??
          binding.sessionController.sessionState.rootThreadId ??
          binding
              .sessionController
              .historicalConversationRestoreState
              ?.threadId,
    ),
    draftText: binding.composerDraftHost.draft.text,
  );
}

String? _normalizedWorkspaceThreadId(String? value) {
  final normalizedValue = value?.trim();
  if (normalizedValue == null || normalizedValue.isEmpty) {
    return null;
  }
  return normalizedValue;
}
