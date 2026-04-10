part of '../connection_workspace_controller.dart';

ConnectionWorkspaceState _withWorkspaceTransportReconnectStaged(
  ConnectionWorkspaceState state,
  String connectionId,
) {
  return state.copyWith(
    transportReconnectRequiredConnectionIds:
        _sanitizeWorkspaceReconnectRequiredIds(
          catalog: state.catalog,
          liveConnectionIds: state.liveConnectionIds,
          reconnectRequiredConnectionIds: <String>{
            ...state.transportReconnectRequiredConnectionIds,
            connectionId,
          },
        ),
    transportRecoveryPhasesByConnectionId:
        _sanitizeWorkspaceTransportRecoveryPhases(
          catalog: state.catalog,
          liveConnectionIds: state.liveConnectionIds,
          transportRecoveryPhasesByConnectionId:
              <String, ConnectionWorkspaceTransportRecoveryPhase>{
                ...state.transportRecoveryPhasesByConnectionId,
                connectionId:
                    ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
              },
        ),
    liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
      catalog: state.catalog,
      liveConnectionIds: state.liveConnectionIds,
      liveReattachPhasesByConnectionId:
          <String, ConnectionWorkspaceLiveReattachPhase>{
            ...state.liveReattachPhasesByConnectionId,
            connectionId: ConnectionWorkspaceLiveReattachPhase.reconnecting,
          },
    ),
    recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
      catalog: state.catalog,
      liveConnectionIds: state.liveConnectionIds,
      recoveryDiagnosticsByConnectionId:
          state.recoveryDiagnosticsByConnectionId,
    ),
  );
}

ConnectionWorkspaceState _withWorkspaceTransportReconnectCleared(
  ConnectionWorkspaceState state,
  String connectionId,
) {
  return state.copyWith(
    transportReconnectRequiredConnectionIds:
        _sanitizeWorkspaceReconnectRequiredIds(
          catalog: state.catalog,
          liveConnectionIds: state.liveConnectionIds,
          reconnectRequiredConnectionIds: <String>{
            ...state.transportReconnectRequiredConnectionIds,
          }..remove(connectionId),
        ),
    transportRecoveryPhasesByConnectionId:
        _sanitizeWorkspaceTransportRecoveryPhases(
          catalog: state.catalog,
          liveConnectionIds: state.liveConnectionIds,
          transportRecoveryPhasesByConnectionId:
              <String, ConnectionWorkspaceTransportRecoveryPhase>{
                for (final entry
                    in state.transportRecoveryPhasesByConnectionId.entries)
                  if (entry.key != connectionId) entry.key: entry.value,
              },
        ),
    liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
      catalog: state.catalog,
      liveConnectionIds: state.liveConnectionIds,
      liveReattachPhasesByConnectionId:
          <String, ConnectionWorkspaceLiveReattachPhase>{
            for (final entry in state.liveReattachPhasesByConnectionId.entries)
              if (entry.key != connectionId) entry.key: entry.value,
          },
    ),
    recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
      catalog: state.catalog,
      liveConnectionIds: state.liveConnectionIds,
      recoveryDiagnosticsByConnectionId:
          state.recoveryDiagnosticsByConnectionId,
    ),
  );
}

void _clearWorkspaceTransportReconnectState(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    _withWorkspaceTransportReconnectCleared(controller._state, connectionId),
  );
}

void _finalizeWorkspaceRecoveredTransportState(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required DateTime completedAt,
  required bool recordRecoveryOutcome,
}) {
  _clearWorkspaceTransportReconnectState(controller, connectionId);
  if (!recordRecoveryOutcome || controller._isDisposed) {
    return;
  }

  controller._completeRecoveryAttempt(
    connectionId,
    completedAt: completedAt,
    outcome: ConnectionWorkspaceRecoveryOutcome.transportRestored,
  );
}

