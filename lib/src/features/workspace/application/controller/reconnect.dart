part of '../connection_workspace_controller.dart';

Future<void> _reconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final previousBinding = controller._liveBindingsByConnectionId[connectionId];
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

  if (!shouldReplaceBinding) {
    final preservedLaneState = _preservedWorkspaceLaneState(previousBinding);
    controller._applyState(
      controller._state.copyWith(
        transportRecoveryPhasesByConnectionId: shouldReconnectTransport
            ? _sanitizeWorkspaceTransportRecoveryPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                transportRecoveryPhasesByConnectionId:
                    <String, ConnectionWorkspaceTransportRecoveryPhase>{
                      ...controller
                          ._state
                          .transportRecoveryPhasesByConnectionId,
                      connectionId: ConnectionWorkspaceTransportRecoveryPhase
                          .reconnecting,
                    },
              )
            : controller._state.transportRecoveryPhasesByConnectionId,
        liveReattachPhasesByConnectionId: shouldReconnectTransport
            ? _sanitizeWorkspaceLiveReattachPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                liveReattachPhasesByConnectionId:
                    <String, ConnectionWorkspaceLiveReattachPhase>{
                      ...controller._state.liveReattachPhasesByConnectionId,
                      connectionId:
                          ConnectionWorkspaceLiveReattachPhase.reconnecting,
                    },
              )
            : controller._state.liveReattachPhasesByConnectionId,
      ),
    );
    if (!shouldReconnectTransport) {
      return;
    }

    try {
      await _connectWorkspaceBindingTransport(previousBinding);
    } on CodexRemoteAppServerAttachException catch (error) {
      if (!controller._isDisposed) {
        _applyWorkspaceRemoteAttachRuntime(
          controller,
          connectionId: connectionId,
          snapshot: error.snapshot,
        );
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
          error: error,
        );
        controller._setLiveReattachPhase(
          connectionId,
          switch (error.snapshot.status) {
            CodexRemoteAppServerOwnerStatus.missing ||
            CodexRemoteAppServerOwnerStatus.stopped =>
              ConnectionWorkspaceLiveReattachPhase.ownerMissing,
            CodexRemoteAppServerOwnerStatus.unhealthy ||
            CodexRemoteAppServerOwnerStatus.running =>
              ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy,
          },
        );
        controller._setTransportRecoveryPhase(
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        if (preservedLaneState.threadId case final threadId?) {
          controller._setTurnLivenessAssessment(
            connectionId,
            ConnectionWorkspaceTurnLivenessAssessment(
              status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
              evidence:
                  ConnectionWorkspaceTurnLivenessEvidence.ownerUnavailable,
              threadId: threadId,
            ),
          );
        }
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    } catch (error) {
      if (!controller._isDisposed) {
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
          error: error,
        );
        controller._clearLiveReattachPhase(connectionId);
        controller._setTransportRecoveryPhase(
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        if (preservedLaneState.threadId case final threadId?) {
          controller._setTurnLivenessAssessment(
            connectionId,
            ConnectionWorkspaceTurnLivenessAssessment(
              status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
              evidence:
                  ConnectionWorkspaceTurnLivenessEvidence.transportUnavailable,
              threadId: threadId,
            ),
          );
        }
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    }
    if (controller._isDisposed || preservedLaneState.threadId == null) {
      return;
    }

    await _recoverWorkspaceConversationAfterTransportReconnect(
      controller,
      connectionId,
      previousBinding,
      threadId: preservedLaneState.threadId!,
      hadVisibleConversationState:
          _workspaceLaneHasVisibleLiveConversationState(previousBinding),
    );
    return;
  }

  final preservedLaneState = _preservedWorkspaceLaneState(previousBinding);
  final nextBinding = await _loadWorkspaceLaneBinding(
    controller,
    connectionId,
    initialDraftText: preservedLaneState.draftText,
  );
  if (controller._isDisposed) {
    nextBinding.dispose();
    return;
  }

  controller._liveBindingsByConnectionId[connectionId] = nextBinding;
  controller._unregisterLiveBinding(connectionId);
  controller._registerLiveBinding(connectionId, nextBinding);
  previousBinding.dispose();
  controller._applyState(
    controller._state.copyWith(
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              ...controller._state.savedSettingsReconnectRequiredConnectionIds,
            }..remove(connectionId),
          ),
      transportReconnectRequiredConnectionIds: shouldReconnectTransport
          ? controller._state.transportReconnectRequiredConnectionIds
          : _sanitizeWorkspaceReconnectRequiredIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                ...controller._state.transportReconnectRequiredConnectionIds,
              }..remove(connectionId),
            ),
      transportRecoveryPhasesByConnectionId: shouldReconnectTransport
          ? _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    ...controller._state.transportRecoveryPhasesByConnectionId,
                    connectionId:
                        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
                  },
            )
          : _sanitizeWorkspaceTransportRecoveryPhases(
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
      liveReattachPhasesByConnectionId: shouldReconnectTransport
          ? _sanitizeWorkspaceLiveReattachPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              liveReattachPhasesByConnectionId:
                  <String, ConnectionWorkspaceLiveReattachPhase>{
                    ...controller._state.liveReattachPhasesByConnectionId,
                    connectionId:
                        ConnectionWorkspaceLiveReattachPhase.reconnecting,
                  },
            )
          : _sanitizeWorkspaceLiveReattachPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              liveReattachPhasesByConnectionId:
                  <String, ConnectionWorkspaceLiveReattachPhase>{
                    for (final entry
                        in controller
                            ._state
                            .liveReattachPhasesByConnectionId
                            .entries)
                      if (entry.key != connectionId) entry.key: entry.value,
                  },
            ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: controller._state.catalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
    ),
  );
  await nextBinding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
  if (shouldReconnectTransport) {
    try {
      await _connectWorkspaceBindingTransport(nextBinding);
    } on CodexRemoteAppServerAttachException catch (error) {
      if (!controller._isDisposed) {
        _applyWorkspaceRemoteAttachRuntime(
          controller,
          connectionId: connectionId,
          snapshot: error.snapshot,
        );
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
          error: error,
        );
        controller._setLiveReattachPhase(
          connectionId,
          switch (error.snapshot.status) {
            CodexRemoteAppServerOwnerStatus.missing ||
            CodexRemoteAppServerOwnerStatus.stopped =>
              ConnectionWorkspaceLiveReattachPhase.ownerMissing,
            CodexRemoteAppServerOwnerStatus.unhealthy ||
            CodexRemoteAppServerOwnerStatus.running =>
              ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy,
          },
        );
        controller._setTransportRecoveryPhase(
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        if (preservedLaneState.threadId case final threadId?) {
          controller._setTurnLivenessAssessment(
            connectionId,
            ConnectionWorkspaceTurnLivenessAssessment(
              status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
              evidence:
                  ConnectionWorkspaceTurnLivenessEvidence.ownerUnavailable,
              threadId: threadId,
            ),
          );
        }
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    } catch (error) {
      if (!controller._isDisposed) {
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
          error: error,
        );
        controller._clearLiveReattachPhase(connectionId);
        controller._setTransportRecoveryPhase(
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        if (preservedLaneState.threadId case final threadId?) {
          controller._setTurnLivenessAssessment(
            connectionId,
            ConnectionWorkspaceTurnLivenessAssessment(
              status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
              evidence:
                  ConnectionWorkspaceTurnLivenessEvidence.transportUnavailable,
              threadId: threadId,
            ),
          );
        }
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    }
  }
  if (preservedLaneState.threadId != null) {
    if (shouldReconnectTransport) {
      await _recoverWorkspaceConversationAfterTransportReconnect(
        controller,
        connectionId,
        nextBinding,
        threadId: preservedLaneState.threadId!,
        hadVisibleConversationState: false,
      );
      return;
    }
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

Future<void> _connectWorkspaceBindingTransport(ConnectionLaneBinding binding) {
  if (binding.agentAdapterClient.isConnected) {
    return Future<void>.value();
  }

  return binding.agentAdapterClient.connect(
    profile: binding.sessionController.profile,
    secrets: binding.sessionController.secrets,
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
      controller._setLiveReattachPhase(
        connectionId,
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
      );
      await binding.sessionController.selectConversationForResume(threadId);
      if (!controller._isDisposed) {
        controller._setTurnLivenessAssessment(connectionId, assessment);
        controller._completeConversationRecoveryAttempt(
          connectionId,
          binding,
          completedAt: controller._now(),
        );
      }
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
    controller._setLiveReattachPhase(
      connectionId,
      ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
    );
    await binding.sessionController.selectConversationForResume(threadId);
    if (!controller._isDisposed) {
      controller._setTurnLivenessAssessment(connectionId, assessment);
      controller._completeConversationRecoveryAttempt(
        connectionId,
        binding,
        completedAt: controller._now(),
      );
    }
  }
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

void _syncWorkspaceTurnLivenessAssessment(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionLaneBinding binding,
) {
  final assessment = controller._state.turnLivenessAssessmentFor(connectionId);
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
    controller._clearTurnLivenessAssessment(connectionId);
    return;
  }

  switch (assessment.status) {
    case ConnectionWorkspaceTurnLivenessStatus.stillLive:
      if (!_workspaceLaneHasProvenLiveTurnState(binding)) {
        controller._clearTurnLivenessAssessment(connectionId);
      }
    case ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway ||
        ConnectionWorkspaceTurnLivenessStatus.continuityLost ||
        ConnectionWorkspaceTurnLivenessStatus.unknown:
      if (binding.agentAdapterClient.activeTurnId?.trim().isNotEmpty == true) {
        controller._clearTurnLivenessAssessment(connectionId);
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
  String connectionId,
  ConnectionLaneBinding binding,
) {
  if (controller._isDisposed || !binding.agentAdapterClient.isConnected) {
    return false;
  }

  return controller._state.requiresTransportReconnect(connectionId) &&
      controller._state.transportRecoveryPhaseFor(connectionId) ==
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
