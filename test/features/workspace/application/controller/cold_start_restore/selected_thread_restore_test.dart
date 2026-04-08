import '../controller_test_support.dart';

void main() {
  test(
    'initialization restores the persisted selected lane, draft, and transcript target',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final backgroundedAt = DateTime.utc(2026, 3, 22, 12, 30);
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedAt: backgroundedAt,
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

      _expectRestoredSelection(
        controller: controller,
        client: clientsById['conn_secondary']!,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
      );
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(diagnostics, isNotNull);
      expect(diagnostics!.lastBackgroundedAt, backgroundedAt);
      expect(
        diagnostics.lastBackgroundedLifecycleState,
        ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      expect(
        diagnostics.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(
        diagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.conversationRestored,
      );
    },
  );

  test(
    'initialization restores the persisted selected lane, draft, and transcript target from secure recovery storage',
    () async {
      final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
        SharedPreferences.setMockInitialValues(<String, Object>{});
      });

      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final secureStorage = FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final recoveryStore = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );
      await recoveryStore.save(
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
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

      _expectRestoredSelection(
        controller: controller,
        client: clientsById['conn_secondary']!,
      );
      expect(
        await preferences.getString('pocket_relay.workspace.recovery_state'),
        isNot(contains('Restore my draft')),
      );
      expect(
        secureStorage
            .data['pocket_relay.workspace.recovery_state.draft_text.conn_secondary'],
        'Restore my draft',
      );
    },
  );
}

void _expectRestoredSelection({
  required ConnectionWorkspaceController controller,
  required FakeCodexAppServerClient client,
}) {
  final binding = controller.selectedLaneBinding;
  expect(controller.state.selectedConnectionId, 'conn_secondary');
  expect(binding, isNotNull);
  expect(binding!.composerDraftHost.draft.text, 'Restore my draft');
  expect(binding.sessionController.sessionState.rootThreadId, 'thread_saved');
  expect(
    binding.sessionController.transcriptBlocks
        .whereType<TranscriptTextBlock>()
        .single
        .body,
    'Restored answer',
  );
  expect(client.startSessionRequests.single.resumeThreadId, 'thread_saved');
  expect(client.readThreadCalls, <String>[
    'thread_saved',
    'thread_saved',
    'thread_saved',
  ]);
  expect(client.connectCalls, 1);
  expect(
    controller.state.requiresTransportReconnect('conn_secondary'),
    isFalse,
  );
  expect(controller.state.transportRecoveryPhaseFor('conn_secondary'), isNull);
}