void _clearWorkspaceLiveReattachPhase(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  if (controller._isDisposed ||
      controller._state.liveReattachPhaseFor(connectionId) == null) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: controller._state.catalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        liveReattachPhasesByConnectionId:
            <String, ConnectionWorkspaceLiveReattachPhase>{
              for (final entry
                  in controller._state.liveReattachPhasesByConnectionId.entries)
                if (entry.key != connectionId) entry.key: entry.value,
            },
      ),
    ),
  );
}

void _clearWorkspaceTurnLivenessAssessment(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  final currentAssessment = controller._state.turnLivenessAssessmentFor(
    connectionId,
  );
  if (controller._isDisposed || currentAssessment == null) {
    return;
  }

  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(clearLastTurnLivenessAssessment: true),
  );
}

void _setWorkspaceTurnLivenessAssessment(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionWorkspaceTurnLivenessAssessment assessment,
) {
  if (controller._isDisposed ||
      !controller._state.isConnectionLive(connectionId) ||
      controller._state.turnLivenessAssessmentFor(connectionId) == assessment) {
    return;
  }

  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(lastTurnLivenessAssessment: assessment),
  );
}

void _setWorkspaceLiveReattachPhase(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionWorkspaceLiveReattachPhase phase,
) {
  if (controller._isDisposed ||
      !controller._state.isConnectionLive(connectionId)) {
    return;
  }

  if (controller._state.liveReattachPhaseFor(connectionId) == phase) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: controller._state.catalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        liveReattachPhasesByConnectionId:
            <String, ConnectionWorkspaceLiveReattachPhase>{
              ...controller._state.liveReattachPhasesByConnectionId,
              connectionId: phase,
            },
      ),
    ),
  );
}

void _markWorkspaceTransportReconnectRequired(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  if (controller._isDisposed ||
      !controller._state.isConnectionLive(connectionId) ||
      controller._state.requiresTransportReconnect(connectionId)) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              ...controller._state.transportReconnectRequiredConnectionIds,
              connectionId,
            },
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  ...controller._state.transportRecoveryPhasesByConnectionId,
                  connectionId: ConnectionWorkspaceTransportRecoveryPhase.lost,
                },
          ),
    ),
  );
}

void _clearWorkspaceTransportReconnectRequired(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  if (controller._isDisposed ||
      !controller._state.requiresTransportReconnect(connectionId)) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              ...controller._state.transportReconnectRequiredConnectionIds,
            }..remove(connectionId),
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  for (final entry
                      in controller
                          ._state
                          .transportRecoveryPhasesByConnectionId
                          .entries)
                    if (entry.key != connectionId) entry.key: entry.value,
                },
          ),
    ),
  );
}

void _setWorkspaceTransportRecoveryPhase(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionWorkspaceTransportRecoveryPhase phase,
) {
  if (controller._isDisposed ||
      !controller._state.isConnectionLive(connectionId)) {
    return;
  }

  if (controller._state.transportRecoveryPhaseFor(connectionId) == phase) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  ...controller._state.transportRecoveryPhasesByConnectionId,
                  connectionId: phase,
                },
          ),
    ),
  );
}

void _recordWorkspaceLifecycleBackgroundSnapshot(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required DateTime occurredAt,
  required ConnectionWorkspaceBackgroundLifecycleState lifecycleState,
}) {
  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(
      lastBackgroundedAt: occurredAt,
      lastBackgroundedLifecycleState: lifecycleState,
    ),
    enqueueRecoveryPersistence: false,
  );
}

void _recordWorkspaceLifecycleResume(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required DateTime occurredAt,
}) {
  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(
      lastResumedAt: occurredAt,
      clearLastBackgroundedLifecycleState: true,
    ),
    enqueueRecoveryPersistence: true,
  );
}

void _recordWorkspaceTransportLoss(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required DateTime occurredAt,
  required ConnectionWorkspaceTransportLossReason reason,
}) {
  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(
      lastTransportLossAt: occurredAt,
      lastTransportLossReason: reason,
    ),
  );
}

