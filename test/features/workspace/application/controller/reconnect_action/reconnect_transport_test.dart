import '../controller_test_support.dart';

void main() {
  test(
    'reconnectConnection on a transport-loss lane reconnects through the existing binding before clearing transport recovery state',
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
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');
      await clientsByConnectionId['conn_primary']!.first.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);
      await clientsByConnectionId['conn_primary']!.first.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );

      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, same(firstBinding));
      expect(clientsByConnectionId['conn_primary'], hasLength(1));
      expect(clientsByConnectionId['conn_primary']!.first.connectCalls, 2);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        isNull,
      );
    },
  );

  test(
    'reconnectConnection preserves reconnect-required state if transport drops during history assessment',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final client = clientsById['conn_primary']!
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        );
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      client.readThreadCalls.clear();
      await client.disconnect();
      await Future<void>.delayed(Duration.zero);

      client.readThreadWithTurnsGate = Completer<void>();
      final reconnectFuture = controller.reconnectConnection('conn_primary');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(client.readThreadCalls, contains('thread_saved'));

      await client.disconnect();
      await Future<void>.delayed(Duration.zero);
      client.readThreadWithTurnsGate!.complete();
      await reconnectFuture;

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.transportLost,
      );
    },
  );
}
