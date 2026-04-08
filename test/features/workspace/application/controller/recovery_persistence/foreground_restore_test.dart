import '../controller_test_support.dart';

void main() {
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
}