void _recordWorkspaceFallbackTransportConnectFailure(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required DateTime occurredAt,
  required Object? error,
}) {
  final diagnostics = controller._state.recoveryDiagnosticsFor(connectionId);
  final lastRecoveryStartedAt = diagnostics?.lastRecoveryStartedAt;
  final lastTransportLossAt = diagnostics?.lastTransportLossAt;
  if (lastRecoveryStartedAt != null &&
      lastTransportLossAt != null &&
      !lastTransportLossAt.isBefore(lastRecoveryStartedAt)) {
    return;
  }

  controller._recordTransportLoss(
    connectionId,
    occurredAt: occurredAt,
    reason: ConnectionWorkspaceTransportLossReason.connectFailed,
  );
  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(
      lastTransportFailureDetail: PocketErrorDetailFormatter.normalize(error),
    ),
  );
}

void _recordWorkspaceLiveReattachFailure(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required Object? error,
}) {
  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(
      lastLiveReattachFailureDetail: PocketErrorDetailFormatter.normalize(
        error,
      ),
    ),
  );
}

void _beginWorkspaceRecoveryAttempt(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required DateTime startedAt,
  required ConnectionWorkspaceRecoveryOrigin origin,
}) {
  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(
      lastRecoveryOrigin: origin,
      lastRecoveryStartedAt: startedAt,
      clearLastTransportFailureDetail: true,
      clearLastLiveReattachFailureDetail: true,
      clearLastRecoveryCompletedAt: true,
      clearLastRecoveryOutcome: true,
      clearLastTurnLivenessAssessment: true,
    ),
  );
}

void _completeWorkspaceRecoveryAttempt(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required DateTime completedAt,
  required ConnectionWorkspaceRecoveryOutcome outcome,
}) {
  controller._updateRecoveryDiagnostics(
    connectionId,
    (current) => current.copyWith(
      lastRecoveryCompletedAt: completedAt,
      lastRecoveryOutcome: outcome,
    ),
  );
}

void _completeWorkspaceConversationRecoveryAttempt(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionLaneBinding binding, {
  required DateTime completedAt,
}) {
  final restorePhase =
      binding.sessionController.historicalConversationRestoreState?.phase;
  final outcome = switch (restorePhase) {
    ChatHistoricalConversationRestorePhase.unavailable =>
      ConnectionWorkspaceRecoveryOutcome.conversationUnavailable,
    ChatHistoricalConversationRestorePhase.failed =>
      ConnectionWorkspaceRecoveryOutcome.conversationRestoreFailed,
    _ => ConnectionWorkspaceRecoveryOutcome.conversationRestored,
  };
  controller._completeRecoveryAttempt(
    connectionId,
    completedAt: completedAt,
    outcome: outcome,
  );
}

void _updateWorkspaceRecoveryDiagnostics(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionWorkspaceRecoveryDiagnostics Function(
    ConnectionWorkspaceRecoveryDiagnostics current,
  )
  update, {
  required bool enqueueRecoveryPersistence,
}) {
  if (controller._isDisposed ||
      !controller._state.isConnectionLive(connectionId)) {
    return;
  }

  final currentDiagnostics =
      controller._state.recoveryDiagnosticsFor(connectionId) ??
      const ConnectionWorkspaceRecoveryDiagnostics();
  final nextDiagnostics = update(currentDiagnostics);
  if (nextDiagnostics == currentDiagnostics) {
    return;
  }

  final nextState = controller._state.copyWith(
    recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
      catalog: controller._state.catalog,
      liveConnectionIds: controller._state.liveConnectionIds,
      recoveryDiagnosticsByConnectionId:
          <String, ConnectionWorkspaceRecoveryDiagnostics>{
            ...controller._state.recoveryDiagnosticsByConnectionId,
            connectionId: nextDiagnostics,
          },
    ),
  );
  if (enqueueRecoveryPersistence) {
    controller._applyState(nextState);
    return;
  }
  controller._applyStateWithoutRecoveryPersistence(nextState);
}
