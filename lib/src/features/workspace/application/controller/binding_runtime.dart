part of '../connection_workspace_controller.dart';

void _notifyWorkspaceBindingChange(ConnectionWorkspaceController controller) {
  if (controller._isDisposed) {
    return;
  }

  controller._notifyListenersInternal();
  unawaited(controller._enqueueRecoveryPersistence());
}

void _registerWorkspaceLiveBinding(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding,
) {
  void listener() {
    _syncWorkspaceTurnLivenessAssessment(controller, laneId, binding);
    _syncWorkspaceRecoveredTransportState(controller, laneId, binding);
    if (controller._state.selectedLaneId != laneId) {
      return;
    }
    final snapshot = controller._selectedRecoveryStateSnapshot();
    if (controller._hasImmediateRecoveryIdentityChange(snapshot)) {
      unawaited(
        controller._queueRecoveryPersistenceSnapshot(
          snapshot: snapshot,
          laneId: laneId,
        ),
      );
      return;
    }
    controller._scheduleRecoveryPersistence();
  }

  controller._laneRoster.registerBinding(
    laneId: laneId,
    binding: binding,
    listener: listener,
    agentAdapterEventSubscription: binding.agentAdapterClient.events.listen((
      event,
    ) {
      switch (event) {
        case AgentAdapterDisconnectedEvent(:final exitCode):
          if (controller._intentionalTransportDisconnectConnectionIds.remove(
            laneId,
          )) {
            _clearWorkspaceTransportReconnectState(controller, laneId);
            controller._clearTurnLivenessAssessment(laneId);
            break;
          }
          controller._recordTransportLoss(
            laneId,
            occurredAt: controller._now(),
            reason: switch (exitCode) {
              null => ConnectionWorkspaceTransportLossReason.disconnected,
              0 => ConnectionWorkspaceTransportLossReason.appServerExitGraceful,
              _ => ConnectionWorkspaceTransportLossReason.appServerExitError,
            },
          );
          controller._markTransportReconnectRequired(laneId);
          controller._setLiveReattachPhase(
            laneId,
            ConnectionWorkspaceLiveReattachPhase.transportLost,
          );
          controller._clearTurnLivenessAssessment(laneId);
          break;
        case AgentAdapterConnectedEvent():
          final wasRecovering = controller._state
              .requiresTransportReconnectForLane(laneId);
          if (wasRecovering) {
            final hasConversationIdentity =
                binding.sessionController.sessionState.currentThreadId
                        ?.trim()
                        .isNotEmpty ==
                    true ||
                binding.sessionController.sessionState.rootThreadId
                        ?.trim()
                        .isNotEmpty ==
                    true;
            if (hasConversationIdentity) {
              controller._setLiveReattachPhase(
                laneId,
                ConnectionWorkspaceLiveReattachPhase.reconnecting,
              );
            } else {
              _finalizeWorkspaceRecoveredTransportState(
                controller,
                laneId,
                completedAt: controller._now(),
                recordRecoveryOutcome: true,
              );
            }
          }
          break;
        case AgentAdapterSshConnectFailedEvent():
          controller._recordTransportLoss(
            laneId,
            occurredAt: controller._now(),
            reason: ConnectionWorkspaceTransportLossReason.sshConnectFailed,
          );
          break;
        case AgentAdapterSshHostKeyMismatchEvent():
          controller._recordTransportLoss(
            laneId,
            occurredAt: controller._now(),
            reason: ConnectionWorkspaceTransportLossReason.sshHostKeyMismatch,
          );
          break;
        case AgentAdapterSshAuthenticationFailedEvent():
          controller._recordTransportLoss(
            laneId,
            occurredAt: controller._now(),
            reason:
                ConnectionWorkspaceTransportLossReason.sshAuthenticationFailed,
          );
          break;
        default:
          break;
      }
    }),
  );
}

void _unregisterWorkspaceLiveBinding(
  ConnectionWorkspaceController controller,
  String laneId,
) {
  controller._laneRoster.unregisterBinding(laneId);
}
