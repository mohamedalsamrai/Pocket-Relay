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
      final inFlightRecoveryState = await recoveryStore.load();
      expect(inFlightRecoveryState, isNotNull);
      expect(inFlightRecoveryState!.connectionId, 'conn_secondary');
      expect(inFlightRecoveryState.selectedThreadId, 'thread_saved');
      expect(inFlightRecoveryState.draftText, 'Restore my draft');
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
    'cold-start transport failure preserves the selected thread for a later restore retry',
    () async {
      final initialRecoveryState = const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_secondary',
        selectedThreadId: 'thread_saved',
        draftText: 'Restore my draft',
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: initialRecoveryState,
      );

      final failingClientsById = buildClientsById(
        'conn_primary',
        'conn_secondary',
      );
      failingClientsById['conn_secondary']!.connectError =
          const CodexAppServerException('connect failed');
      final failingController = buildWorkspaceController(
        clientsById: failingClientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        failingController.dispose();
        await closeClients(failingClientsById);
      });

      await failingController.initialize();

      final failedRecoveryState = await recoveryStore.load();
      expect(failedRecoveryState, isNotNull);
      expect(failedRecoveryState, initialRecoveryState);

      final retryClientsById = buildClientsById(
        'conn_primary',
        'conn_secondary',
      );
      retryClientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final retryController = buildWorkspaceController(
        clientsById: retryClientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        retryController.dispose();
        await closeClients(retryClientsById);
      });

      await retryController.initialize();

      expect(retryController.state.selectedConnectionId, 'conn_secondary');
      expect(
        retryController
            .selectedLaneBinding
            ?.sessionController
            .sessionState
            .rootThreadId,
        'thread_saved',
      );
      expect(
        retryController.selectedLaneBinding?.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        retryClientsById['conn_secondary']!
            .startSessionRequests
            .single
            .resumeThreadId,
        'thread_saved',
      );
    },
  );

  test(
    'clearing the transcript after failed cold-start recovery clears the persisted selected thread',
    () async {
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexAppServerException('connect failed');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_saved');

      controller.selectedLaneBinding!.sessionController.clearTranscript();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.debugLatestUnsavedRecoveryState?.selectedThreadId,
        isNull,
      );
      expect((await recoveryStore.load())?.selectedThreadId, isNull);
    },
  );

  test(
    'clearing the transcript during in-flight cold-start recovery clears the persisted selected thread',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
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
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        if (!clientsById['conn_secondary']!.connectGate!.isCompleted) {
          clientsById['conn_secondary']!.connectGate!.complete();
        }
        controller.dispose();
        await closeClients(clientsById);
      });

      final initialization = controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
      );
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_saved');

      controller.selectedLaneBinding!.sessionController.clearTranscript();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.debugLatestUnsavedRecoveryState?.selectedThreadId,
        isNull,
      );
      expect((await recoveryStore.load())?.selectedThreadId, isNull);

      clientsById['conn_secondary']!.connectGate!.complete();
      await initialization;
    },
  );

  test(
    'lifecycle persistence after failed cold-start recovery keeps the selected thread for the next launch retry',
    () async {
      const initialRecoveryState = ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_secondary',
        selectedThreadId: 'thread_saved',
        draftText: 'Restore my draft',
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: initialRecoveryState,
      );
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexAppServerException('connect failed');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_saved');

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );

      expect((await recoveryStore.load())?.selectedThreadId, 'thread_saved');
    },
  );

  test(
    'debounced persistence after failed cold-start recovery keeps the selected thread for the next launch retry',
    () async {
      const initialRecoveryState = ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_secondary',
        selectedThreadId: 'thread_saved',
        draftText: 'Restore my draft',
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: initialRecoveryState,
      );
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexAppServerException('connect failed');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(milliseconds: 10),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_saved');
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
