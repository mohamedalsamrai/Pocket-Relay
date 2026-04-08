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
  String connectionId,
  ConnectionLaneBinding binding, {
  required String? threadId,
  required bool hadVisibleConversationState,
}) async {
  final transportConnected = await _connectWorkspaceBindingTransportForRecovery(
    controller,
    connectionId,
    binding,
    threadId: threadId,
  );
  if (!transportConnected || controller._isDisposed || threadId == null) {
    return transportConnected;
  }

  await _recoverWorkspaceConversationAfterTransportReconnect(
    controller,
    connectionId,
    binding,
    threadId: threadId,
    hadVisibleConversationState: hadVisibleConversationState,
  );
  return true;
}

Future<bool> _connectWorkspaceBindingTransportForRecovery(
  ConnectionWorkspaceController controller,
  String connectionId,
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
        connectionId: connectionId,
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
        connectionId: connectionId,
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
    connectionId,
    occurredAt: occurredAt,
    error: error,
  );
  if (liveReattachPhase == null) {
    controller._clearLiveReattachPhase(connectionId);
  } else {
    controller._setLiveReattachPhase(connectionId, liveReattachPhase);
  }
  controller._setTransportRecoveryPhase(
    connectionId,
    ConnectionWorkspaceTransportRecoveryPhase.unavailable,
  );
  if (threadId != null) {
    controller._setTurnLivenessAssessment(
      connectionId,
      ConnectionWorkspaceTurnLivenessAssessment(
        status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
        evidence: turnLivenessEvidence,
        threadId: threadId,
      ),
    );
  }
  controller._completeRecoveryAttempt(
    connectionId,
    completedAt: occurredAt,
    outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
  );
}

Future<void> _recoverWorkspaceConversationAfterTransportReconnect(
  ConnectionWorkspaceController controller,
  String connectionId,
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
      connectionId,
      binding,
    )) {
      return;
    }
    controller._clearTransportReconnectRequired(connectionId);

    if (shouldRestoreFromHistory) {
      await _restoreWorkspaceConversationFromHistoryAfterReconnect(
        controller,
        connectionId,
        binding,
        threadId: threadId,
        assessment: assessment,
      );
      return;
    }

    controller._setLiveReattachPhase(
      connectionId,
      ConnectionWorkspaceLiveReattachPhase.liveReattached,
    );
    controller._setTurnLivenessAssessment(connectionId, assessment);
    controller._completeRecoveryAttempt(
      connectionId,
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
    controller._recordLiveReattachFailure(connectionId, error: error);
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
      connectionId,
      binding,
    )) {
      return;
    }
    controller._clearTransportReconnectRequired(connectionId);
    final shouldRestoreFromHistory =
        assessment.status ==
            ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway ||
        !hadVisibleConversationState;
    if (!shouldRestoreFromHistory) {
      controller._clearLiveReattachPhase(connectionId);
      controller._setTurnLivenessAssessment(connectionId, assessment);
      controller._completeRecoveryAttempt(
        connectionId,
        completedAt: controller._now(),
        outcome: ConnectionWorkspaceRecoveryOutcome.continuityLost,
      );
      return;
    }
    await _restoreWorkspaceConversationFromHistoryAfterReconnect(
      controller,
      connectionId,
      binding,
      threadId: threadId,
      assessment: assessment,
    );
  }
}

Future<void> _restoreWorkspaceConversationFromHistoryAfterReconnect(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionLaneBinding binding, {
  required String threadId,
  required ConnectionWorkspaceTurnLivenessAssessment assessment,
}) async {
  controller._setLiveReattachPhase(
    connectionId,
    ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
  );
  await binding.sessionController.selectConversationForResume(threadId);
  if (controller._isDisposed) {
    return;
  }

  controller._setTurnLivenessAssessment(connectionId, assessment);
  controller._completeConversationRecoveryAttempt(
    connectionId,
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
  String connectionId,
  ConnectionLaneBinding binding,
) {
  if (!controller._state.requiresTransportReconnect(connectionId) ||
      !binding.agentAdapterClient.isConnected) {
    return;
  }

  final liveReattachPhase = controller._state.liveReattachPhaseFor(
    connectionId,
  );
  if (liveReattachPhase == ConnectionWorkspaceLiveReattachPhase.ownerMissing ||
      liveReattachPhase ==
          ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy) {
    return;
  }

  final diagnostics = controller._state.recoveryDiagnosticsFor(connectionId);
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
    connectionId,
    completedAt: controller._now(),
    recordRecoveryOutcome: recoveryAttemptInFlight,
  );
}
