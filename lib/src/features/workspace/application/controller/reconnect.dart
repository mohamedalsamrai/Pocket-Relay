part of '../connection_workspace_controller.dart';

Future<void> _reconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final previousBinding = controller._laneRoster.bindingFor(connectionId);
  if (previousBinding == null) {
    return;
  }
  if (previousBinding.sessionController.sessionState.isBusy) {
    return;
  }

  final reconnectRequirement = controller._state.reconnectRequirementFor(
    connectionId,
  );
  if (reconnectRequirement == null) {
    return;
  }
  final shouldReconnectTransport =
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.transport ||
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings;
  final shouldReplaceBinding =
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.savedSettings ||
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings;
  final preservedLaneState = _preservedWorkspaceLaneState(previousBinding);

  if (!shouldReplaceBinding) {
    if (!shouldReconnectTransport) {
      return;
    }
    controller._applyState(
      _withWorkspaceTransportReconnectStaged(controller._state, connectionId),
    );

    await _attemptWorkspaceTransportReconnect(
      controller,
      connectionId,
      previousBinding,
      threadId: preservedLaneState.threadId,
      hadVisibleConversationState:
          _workspaceLaneHasVisibleLiveConversationState(previousBinding),
    );
    return;
  }

  final nextBinding = await _loadWorkspaceLaneBinding(
    controller,
    connectionId,
    initialDraftText: preservedLaneState.draftText,
  );
  if (controller._isDisposed) {
    nextBinding.dispose();
    return;
  }

  controller._laneRoster.putBinding(connectionId, nextBinding);
  controller._unregisterLiveBinding(connectionId);
  controller._registerLiveBinding(connectionId, nextBinding);
  previousBinding.dispose();
  final reconnectStateBase = controller._state.copyWith(
    savedSettingsReconnectRequiredConnectionIds:
        _sanitizeWorkspaceReconnectRequiredIds(
          catalog: controller._state.catalog,
          liveConnectionIds: controller._state.liveConnectionIds,
          reconnectRequiredConnectionIds: <String>{
            ...controller._state.savedSettingsReconnectRequiredConnectionIds,
          }..remove(connectionId),
        ),
  );
  controller._applyState(
    shouldReconnectTransport
        ? _withWorkspaceTransportReconnectStaged(
            reconnectStateBase,
            connectionId,
          )
        : _withWorkspaceTransportReconnectCleared(
            reconnectStateBase,
            connectionId,
          ),
  );
  await nextBinding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
  if (shouldReconnectTransport) {
    await _attemptWorkspaceTransportReconnect(
      controller,
      connectionId,
      nextBinding,
      threadId: preservedLaneState.threadId,
      hadVisibleConversationState: false,
    );
    return;
  }
  if (preservedLaneState.threadId != null) {
    await nextBinding.sessionController.selectConversationForResume(
      preservedLaneState.threadId!,
    );
    if (!controller._isDisposed) {
      controller._completeConversationRecoveryAttempt(
        connectionId,
        nextBinding,
        completedAt: controller._now(),
      );
    }
    return;
  }
}
