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
  String connectionId,
  ConnectionLaneBinding binding,
) {
  void listener() {
    _syncWorkspaceTurnLivenessAssessment(controller, connectionId, binding);
    _syncWorkspaceRecoveredTransportState(controller, connectionId, binding);
    if (controller._state.selectedConnectionId != connectionId) {
      return;
    }
    final snapshot = controller._selectedRecoveryStateSnapshot();
    if (controller._hasImmediateRecoveryIdentityChange(snapshot)) {
      unawaited(
        controller._queueRecoveryPersistenceSnapshot(snapshot: snapshot),
      );
      return;
    }
    controller._scheduleRecoveryPersistence();
  }

  controller._liveBindingRegistry.register(
    connectionId: connectionId,
    binding: binding,
    listener: listener,
    agentAdapterEventSubscription: binding.agentAdapterClient.events.listen((
      event,
    ) {
      switch (event) {
        case AgentAdapterDisconnectedEvent(:final exitCode):
          if (controller._intentionalTransportDisconnectConnectionIds.remove(
            connectionId,
          )) {
            _clearWorkspaceTransportReconnectState(controller, connectionId);
            controller._clearTurnLivenessAssessment(connectionId);
            break;
          }
          controller._recordTransportLoss(
            connectionId,
            occurredAt: controller._now(),
            reason: switch (exitCode) {
              null => ConnectionWorkspaceTransportLossReason.disconnected,
              0 => ConnectionWorkspaceTransportLossReason.appServerExitGraceful,
              _ => ConnectionWorkspaceTransportLossReason.appServerExitError,
            },
          );
          controller._markTransportReconnectRequired(connectionId);
          controller._setLiveReattachPhase(
            connectionId,
            ConnectionWorkspaceLiveReattachPhase.transportLost,
          );
          controller._clearTurnLivenessAssessment(connectionId);
          break;
        case AgentAdapterConnectedEvent():
          final wasRecovering = controller._state.requiresTransportReconnect(
            connectionId,
          );
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
                connectionId,
                ConnectionWorkspaceLiveReattachPhase.reconnecting,
              );
            } else {
              _finalizeWorkspaceRecoveredTransportState(
                controller,
                connectionId,
                completedAt: controller._now(),
                recordRecoveryOutcome: true,
              );
            }
          }
          break;
        case AgentAdapterSshConnectFailedEvent():
          controller._recordTransportLoss(
            connectionId,
            occurredAt: controller._now(),
            reason: ConnectionWorkspaceTransportLossReason.sshConnectFailed,
          );
          break;
        case AgentAdapterSshHostKeyMismatchEvent():
          controller._recordTransportLoss(
            connectionId,
            occurredAt: controller._now(),
            reason: ConnectionWorkspaceTransportLossReason.sshHostKeyMismatch,
          );
          break;
        case AgentAdapterSshAuthenticationFailedEvent():
          controller._recordTransportLoss(
            connectionId,
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
  String connectionId,
) {
  controller._liveBindingRegistry.unregister(connectionId);
}
