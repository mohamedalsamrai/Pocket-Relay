import '../controller_test_support.dart';

void main() {
  test(
    'initialization keeps live reattach as the default when cold-start resume replays pending requests',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'input_restore_1',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_saved',
          'turnId': 'turn_restore_1',
          'itemId': 'item_restore_1',
          'questions': <Object?>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Name',
              'question': 'What is your name?',
            },
          ],
        },
      );
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      clientsById['conn_secondary']!
              .resumeThreadReplayEventsByThreadId['thread_saved'] =
          <CodexAppServerEvent>[replayedRequest];
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

      final binding = controller.selectedLaneBinding;
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(binding, isNotNull);
      expect(binding!.composerDraftHost.draft.text, 'Restore my draft');
      expect(
        clientsById['conn_secondary']!
            .startSessionRequests
            .single
            .resumeThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.sessionState.pendingUserInputRequests
            .containsKey('input_restore_1'),
        isTrue,
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .map((block) => block.body),
        contains('Restored answer'),
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.liveReattached,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_secondary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.liveReattached,
      );
    },
  );
}
