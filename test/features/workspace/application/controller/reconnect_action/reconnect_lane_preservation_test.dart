import '../controller_test_support.dart';

void main() {
  test(
    'reconnectConnection does not leave a manual recovery attempt in flight for saved-settings-only reconnects',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );

      await controller.reconnectConnection('conn_primary');

      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(diagnostics?.lastRecoveryOrigin, isNull);
      expect(diagnostics?.lastRecoveryStartedAt, isNull);
      expect(diagnostics?.lastRecoveryCompletedAt, isNull);
    },
  );

  test(
    'reconnectConnection replaces the targeted live binding and clears reconnect-required state',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = buildWorkspaceControllerWithTrackedClients(
        repository: repository,
        clientsByConnectionId: clientsByConnectionId,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(nextBinding?.sessionController.profile.host, 'primary.changed');
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 1);
      expect(clientsByConnectionId['conn_primary']!.last.disconnectCalls, 0);
    },
  );

  test(
    'reconnectConnection preserves an explicitly resumed transcript selection on the recreated lane',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = buildWorkspaceControllerWithTrackedClients(
        repository: repository,
        clientsByConnectionId: clientsByConnectionId,
        configureClient: (client, connectionId) {
          client.threadHistoriesById['thread_saved'] = savedConversationThread(
            threadId: 'thread_saved',
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      await controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_saved',
      );
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(clientsByConnectionId['conn_primary'], hasLength(3));
      expect(
        clientsByConnectionId['conn_primary']!.last.readThreadCalls,
        <String>['thread_saved'],
      );
      expect(
        nextBinding!.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        nextBinding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
    },
  );
}
