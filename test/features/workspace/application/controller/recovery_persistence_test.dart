import 'controller_test_support.dart';

void main() {
  test(
    'inactive without pause snapshots recovery state but does not reconnect the selected lane',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore();
      final snapshotTime = DateTime(2026, 3, 22, 14, 5);
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Keep me');

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      final backgroundedRecoveryState = await recoveryStore.load();
      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      final recoveryState = await recoveryStore.load();
      expect(nextBinding, same(firstBinding));
      expect(clientsById['conn_primary']!.disconnectCalls, 0);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(backgroundedRecoveryState, isNotNull);
      expect(backgroundedRecoveryState!.draftText, 'Keep me');
      expect(backgroundedRecoveryState.backgroundedAt, snapshotTime);
      expect(
        backgroundedRecoveryState.backgroundedLifecycleState,
        ConnectionWorkspaceBackgroundLifecycleState.inactive,
      );
      expect(recoveryState, isNotNull);
      expect(recoveryState!.backgroundedAt, isNull);
      expect(recoveryState.backgroundedLifecycleState, isNull);
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnostics, isNotNull);
      expect(diagnostics!.lastResumedAt, snapshotTime);
      expect(diagnostics.lastBackgroundedAt, isNull);
    },
  );

  test(
    'resumed restores the persisted selected conversation when the live lane lost visible conversation state',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore();
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
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(Duration.zero);
      await recoveryStore.save(
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_saved',
          draftText: '',
        ),
      );

      binding.sessionController.clearTranscript();
      await Future<void>.delayed(Duration.zero);
      await recoveryStore.save(
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_saved',
          draftText: '',
        ),
      );

      expect(binding.sessionController.transcriptBlocks, isEmpty);
      expect(binding.sessionController.sessionState.rootThreadId, isNull);

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      expect(
        binding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        clientsById['conn_primary']!.readThreadCalls,
        contains('thread_saved'),
      );
    },
  );

  test(
    'resumed falls back to persisted recovery state when the latest unsaved snapshot has no selected thread',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = FixedLoadConnectionWorkspaceRecoveryStore(
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_saved',
          draftText: '',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(Duration.zero);

      binding.sessionController.clearTranscript();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.debugLatestUnsavedRecoveryState?.selectedThreadId,
        null,
      );
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_saved');
      expect(binding.sessionController.transcriptBlocks, isEmpty);
      expect(binding.sessionController.sessionState.rootThreadId, isNull);

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      expect(
        binding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .single
            .body,
        'Restored answer',
      );
    },
  );

  test(
    'resumed does not restore a stale conversation after lane selection changes during recovery load',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = DelayedLoadConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_saved',
          draftText: '',
        ),
        immediateLoadCount: 1,
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        if (!recoveryStore.loadCompleter.isCompleted) {
          recoveryStore.loadCompleter.complete();
        }
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      final binding = controller.bindingForConnectionId('conn_primary')!;
      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(Duration.zero);
      binding.sessionController.clearTranscript();
      await Future<void>.delayed(Duration.zero);
      final readThreadCallsBeforeResume = List<String>.of(
        clientsById['conn_primary']!.readThreadCalls,
      );

      final resumeFuture = controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await Future<void>.delayed(Duration.zero);

      controller.showSavedConnections();
      recoveryStore.loadCompleter.complete();
      await resumeFuture;

      expect(controller.state.isShowingSavedConnections, isTrue);
      expect(binding.sessionController.sessionState.rootThreadId, isNull);
      expect(binding.sessionController.transcriptBlocks, isEmpty);
      expect(
        clientsById['conn_primary']!.readThreadCalls,
        readThreadCallsBeforeResume,
      );
    },
  );

  test(
    'selected lane draft bursts debounce into one persisted recovery snapshot',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final recoveryStore = RecordingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
      );
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
      recoveryStore.savedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      binding.restoreComposerDraft('D');
      binding.restoreComposerDraft('Dr');
      binding.restoreComposerDraft('Draft');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.savedStates, hasLength(1));
      expect(recoveryStore.savedStates.single?.draftText, 'Draft');
      expect(recoveryStore.savedStates.single?.connectionId, 'conn_primary');
    },
  );

  test('dispose flushes a pending debounced recovery snapshot', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final recoveryStore = RecordingConnectionWorkspaceRecoveryStore(
      initialState: const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        draftText: '',
      ),
    );
    final controller = buildWorkspaceController(
      clientsById: clientsById,
      recoveryStore: recoveryStore,
      recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
    );
    addTearDown(() async {
      await closeClients(clientsById);
    });

    await controller.initialize();
    recoveryStore.savedStates.clear();
    final binding = controller.bindingForConnectionId('conn_primary')!;

    binding.restoreComposerDraft('Pending draft');
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(recoveryStore.savedStates, isNotEmpty);
    expect(recoveryStore.savedStates.last?.connectionId, 'conn_primary');
    expect(recoveryStore.savedStates.last?.draftText, 'Pending draft');
  });

  test(
    'selected lane thread changes persist immediately without waiting for debounce',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = RecordingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      recoveryStore.savedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.savedStates, isNotEmpty);
      expect(recoveryStore.savedStates.last?.connectionId, 'conn_primary');
      expect(recoveryStore.savedStates.last?.selectedThreadId, 'thread_saved');
    },
  );

  test(
    'selected lane thread reversion during an in-flight save still persists the reverted snapshot',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_a'] =
          savedConversationThread(threadId: 'thread_a');
      clientsById['conn_primary']!.threadHistoriesById['thread_b'] =
          savedConversationThread(threadId: 'thread_b');
      final recoveryStore = DelayedFirstSaveConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_a',
          draftText: '',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
      );
      addTearDown(() async {
        if (!recoveryStore.firstSaveCompleter.isCompleted) {
          recoveryStore.firstSaveCompleter.complete();
        }
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      recoveryStore.attemptedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      await binding.sessionController.selectConversationForResume('thread_b');
      await Future<void>.delayed(Duration.zero);
      await binding.sessionController.selectConversationForResume('thread_a');
      await Future<void>.delayed(Duration.zero);

      recoveryStore.firstSaveCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.attemptedStates, isNotEmpty);
      expect(recoveryStore.attemptedStates.last?.selectedThreadId, 'thread_a');
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_a');
    },
  );

  test(
    'failed recovery persistence keeps the latest selected thread as unsaved state',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = ToggleableFailingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_stale',
          draftText: '',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      recoveryStore.saveError = StateError('secure storage write failed');

      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.debugLatestUnsavedRecoveryState?.selectedThreadId,
        'thread_saved',
      );
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_stale');
    },
  );

  test('non-selected lane changes do not persist recovery snapshots', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final recoveryStore = RecordingConnectionWorkspaceRecoveryStore(
      initialState: const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        draftText: '',
      ),
    );
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
    await controller.instantiateConnection('conn_secondary');
    controller.selectConnection('conn_primary');
    recoveryStore.savedStates.clear();

    controller
        .bindingForConnectionId('conn_secondary')!
        .restoreComposerDraft('Ignored draft');
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(recoveryStore.savedStates, isEmpty);
    expect(await recoveryStore.load(), recoveryStore.initialState);
  });

  test(
    'selected lane recovery persistence failures are recorded in recovery diagnostics',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final snapshotTime = DateTime(2026, 3, 27, 14, 10);
      final recoveryStore = ToggleableFailingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
        saveError: StateError('secure storage write failed'),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      binding.restoreComposerDraft('Draft that should persist');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.attemptedStates, hasLength(1));
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnostics, isNotNull);
      expect(
        diagnostics!.lastRecoveryPersistenceFailureAt,
        snapshotTime.toUtc(),
      );
      expect(
        diagnostics.lastRecoveryPersistenceFailureDetail,
        'secure storage write failed',
      );
      expect(await recoveryStore.load(), recoveryStore.initialState);
    },
  );

  test(
    'selected lane recovery persistence clears stale failure detail after a later successful save',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final snapshotTime = DateTime(2026, 3, 27, 14, 20);
      final recoveryStore = ToggleableFailingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
        saveError: StateError('secure storage write failed'),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      binding.restoreComposerDraft('Failed draft');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final diagnosticsAfterFailure = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(
        diagnosticsAfterFailure?.lastRecoveryPersistenceFailureDetail,
        'secure storage write failed',
      );

      recoveryStore.saveError = null;
      binding.restoreComposerDraft('Recovered draft');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.attemptedStates, hasLength(2));
      final diagnosticsAfterSuccess = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnosticsAfterSuccess, isNotNull);
      expect(diagnosticsAfterSuccess!.lastRecoveryPersistenceFailureAt, isNull);
      expect(
        diagnosticsAfterSuccess.lastRecoveryPersistenceFailureDetail,
        isNull,
      );
      expect(
        await recoveryStore.load(),
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: 'Recovered draft',
        ),
      );
    },
  );
}
