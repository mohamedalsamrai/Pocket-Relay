part of '../connection_workspace_controller.dart';

ConnectionWorkspaceState _withWorkspaceTransportReconnectStaged(
  ConnectionWorkspaceState state,
  String laneId,
) {
  final liveLaneIds = state.liveLaneIds;
  return state.copyWith(
    transportReconnectRequiredLaneIds:
        _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
          liveLaneIds: liveLaneIds,
          transportReconnectRequiredLaneIds: <String>{
            ...state.transportReconnectRequiredLaneIds,
            laneId,
          },
        ),
    transportRecoveryPhasesByLaneId: _sanitizeWorkspaceTransportRecoveryPhases(
      liveLaneIds: liveLaneIds,
      transportRecoveryPhasesByLaneId:
          <String, ConnectionWorkspaceTransportRecoveryPhase>{
            ...state.transportRecoveryPhasesByLaneId,
            laneId: ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
          },
    ),
    liveReattachPhasesByLaneId: _sanitizeWorkspaceLiveReattachPhases(
      liveLaneIds: liveLaneIds,
      liveReattachPhasesByLaneId:
          <String, ConnectionWorkspaceLiveReattachPhase>{
            ...state.liveReattachPhasesByLaneId,
            laneId: ConnectionWorkspaceLiveReattachPhase.reconnecting,
          },
    ),
    recoveryDiagnosticsByLaneId: _sanitizeWorkspaceRecoveryDiagnostics(
      liveLaneIds: liveLaneIds,
      recoveryDiagnosticsByLaneId: state.recoveryDiagnosticsByLaneId,
    ),
  );
}

ConnectionWorkspaceState _withWorkspaceTransportReconnectCleared(
  ConnectionWorkspaceState state,
  String laneId,
) {
  final liveLaneIds = state.liveLaneIds;
  return state.copyWith(
    transportReconnectRequiredLaneIds:
        _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
          liveLaneIds: liveLaneIds,
          transportReconnectRequiredLaneIds: <String>{
            ...state.transportReconnectRequiredLaneIds,
          }..remove(laneId),
        ),
    transportRecoveryPhasesByLaneId: _sanitizeWorkspaceTransportRecoveryPhases(
      liveLaneIds: liveLaneIds,
      transportRecoveryPhasesByLaneId:
          <String, ConnectionWorkspaceTransportRecoveryPhase>{
            for (final entry in state.transportRecoveryPhasesByLaneId.entries)
              if (entry.key != laneId) entry.key: entry.value,
          },
    ),
    liveReattachPhasesByLaneId: _sanitizeWorkspaceLiveReattachPhases(
      liveLaneIds: liveLaneIds,
      liveReattachPhasesByLaneId:
          <String, ConnectionWorkspaceLiveReattachPhase>{
            for (final entry in state.liveReattachPhasesByLaneId.entries)
              if (entry.key != laneId) entry.key: entry.value,
          },
    ),
    recoveryDiagnosticsByLaneId: _sanitizeWorkspaceRecoveryDiagnostics(
      liveLaneIds: liveLaneIds,
      recoveryDiagnosticsByLaneId: state.recoveryDiagnosticsByLaneId,
    ),
  );
}

void _clearWorkspaceTransportReconnectState(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    _withWorkspaceTransportReconnectCleared(controller._state, laneId),
  );
}

void _finalizeWorkspaceRecoveredTransportState(
  ConnectionWorkspaceController controller,
  String laneId, {
  required DateTime completedAt,
  required bool recordRecoveryOutcome,
}) {
  _clearWorkspaceTransportReconnectState(controller, laneId);
  if (!recordRecoveryOutcome || controller._isDisposed) {
    return;
  }

  controller._completeRecoveryAttempt(
    laneId,
    completedAt: completedAt,
    outcome: ConnectionWorkspaceRecoveryOutcome.transportRestored,
  );
}

