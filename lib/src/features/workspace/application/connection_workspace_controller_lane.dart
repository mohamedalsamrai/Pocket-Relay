part of 'connection_workspace_controller.dart';

Future<void> _reconnectWorkspaceLane(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  if (!controller._state.isConnectionLive(normalizedConnectionId) ||
      !controller._state.requiresReconnect(normalizedConnectionId)) {
    return;
  }

  if (controller._state.requiresTransportReconnect(normalizedConnectionId)) {
    controller._beginRecoveryAttempt(
      normalizedConnectionId,
      startedAt: controller._now(),
      origin: ConnectionWorkspaceRecoveryOrigin.manualReconnect,
    );
  }
  await _reconnectWorkspaceConnection(controller, normalizedConnectionId);
}

Future<void> _disconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  final binding = controller._laneRoster.bindingFor(normalizedConnectionId);
  if (binding == null ||
      binding.sessionController.sessionState.isBusy ||
      !binding.agentAdapterClient.isConnected) {
    return;
  }

  controller._intentionalTransportDisconnectConnectionIds.add(
    normalizedConnectionId,
  );
  try {
    await binding.agentAdapterClient.disconnect();
  } catch (_) {
    controller._intentionalTransportDisconnectConnectionIds.remove(
      normalizedConnectionId,
    );
    rethrow;
  } finally {
    controller._intentionalTransportDisconnectConnectionIds.remove(
      normalizedConnectionId,
    );
    if (!binding.agentAdapterClient.isConnected) {
      controller._clearTransportReconnectRequired(normalizedConnectionId);
      controller._clearLiveReattachPhase(normalizedConnectionId);
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

void _selectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  final normalizedConnectionId = connectionId.trim();
  if (normalizedConnectionId.isEmpty ||
      !controller._state.isConnectionLive(normalizedConnectionId)) {
    return;
  }
  if (controller._state.selectedConnectionId == normalizedConnectionId &&
      controller._state.isShowingLiveLane) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      selectedConnectionId: normalizedConnectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
    ),
  );
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
  final binding = controller._laneRoster.bindingFor(normalizedConnectionId);
  if (binding == null) {
    return;
  }
  if (binding.sessionController.sessionState.isBusy) {
    return;
  }
  controller._laneRoster.removeBinding(normalizedConnectionId);

  final terminationPlan = controller._laneRoster.planTerminationAfterRemoval(
    state: controller._state,
    removedConnectionId: normalizedConnectionId,
  );

  controller._unregisterLiveBinding(normalizedConnectionId);
  binding.dispose();
  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      liveConnectionIds: terminationPlan.liveConnectionIds,
      selectedConnectionId: terminationPlan.selectedConnectionId,
      viewport: terminationPlan.viewport,
      clearSelectedConnectionId: terminationPlan.selectedConnectionId == null,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: terminationPlan.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: terminationPlan.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.transportReconnectRequiredConnectionIds,
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: terminationPlan.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                controller._state.transportRecoveryPhasesByConnectionId,
          ),
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: controller._state.catalog,
        liveConnectionIds: terminationPlan.liveConnectionIds,
        liveReattachPhasesByConnectionId:
            controller._state.liveReattachPhasesByConnectionId,
      ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: controller._state.catalog,
        liveConnectionIds: terminationPlan.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
    ),
  );
}
