part of '../connection_workspace_controller.dart';

Future<void> _connectWorkspaceBindingTransport(ConnectionLaneBinding binding) {
  if (binding.agentAdapterClient.isConnected) {
    return Future<void>.value();
  }

  return binding.agentAdapterClient.connect(
    profile: binding.sessionController.profile,
    secrets: binding.sessionController.secrets,
  );
}

Future<bool> _attemptWorkspaceTransportReconnect(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding, {
  required String? threadId,
  required bool hadVisibleConversationState,
}) async {
  final transportConnected = await _connectWorkspaceBindingTransportForRecovery(
    controller,
    laneId,
    binding,
    threadId: threadId,
  );
  if (!transportConnected || controller._isDisposed) {
    return transportConnected;
  }
  if (threadId == null) {
    _finalizeWorkspaceRecoveredTransportState(
      controller,
      laneId,
      completedAt: controller._now(),
      recordRecoveryOutcome: true,
    );
    return true;
  }

  await _recoverWorkspaceConversationAfterTransportReconnect(
    controller,
    laneId,
    binding,
    threadId: threadId,
    hadVisibleConversationState: hadVisibleConversationState,
  );
  return true;
}

Future<bool> _connectWorkspaceBindingTransportForRecovery(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding, {
  required String? threadId,
}) async {
  try {
    await _connectWorkspaceBindingTransport(binding);
    return true;
  } on CodexRemoteAppServerAttachException catch (error) {
    if (!controller._isDisposed) {
      _handleWorkspaceUnavailableTransportDuringRecovery(
        controller,
        laneId: laneId,
        connectionId: binding.connectionId,
        threadId: threadId,
        occurredAt: controller._now(),
        error: error,
        turnLivenessEvidence:
            ConnectionWorkspaceTurnLivenessEvidence.ownerUnavailable,
        liveReattachPhase: switch (error.snapshot.status) {
          CodexRemoteAppServerOwnerStatus.missing ||
          CodexRemoteAppServerOwnerStatus.stopped =>
            ConnectionWorkspaceLiveReattachPhase.ownerMissing,
          CodexRemoteAppServerOwnerStatus.unhealthy ||
          CodexRemoteAppServerOwnerStatus.running =>
            ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy,
        },
        remoteSnapshot: error.snapshot,
      );
    }
    return false;
  } catch (error) {
    if (!controller._isDisposed) {
      _handleWorkspaceUnavailableTransportDuringRecovery(
        controller,
        laneId: laneId,
        connectionId: binding.connectionId,
        threadId: threadId,
        occurredAt: controller._now(),
        error: error,
        turnLivenessEvidence:
            ConnectionWorkspaceTurnLivenessEvidence.transportUnavailable,
      );
    }
    return false;
  }
}

void _handleWorkspaceUnavailableTransportDuringRecovery(
  ConnectionWorkspaceController controller, {
  required String laneId,
  required String connectionId,
  required String? threadId,
  required DateTime occurredAt,
  required Object error,
  required ConnectionWorkspaceTurnLivenessEvidence turnLivenessEvidence,
  ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
  CodexRemoteAppServerOwnerSnapshot? remoteSnapshot,
}) {
  if (remoteSnapshot != null) {
    _applyWorkspaceRemoteAttachRuntime(
      controller,
      connectionId: connectionId,
      snapshot: remoteSnapshot,
    );
  }

  controller._recordFallbackTransportConnectFailure(
    laneId,
    occurredAt: occurredAt,
    error: error,
  );
  if (liveReattachPhase == null) {
    controller._clearLiveReattachPhase(laneId);
  } else {
    controller._setLiveReattachPhase(laneId, liveReattachPhase);
  }
  controller._setTransportRecoveryPhase(
    laneId,
    ConnectionWorkspaceTransportRecoveryPhase.unavailable,
  );
  if (threadId != null) {
    controller._setTurnLivenessAssessment(
      laneId,
      ConnectionWorkspaceTurnLivenessAssessment(
        status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
        evidence: turnLivenessEvidence,
        threadId: threadId,
      ),
    );
  }
  controller._completeRecoveryAttempt(
    laneId,
    completedAt: occurredAt,
    outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
  );
}