void _clearWorkspaceLiveReattachPhase(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  if (controller._isDisposed ||
      controller._state.liveReattachPhaseForLane(laneId) == null) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      liveReattachPhasesByLaneId: _sanitizeWorkspaceLiveReattachPhases(
        liveLaneIds: controller._state.liveLaneIds,
        liveReattachPhasesByLaneId:
            <String, ConnectionWorkspaceLiveReattachPhase>{
              for (final entry
                  in controller._state.liveReattachPhasesByLaneId.entries)
                if (entry.key != laneId) entry.key: entry.value,
            },
      ),
    ),
  );
}

void _clearWorkspaceTurnLivenessAssessment(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  final currentAssessment = controller._state.turnLivenessAssessmentForLane(
    laneId,
  );
  if (controller._isDisposed || currentAssessment == null) {
    return;
  }

  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(clearLastTurnLivenessAssessment: true),
  );
}

void _setWorkspaceTurnLivenessAssessment(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionWorkspaceTurnLivenessAssessment assessment,
) {
  if (controller._isDisposed ||
      !controller._state.isLaneLive(laneId) ||
      controller._state.turnLivenessAssessmentForLane(laneId) == assessment) {
    return;
  }

  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(lastTurnLivenessAssessment: assessment),
  );
}

void _setWorkspaceLiveReattachPhase(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionWorkspaceLiveReattachPhase phase,
) {
  if (controller._isDisposed || !controller._state.isLaneLive(laneId)) {
    return;
  }

  if (controller._state.liveReattachPhaseForLane(laneId) == phase) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      liveReattachPhasesByLaneId: _sanitizeWorkspaceLiveReattachPhases(
        liveLaneIds: controller._state.liveLaneIds,
        liveReattachPhasesByLaneId:
            <String, ConnectionWorkspaceLiveReattachPhase>{
              ...controller._state.liveReattachPhasesByLaneId,
              laneId: phase,
            },
      ),
    ),
  );
}

void _markWorkspaceTransportReconnectRequired(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  if (controller._isDisposed ||
      !controller._state.isLaneLive(laneId) ||
      controller._state.requiresTransportReconnectForLane(laneId)) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      transportReconnectRequiredLaneIds:
          _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
            liveLaneIds: controller._state.liveLaneIds,
            transportReconnectRequiredLaneIds: <String>{
              ...controller._state.transportReconnectRequiredLaneIds,
              laneId,
            },
          ),
      transportRecoveryPhasesByLaneId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            liveLaneIds: controller._state.liveLaneIds,
            transportRecoveryPhasesByLaneId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  ...controller._state.transportRecoveryPhasesByLaneId,
                  laneId: ConnectionWorkspaceTransportRecoveryPhase.lost,
                },
          ),
    ),
  );
}

void _clearWorkspaceTransportReconnectRequired(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  if (controller._isDisposed ||
      !controller._state.requiresTransportReconnectForLane(laneId)) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      transportReconnectRequiredLaneIds:
          _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
            liveLaneIds: controller._state.liveLaneIds,
            transportReconnectRequiredLaneIds: <String>{
              ...controller._state.transportReconnectRequiredLaneIds,
            }..remove(laneId),
          ),
      transportRecoveryPhasesByLaneId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            liveLaneIds: controller._state.liveLaneIds,
            transportRecoveryPhasesByLaneId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  for (final entry
                      in controller
                          ._state
                          .transportRecoveryPhasesByLaneId
                          .entries)
                    if (entry.key != laneId) entry.key: entry.value,
                },
          ),
    ),
  );
}

void _setWorkspaceTransportRecoveryPhase(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionWorkspaceTransportRecoveryPhase phase,
) {
  if (controller._isDisposed || !controller._state.isLaneLive(laneId)) {
    return;
  }

  if (controller._state.transportRecoveryPhaseForLane(laneId) == phase) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      transportRecoveryPhasesByLaneId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            liveLaneIds: controller._state.liveLaneIds,
            transportRecoveryPhasesByLaneId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  ...controller._state.transportRecoveryPhasesByLaneId,
                  laneId: phase,
                },
          ),
    ),
  );
}

void _recordWorkspaceLifecycleBackgroundSnapshot(
  ConnectionWorkspaceController controller,
  String laneId, {
  required DateTime occurredAt,
  required ConnectionWorkspaceBackgroundLifecycleState lifecycleState,
}) {
  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(
      lastBackgroundedAt: occurredAt,
      lastBackgroundedLifecycleState: lifecycleState,
    ),
    enqueueRecoveryPersistence: false,
  );
}

