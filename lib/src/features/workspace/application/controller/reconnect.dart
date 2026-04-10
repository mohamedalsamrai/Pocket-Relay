part of '../connection_workspace_controller.dart';

Future<void> _reconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String laneId,
) async {
  final previousBinding = controller._laneRoster.bindingForLaneId(laneId);
  if (previousBinding == null) {
    return;
  }
  if (previousBinding.sessionController.sessionState.isBusy) {
    return;
  }

  final reconnectRequirement = controller._state.reconnectRequirementFor(
    previousBinding.connectionId,
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
      _withWorkspaceTransportReconnectStaged(controller._state, laneId),
    );

    await _attemptWorkspaceTransportReconnect(
      controller,
      laneId,
      previousBinding,
      threadId: preservedLaneState.threadId,
      hadVisibleConversationState:
          _workspaceLaneHasVisibleLiveConversationState(previousBinding),
    );
    return;
  }

  final nextBinding = await _loadWorkspaceLaneBinding(
    controller,
    connectionId: previousBinding.connectionId,
    laneId: laneId,
    initialDraftText: preservedLaneState.draftText,
  );
  if (controller._isDisposed) {
    nextBinding.dispose();
    return;
  }

  controller._laneRoster.putBinding(laneId, nextBinding);
  controller._unregisterLiveBinding(laneId);
  controller._registerLiveBinding(laneId, nextBinding);
  previousBinding.dispose();
  final reconnectStateBase = controller._state.copyWith(
    savedSettingsReconnectRequiredConnectionIds:
        _sanitizeWorkspaceReconnectRequiredIds(
          catalog: controller._state.catalog,
          liveConnectionIds: controller._state.liveConnectionIds,
          reconnectRequiredConnectionIds: <String>{
            ...controller._state.savedSettingsReconnectRequiredConnectionIds,
          }..remove(previousBinding.connectionId),
        ),
  );
  controller._applyState(
    shouldReconnectTransport
        ? _withWorkspaceTransportReconnectStaged(reconnectStateBase, laneId)
        : _withWorkspaceTransportReconnectCleared(reconnectStateBase, laneId),
  );
  await nextBinding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
  if (shouldReconnectTransport) {
    await _attemptWorkspaceTransportReconnect(
      controller,
      laneId,
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
        laneId,
        nextBinding,
        completedAt: controller._now(),
      );
    }
    return;
  }
}