Future<void> _recoverWorkspaceConversationAfterTransportReconnect(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding, {
  required String threadId,
  required bool hadVisibleConversationState,
}) async {
  try {
    await binding.sessionController.reattachConversation(threadId);
    if (controller._isDisposed) {
      return;
    }

    final assessment = await _resolveWorkspaceTurnLivenessAfterReconnect(
      binding,
      threadId: threadId,
      liveReattachSucceeded: true,
    );
    final shouldRestoreFromHistory =
        assessment.status ==
            ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway ||
        _shouldFallbackToHistoryRestoreAfterLiveReattach(
          binding,
          hadVisibleConversationState: hadVisibleConversationState,
        );
    if (!_canFinalizeWorkspaceTurnRecoveryAssessment(
      controller,
      laneId,
      binding,
    )) {
      return;
    }
    controller._clearTransportReconnectRequired(laneId);

    if (shouldRestoreFromHistory) {
      await _restoreWorkspaceConversationFromHistoryAfterReconnect(
        controller,
        laneId,
        binding,
        threadId: threadId,
        assessment: assessment,
      );
      return;
    }

    controller._setLiveReattachPhase(
      laneId,
      ConnectionWorkspaceLiveReattachPhase.liveReattached,
    );
    controller._setTurnLivenessAssessment(laneId, assessment);
    controller._completeRecoveryAttempt(
      laneId,
      completedAt: controller._now(),
      outcome: switch (assessment.status) {
        ConnectionWorkspaceTurnLivenessStatus.stillLive =>
          ConnectionWorkspaceRecoveryOutcome.liveReattached,
        ConnectionWorkspaceTurnLivenessStatus.unknown =>
          ConnectionWorkspaceRecoveryOutcome.livenessUnknown,
        ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway =>
          ConnectionWorkspaceRecoveryOutcome.conversationRestored,
        ConnectionWorkspaceTurnLivenessStatus.continuityLost =>
          ConnectionWorkspaceRecoveryOutcome.continuityLost,
      },
    );
  } catch (error) {
    controller._recordLiveReattachFailure(laneId, error: error);
    if (controller._isDisposed) {
      return;
    }

    final assessment = await _resolveWorkspaceTurnLivenessAfterReconnect(
      binding,
      threadId: threadId,
      liveReattachSucceeded: false,
    );
    if (!_canFinalizeWorkspaceTurnRecoveryAssessment(
      controller,
      laneId,
      binding,
    )) {
      return;
    }
    controller._clearTransportReconnectRequired(laneId);
    final shouldRestoreFromHistory =
        assessment.status ==
            ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway ||
        !hadVisibleConversationState;
    if (!shouldRestoreFromHistory) {
      controller._clearLiveReattachPhase(laneId);
      controller._setTurnLivenessAssessment(laneId, assessment);
      controller._completeRecoveryAttempt(
        laneId,
        completedAt: controller._now(),
        outcome: ConnectionWorkspaceRecoveryOutcome.continuityLost,
      );
      return;
    }
    await _restoreWorkspaceConversationFromHistoryAfterReconnect(
      controller,
      laneId,
      binding,
      threadId: threadId,
      assessment: assessment,
    );
  }
}

Future<void> _restoreWorkspaceConversationFromHistoryAfterReconnect(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding, {
  required String threadId,
  required ConnectionWorkspaceTurnLivenessAssessment assessment,
}) async {
  controller._setLiveReattachPhase(
    laneId,
    ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
  );
  await binding.sessionController.selectConversationForResume(threadId);
  if (controller._isDisposed) {
    return;
  }

  controller._setTurnLivenessAssessment(laneId, assessment);
  controller._completeConversationRecoveryAttempt(
    laneId,
    binding,
    completedAt: controller._now(),
  );
}

bool _shouldFallbackToHistoryRestoreAfterLiveReattach(
  ConnectionLaneBinding binding, {
  required bool hadVisibleConversationState,
}) {
  if (hadVisibleConversationState) {
    return false;
  }

  return !_workspaceLaneHasVisibleLiveConversationState(binding);
}

bool _workspaceLaneHasVisibleLiveConversationState(
  ConnectionLaneBinding binding,
) {
  final sessionState = binding.sessionController.sessionState;
  return sessionState.activeTurn != null ||
      sessionState.pendingApprovalRequests.isNotEmpty ||
      sessionState.pendingUserInputRequests.isNotEmpty ||
      binding.sessionController.transcriptBlocks.isNotEmpty;
}

bool _workspaceLaneHasProvenLiveTurnState(ConnectionLaneBinding binding) {
  final sessionState = binding.sessionController.sessionState;
  return sessionState.activeTurn != null ||
      sessionState.pendingApprovalRequests.isNotEmpty ||
      sessionState.pendingUserInputRequests.isNotEmpty ||
      binding.agentAdapterClient.activeTurnId?.trim().isNotEmpty == true;
}

void _syncWorkspaceRecoveredTransportState(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding,
) {
  if (!controller._state.requiresTransportReconnectForLane(laneId) ||
      !binding.agentAdapterClient.isConnected) {
    return;
  }

  final liveReattachPhase = controller._state.liveReattachPhaseForLane(laneId);
  if (liveReattachPhase == ConnectionWorkspaceLiveReattachPhase.ownerMissing ||
      liveReattachPhase ==
          ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy) {
    return;
  }

  final diagnostics = controller._state.recoveryDiagnosticsForLane(laneId);
  final recoveryAttemptInFlight =
      diagnostics?.lastRecoveryStartedAt != null &&
      diagnostics?.lastRecoveryCompletedAt == null;
  final recoveryOrigin = diagnostics?.lastRecoveryOrigin;
  if (recoveryAttemptInFlight &&
      (recoveryOrigin == ConnectionWorkspaceRecoveryOrigin.manualReconnect ||
          recoveryOrigin == ConnectionWorkspaceRecoveryOrigin.coldStart)) {
    return;
  }

  final sessionController = binding.sessionController;
  final historicalRestoreInFlight =
      sessionController.historicalConversationRestoreState?.phase ==
      ChatHistoricalConversationRestorePhase.loading;
  if (sessionController.conversationRecoveryState != null ||
      historicalRestoreInFlight) {
    return;
  }

  final sessionState = sessionController.sessionState;
  final hasConversationIdentity =
      sessionState.currentThreadId?.trim().isNotEmpty == true ||
      sessionState.rootThreadId?.trim().isNotEmpty == true;
  final passiveRecoveryCleanup =
      recoveryOrigin == null ||
      recoveryOrigin == ConnectionWorkspaceRecoveryOrigin.foregroundResume;
  final hasRecoveredActivity = passiveRecoveryCleanup
      ? _workspaceLaneHasProvenLiveTurnState(binding) || hasConversationIdentity
      : _workspaceLaneHasProvenLiveTurnState(binding) ||
            (hasConversationIdentity &&
                _workspaceLaneHasVisibleLiveConversationState(binding));
  if (!hasRecoveredActivity) {
    return;
  }

  _finalizeWorkspaceRecoveredTransportState(
    controller,
    laneId,
    completedAt: controller._now(),
    recordRecoveryOutcome: recoveryAttemptInFlight,
  );
}
