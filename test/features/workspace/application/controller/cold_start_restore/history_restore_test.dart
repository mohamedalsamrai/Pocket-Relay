import '../controller_test_support.dart';

void main() {
  test(
    'initialization marks the restored lane reconnecting while cold-start transport bootstrap is in flight',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      clientsById['conn_secondary']!.connectGate = Completer<void>();
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      final initialization = controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
      );
      expect(
        controller.selectedLaneBinding?.composerDraftHost.draft.text,
        'Restore my draft',
      );
      final reconnectingDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(reconnectingDiagnostics, isNotNull);
      expect(
        reconnectingDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(reconnectingDiagnostics.lastRecoveryStartedAt, isNotNull);
      expect(reconnectingDiagnostics.lastRecoveryCompletedAt, isNull);
      expect(reconnectingDiagnostics.lastRecoveryOutcome, isNull);

      clientsById['conn_secondary']!.connectGate!.complete();
      await initialization;

      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        isNull,
      );
      expect(
        controller
            .selectedLaneBinding
            ?.sessionController
            .sessionState
            .rootThreadId,
        'thread_saved',
      );
      expect(
        controller.selectedLaneBinding?.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        clientsById['conn_secondary']!
            .startSessionRequests
            .single
            .resumeThreadId,
        'thread_saved',
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, <String>[
        'thread_saved',
        'thread_saved',
      ]);
      expect(clientsById['conn_secondary']!.connectCalls, 1);
      final restoredDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(restoredDiagnostics, isNotNull);
      expect(
        restoredDiagnostics!.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportRestored,
      );
      expect(restoredDiagnostics.lastRecoveryCompletedAt, isNotNull);
    },
  );

  test(
    'initialization keeps the restored lane visible and marks remote session unavailable when cold-start transport bootstrap fails',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexAppServerException('connect failed');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(controller.selectedLaneBinding, isNotNull);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Restore my draft',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(controller.state.liveReattachPhaseFor('conn_secondary'), isNull);
      final unavailableDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(unavailableDiagnostics, isNotNull);
      expect(
        unavailableDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(
        unavailableDiagnostics.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.connectFailed,
      );
      expect(
        unavailableDiagnostics.lastTransportFailureDetail,
        'connect failed',
      );
      expect(
        unavailableDiagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
      expect(
        controller
            .selectedLaneBinding!
            .sessionController
            .sessionState
            .rootThreadId,
        isNull,
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, isEmpty);
    },
  );

  test(
    'initialization stores remote stopped runtime when cold-start transport bootstrap cannot attach to the managed owner',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexRemoteAppServerAttachException(
            snapshot: CodexRemoteAppServerOwnerSnapshot(
              ownerId: 'conn_secondary',
              workspaceDir: '/workspace',
              status: CodexRemoteAppServerOwnerStatus.stopped,
              sessionName: 'pocket-relay-conn_secondary',
              detail: 'Managed remote app-server is not running.',
            ),
            message: 'Managed remote app-server is not running.',
          );
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      final remoteRuntime = controller.state.remoteRuntimeFor('conn_secondary');
      expect(remoteRuntime, isNotNull);
      expect(
        remoteRuntime!.server.status,
        ConnectionRemoteServerStatus.notRunning,
      );
      expect(
        remoteRuntime.server.detail,
        'Managed remote app-server is not running.',
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.ownerMissing,
      );
    },
  );
}
