part of 'connection_workspace_controller.dart';

Future<void> _reconnectWorkspaceLane(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  final laneId = controller._state.primaryLiveLaneIdForConnection(
    normalizedConnectionId,
  );
  if (laneId == null ||
      !controller._state.requiresReconnect(normalizedConnectionId)) {
    return;
  }

  if (controller._state.requiresTransportReconnect(normalizedConnectionId)) {
    controller._beginRecoveryAttempt(
      laneId,
      startedAt: controller._now(),
      origin: ConnectionWorkspaceRecoveryOrigin.manualReconnect,
    );
  }
  await _reconnectWorkspaceConnection(controller, laneId);
}

Future<void> _disconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  final laneId = controller._state.primaryLiveLaneIdForConnection(
    normalizedConnectionId,
  );
  if (laneId == null) {
    return;
  }
  final binding = controller._laneRoster.bindingForLaneId(laneId);
  if (binding == null ||
      binding.sessionController.sessionState.isBusy ||
      !binding.agentAdapterClient.isConnected) {
    return;
  }

  controller._intentionalTransportDisconnectConnectionIds.add(laneId);
  try {
    await binding.agentAdapterClient.disconnect();
  } catch (_) {
    controller._intentionalTransportDisconnectConnectionIds.remove(laneId);
    rethrow;
  } finally {
    controller._intentionalTransportDisconnectConnectionIds.remove(laneId);
    if (!binding.agentAdapterClient.isConnected) {
      controller._clearTransportReconnectRequired(laneId);
      controller._clearLiveReattachPhase(laneId);
    }
  }
}

Future<void> _resumeWorkspaceConversationSelection(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required String threadId,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  final normalizedThreadId = threadId.trim();
  if (normalizedThreadId.isEmpty) {
    throw ArgumentError.value(
      threadId,
      'threadId',
      'Thread id must not be empty.',
    );
  }

  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  await _resumeWorkspaceConversation(
    controller,
    normalizedConnectionId,
    threadId: normalizedThreadId,
  );
}

Future<void> _instantiateWorkspaceLiveConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  if (controller._state.isConnectionLive(normalizedConnectionId)) {
    _selectWorkspaceConnection(controller, normalizedConnectionId);
    return;
  }

  await _instantiateWorkspaceConnection(controller, normalizedConnectionId);
}

void _selectWorkspaceLane(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  final normalizedLaneId = laneId.trim();
  if (normalizedLaneId.isEmpty ||
      !controller._state.isLaneLive(normalizedLaneId)) {
    return;
  }
  if (controller._state.selectedLaneId == normalizedLaneId &&
      controller._state.isShowingLiveLane) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      selectedLaneId: normalizedLaneId,
      viewport: ConnectionWorkspaceViewport.liveLane,
    ),
  );
}

void _selectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  final normalizedConnectionId = connectionId.trim();
  final laneId = controller._state.primaryLiveLaneIdForConnection(
    normalizedConnectionId,
  );
  if (normalizedConnectionId.isEmpty || laneId == null) {
    return;
  }
  _selectWorkspaceLane(controller, laneId);
}

void _showWorkspaceSavedConnections(ConnectionWorkspaceController controller) {
  if (controller._state.isShowingSavedConnections) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      viewport: ConnectionWorkspaceViewport.savedConnections,
    ),
  );
}

void _terminateWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  final normalizedConnectionId = connectionId.trim();
  final laneId = controller._state.primaryLiveLaneIdForConnection(
    normalizedConnectionId,
  );
  if (laneId == null) {
    return;
  }
  _terminateWorkspaceLane(controller, laneId);
}

void _terminateWorkspaceLane(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  final normalizedLaneId = laneId.trim();
  final binding = controller._laneRoster.bindingForLaneId(normalizedLaneId);
  if (binding == null) {
    return;
  }
  if (binding.sessionController.sessionState.isBusy) {
    return;
  }
  controller._laneRoster.removeBinding(normalizedLaneId);

  final terminationPlan = controller._laneRoster.planTerminationAfterRemoval(
    state: controller._state,
    removedLaneId: normalizedLaneId,
  );

  controller._unregisterLiveBinding(normalizedLaneId);
  binding.dispose();
  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      liveLanes: terminationPlan.liveLanes,
      selectedLaneId: terminationPlan.selectedLaneId,
      viewport: terminationPlan.viewport,
      clearSelectedLaneId: terminationPlan.selectedLaneId == null,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: terminationPlan.liveLanes
                .map((lane) => lane.connectionId)
                .toList(growable: false),
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredLaneIds:
          _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
            liveLaneIds: terminationPlan.liveLanes
                .map((lane) => lane.laneId)
                .toList(growable: false),
            transportReconnectRequiredLaneIds:
                controller._state.transportReconnectRequiredLaneIds,
          ),
      transportRecoveryPhasesByLaneId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            liveLaneIds: terminationPlan.liveLanes
                .map((lane) => lane.laneId)
                .toList(growable: false),
            transportRecoveryPhasesByLaneId:
                controller._state.transportRecoveryPhasesByLaneId,
          ),
      liveReattachPhasesByLaneId: _sanitizeWorkspaceLiveReattachPhases(
        liveLaneIds: terminationPlan.liveLanes
            .map((lane) => lane.laneId)
            .toList(growable: false),
        liveReattachPhasesByLaneId:
            controller._state.liveReattachPhasesByLaneId,
      ),
      recoveryDiagnosticsByLaneId: _sanitizeWorkspaceRecoveryDiagnostics(
        liveLaneIds: terminationPlan.liveLanes
            .map((lane) => lane.laneId)
            .toList(growable: false),
        recoveryDiagnosticsByLaneId:
            controller._state.recoveryDiagnosticsByLaneId,
      ),
    ),
  );
}
