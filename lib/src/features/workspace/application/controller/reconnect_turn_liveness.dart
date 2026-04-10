part of '../connection_workspace_controller.dart';

void _syncWorkspaceTurnLivenessAssessment(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding,
) {
  final assessment = controller._state.turnLivenessAssessmentForLane(laneId);
  if (assessment == null) {
    return;
  }

  final sessionState = binding.sessionController.sessionState;
  final currentThreadId =
      sessionState.currentThreadId?.trim().isNotEmpty == true
      ? sessionState.currentThreadId!.trim()
      : sessionState.rootThreadId?.trim();
  if (assessment.threadId != null &&
      currentThreadId != null &&
      assessment.threadId != currentThreadId) {
    controller._clearTurnLivenessAssessment(laneId);
    return;
  }

  switch (assessment.status) {
    case ConnectionWorkspaceTurnLivenessStatus.stillLive:
      if (!_workspaceLaneHasProvenLiveTurnState(binding)) {
        controller._clearTurnLivenessAssessment(laneId);
      }
    case ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway ||
        ConnectionWorkspaceTurnLivenessStatus.continuityLost ||
        ConnectionWorkspaceTurnLivenessStatus.unknown:
      if (binding.agentAdapterClient.activeTurnId?.trim().isNotEmpty == true) {
        controller._clearTurnLivenessAssessment(laneId);
      }
  }
}

Future<ConnectionWorkspaceTurnLivenessAssessment>
_resolveWorkspaceTurnLivenessAfterReconnect(
  ConnectionLaneBinding binding, {
  required String threadId,
  required bool liveReattachSucceeded,
}) async {
  final sessionAssessment = _workspaceTurnLivenessAssessmentFromSession(
    binding,
    threadId: threadId,
  );
  if (sessionAssessment != null) {
    return sessionAssessment;
  }

  AgentAdapterThreadHistory? threadHistory;
  try {
    threadHistory = await binding.agentAdapterClient.readThreadWithTurns(
      threadId: threadId,
    );
  } catch (_) {
    threadHistory = null;
  }

  final latestTurn = _latestWorkspaceHistoryTurn(threadHistory, threadId);
  final latestStatus = _normalizedWorkspaceHistoryTurnStatus(
    latestTurn?.status,
  );
  if (liveReattachSucceeded &&
      _isStillLiveWorkspaceHistoryTurnStatus(latestStatus)) {
    return ConnectionWorkspaceTurnLivenessAssessment(
      status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
      evidence:
          ConnectionWorkspaceTurnLivenessEvidence.threadHistoryRunningTurn,
      threadId: threadId,
      turnId: latestTurn?.id,
    );
  }
  if (_isTerminalWorkspaceHistoryTurnStatus(latestStatus)) {
    return ConnectionWorkspaceTurnLivenessAssessment(
      status: ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway,
      evidence:
          ConnectionWorkspaceTurnLivenessEvidence.threadHistoryTerminalTurn,
      threadId: threadId,
      turnId: latestTurn?.id,
    );
  }
  if (!liveReattachSucceeded) {
    return ConnectionWorkspaceTurnLivenessAssessment(
      status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
      evidence: ConnectionWorkspaceTurnLivenessEvidence.liveReattachFailed,
      threadId: threadId,
      turnId: latestTurn?.id,
    );
  }

  return ConnectionWorkspaceTurnLivenessAssessment(
    status: ConnectionWorkspaceTurnLivenessStatus.unknown,
    evidence: ConnectionWorkspaceTurnLivenessEvidence.adapterUnverifiable,
    threadId: threadId,
    turnId: latestTurn?.id,
  );
}

ConnectionWorkspaceTurnLivenessAssessment?
_workspaceTurnLivenessAssessmentFromSession(
  ConnectionLaneBinding binding, {
  required String threadId,
}) {
  final sessionState = binding.sessionController.sessionState;
  final activeTurn = sessionState.activeTurn;
  if (activeTurn != null) {
    return ConnectionWorkspaceTurnLivenessAssessment(
      status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
      evidence: ConnectionWorkspaceTurnLivenessEvidence.activeTurnReattached,
      threadId: threadId,
      turnId: activeTurn.turnId,
    );
  }
  if (sessionState.pendingApprovalRequests.isNotEmpty ||
      sessionState.pendingUserInputRequests.isNotEmpty ||
      binding.agentAdapterClient.activeTurnId?.trim().isNotEmpty == true) {
    return ConnectionWorkspaceTurnLivenessAssessment(
      status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
      evidence:
          ConnectionWorkspaceTurnLivenessEvidence.pendingTurnRequestReattached,
      threadId: threadId,
      turnId: binding.agentAdapterClient.activeTurnId?.trim(),
    );
  }
  return null;
}

AgentAdapterHistoryTurn? _latestWorkspaceHistoryTurn(
  AgentAdapterThreadHistory? history,
  String threadId,
) {
  if (history == null || history.turns.isEmpty) {
    return null;
  }

  for (final turn in history.turns.reversed) {
    final turnThreadId = turn.threadId?.trim();
    if (turnThreadId == null ||
        turnThreadId.isEmpty ||
        turnThreadId == threadId) {
      return turn;
    }
  }
  return null;
}

bool _canFinalizeWorkspaceTurnRecoveryAssessment(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding,
) {
  if (controller._isDisposed || !binding.agentAdapterClient.isConnected) {
    return false;
  }

  return controller._state.requiresTransportReconnectForLane(laneId) &&
      controller._state.transportRecoveryPhaseForLane(laneId) ==
          ConnectionWorkspaceTransportRecoveryPhase.reconnecting;
}

String? _normalizedWorkspaceHistoryTurnStatus(String? status) {
  final trimmed = status?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed.toLowerCase();
}

bool _isStillLiveWorkspaceHistoryTurnStatus(String? status) {
  return switch (status) {
    'running' || 'active' || 'inprogress' || 'in_progress' => true,
    _ => false,
  };
}

bool _isTerminalWorkspaceHistoryTurnStatus(String? status) {
  return switch (status) {
    'completed' ||
    'failed' ||
    'aborted' ||
    'cancelled' ||
    'interrupted' => true,
    _ => false,
  };
}