void _recordWorkspaceLifecycleResume(
  ConnectionWorkspaceController controller,
  String laneId, {
  required DateTime occurredAt,
}) {
  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(
      lastResumedAt: occurredAt,
      clearLastBackgroundedLifecycleState: true,
    ),
    enqueueRecoveryPersistence: true,
  );
}

void _recordWorkspaceTransportLoss(
  ConnectionWorkspaceController controller,
  String laneId, {
  required DateTime occurredAt,
  required ConnectionWorkspaceTransportLossReason reason,
}) {
  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(
      lastTransportLossAt: occurredAt,
      lastTransportLossReason: reason,
    ),
  );
}

void _recordWorkspaceFallbackTransportConnectFailure(
  ConnectionWorkspaceController controller,
  String laneId, {
  required DateTime occurredAt,
  required Object? error,
}) {
  final diagnostics = controller._state.recoveryDiagnosticsForLane(laneId);
  final lastRecoveryStartedAt = diagnostics?.lastRecoveryStartedAt;
  final lastTransportLossAt = diagnostics?.lastTransportLossAt;
  if (lastRecoveryStartedAt != null &&
      lastTransportLossAt != null &&
      !lastTransportLossAt.isBefore(lastRecoveryStartedAt)) {
    return;
  }

  controller._recordTransportLoss(
    laneId,
    occurredAt: occurredAt,
    reason: ConnectionWorkspaceTransportLossReason.connectFailed,
  );
  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(
      lastTransportFailureDetail: PocketErrorDetailFormatter.normalize(error),
    ),
  );
}

void _recordWorkspaceLiveReattachFailure(
  ConnectionWorkspaceController controller,
  String laneId, {
  required Object? error,
}) {
  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(
      lastLiveReattachFailureDetail: PocketErrorDetailFormatter.normalize(
        error,
      ),
    ),
  );
}

void _beginWorkspaceRecoveryAttempt(
  ConnectionWorkspaceController controller,
  String laneId, {
  required DateTime startedAt,
  required ConnectionWorkspaceRecoveryOrigin origin,
}) {
  controller._updateRecoveryDiagnostics(
    laneId,
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
  String laneId, {
  required DateTime completedAt,
  required ConnectionWorkspaceRecoveryOutcome outcome,
}) {
  controller._updateRecoveryDiagnostics(
    laneId,
    (current) => current.copyWith(
      lastRecoveryCompletedAt: completedAt,
      lastRecoveryOutcome: outcome,
    ),
  );
}

void _completeWorkspaceConversationRecoveryAttempt(
  ConnectionWorkspaceController controller,
  String laneId,
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
    laneId,
    completedAt: completedAt,
    outcome: outcome,
  );
}

void _updateWorkspaceRecoveryDiagnostics(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionWorkspaceRecoveryDiagnostics Function(
    ConnectionWorkspaceRecoveryDiagnostics current,
  )
  update, {
  required bool enqueueRecoveryPersistence,
}) {
  if (controller._isDisposed || !controller._state.isLaneLive(laneId)) {
    return;
  }

  final currentDiagnostics =
      controller._state.recoveryDiagnosticsForLane(laneId) ??
      const ConnectionWorkspaceRecoveryDiagnostics();
  final nextDiagnostics = update(currentDiagnostics);
  if (nextDiagnostics == currentDiagnostics) {
    return;
  }

  final nextState = controller._state.copyWith(
    recoveryDiagnosticsByLaneId: _sanitizeWorkspaceRecoveryDiagnostics(
      liveLaneIds: controller._state.liveLaneIds,
      recoveryDiagnosticsByLaneId:
          <String, ConnectionWorkspaceRecoveryDiagnostics>{
            ...controller._state.recoveryDiagnosticsByLaneId,
            laneId: nextDiagnostics,
          },
    ),
  );
  if (enqueueRecoveryPersistence) {
    controller._applyState(nextState);
    return;
  }
  controller._applyStateWithoutRecoveryPersistence(nextState);
}
