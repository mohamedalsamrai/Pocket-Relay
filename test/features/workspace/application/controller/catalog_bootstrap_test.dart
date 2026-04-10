import 'controller_test_support.dart';

void main() {
  test(
    'initializes an empty catalog into the dormant workspace state',
    () async {
      final controller = buildWorkspaceController(
        clientsById: <String, FakeCodexAppServerClient>{},
        repository: MemoryCodexConnectionRepository(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.catalog, const ConnectionCatalogState.empty());
      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.nonLiveSavedConnectionIds, isEmpty);
      expect(controller.state.selectedConnectionId, isNull);
      expect(
        controller.state.viewport,
        ConnectionWorkspaceViewport.savedConnections,
      );
      expect(controller.selectedLaneBinding, isNull);
    },
  );

  test(
    'refreshRemoteRuntime stores inspected remote server state on the workspace controller',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: const StaticRemoteOwnerInspector(
          CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'conn_primary',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.running,
            sessionName: 'pocket-relay-conn_primary',
            endpoint: CodexRemoteAppServerEndpoint(
              host: '127.0.0.1',
              port: 4100,
            ),
            detail: 'Managed remote app-server is ready.',
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      final runtime = await controller.refreshRemoteRuntime(
        connectionId: 'conn_primary',
      );

      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.port, 4100);
      expect(controller.state.remoteRuntimeFor('conn_primary'), runtime);
    },
  );

  test(
    'refreshRemoteRuntime stores a typed probe failure when host verification throws',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const ThrowingRemoteHostProbe(
          'ssh probe failed',
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      final runtime = await controller.refreshRemoteRuntime(
        connectionId: 'conn_primary',
      );

      expect(
        runtime.hostCapability.status,
        ConnectionRemoteHostCapabilityStatus.probeFailed,
      );
      expect(
        runtime.hostCapability.detail,
        contains('[${PocketErrorCatalog.connectionRuntimeProbeFailed.code}]'),
      );
      expect(runtime.hostCapability.detail, contains('ssh probe failed'));
      expect(controller.state.remoteRuntimeFor('conn_primary'), runtime);
    },
  );

  test(
    'saveSavedConnection clears cached remote runtime when the connection becomes local',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: const StaticRemoteOwnerInspector(
          CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'conn_secondary',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.running,
            sessionName: 'pocket-relay-conn_secondary',
            endpoint: CodexRemoteAppServerEndpoint(
              host: '127.0.0.1',
              port: 4101,
            ),
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.refreshRemoteRuntime(connectionId: 'conn_secondary');
      expect(controller.state.remoteRuntimeFor('conn_secondary'), isNotNull);

      await controller.saveSavedConnection(
        connectionId: 'conn_secondary',
        profile: workspaceProfile(
          'Secondary Box',
          'secondary.local',
        ).copyWith(connectionMode: ConnectionMode.local),
        secrets: const ConnectionSecrets(password: 'secret-2'),
      );

      expect(controller.state.remoteRuntimeFor('conn_secondary'), isNull);
    },
  );

  test(
    'startRemoteServer refreshes controller runtime after an explicit start action',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final ownerControl = MutableRemoteOwnerControl(
        snapshot: const CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.missing,
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: ownerControl,
        remoteAppServerOwnerInspector: ownerControl,
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      final runtime = await controller.startRemoteServer(
        connectionId: 'conn_primary',
      );

      expect(ownerControl.startCalls, 1);
      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.port, 4100);
      expect(
        controller.state.remoteRuntimeFor('conn_primary')?.server.status,
        ConnectionRemoteServerStatus.running,
      );
      expect(
        controller.state.remoteRuntimeFor('conn_primary')?.server.port,
        4100,
      );
    },
  );

  test(
    'startRemoteServer applies the follow-up probe runtime before rethrowing a failed action',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final ownerControl = _ThrowingStartRemoteOwnerControl(
        snapshot: const CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.missing,
          sessionName: 'pocket-relay-conn_primary',
          detail: 'No managed remote app-server is running.',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: ownerControl,
        remoteAppServerOwnerInspector: ownerControl,
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await expectLater(
        () => controller.startRemoteServer(connectionId: 'conn_primary'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'start failed',
          ),
        ),
      );

      expect(ownerControl.startCalls, 1);
      expect(
        controller.state.remoteRuntimeFor('conn_primary')?.server.status,
        ConnectionRemoteServerStatus.notRunning,
      );
    },
  );

  test(
    'stopRemoteServer refreshes controller runtime after an explicit stop action',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final ownerControl = MutableRemoteOwnerControl(
        snapshot: const CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.running,
          sessionName: 'pocket-relay-conn_primary',
          endpoint: CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: ownerControl,
        remoteAppServerOwnerInspector: ownerControl,
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      final runtime = await controller.stopRemoteServer(
        connectionId: 'conn_primary',
      );

      expect(ownerControl.stopCalls, 1);
      expect(runtime.server.status, ConnectionRemoteServerStatus.notRunning);
      expect(
        controller.state.remoteRuntimeFor('conn_primary')?.server.status,
        ConnectionRemoteServerStatus.notRunning,
      );
    },
  );

  test(
    'restartRemoteServer refreshes controller runtime after an explicit restart action',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final ownerControl = MutableRemoteOwnerControl(
        snapshot: const CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.running,
          sessionName: 'pocket-relay-conn_primary',
          endpoint: CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: ownerControl,
        remoteAppServerOwnerInspector: ownerControl,
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      final runtime = await controller.restartRemoteServer(
        connectionId: 'conn_primary',
      );

      expect(ownerControl.restartCalls, 1);
      expect(ownerControl.stopCalls, 1);
      expect(ownerControl.startCalls, 1);
      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.port, 4100);
    },
  );

  test('initializes one live lane and keeps the rest dormant', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_secondary',
    ]);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
    expect(controller.selectedLaneBinding?.connectionId, 'conn_primary');
    expect(controller.bindingForConnectionId('conn_secondary'), isNull);
  });
}

final class _ThrowingStartRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  _ThrowingStartRemoteOwnerControl({
    required CodexRemoteAppServerOwnerSnapshot snapshot,
  }) : _snapshot = snapshot;

  final CodexRemoteAppServerOwnerSnapshot _snapshot;
  int startCalls = 0;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return _snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('restart should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls += 1;
    throw StateError('start failed');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('stop should not have been requested');
  }
}
