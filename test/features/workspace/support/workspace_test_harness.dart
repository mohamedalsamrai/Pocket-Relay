import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

ConnectionWorkspaceController buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  CodexConnectionRepository? repository,
  ConnectionModelCatalogStore? modelCatalogStore,
  ConnectionWorkspaceRecoveryStore? recoveryStore,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const ThrowingRemoteOwnerInspector(),
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const ThrowingRemoteOwnerControl(),
  Duration? recoveryPersistenceDebounceDuration,
  WorkspaceNow? now,
}) {
  final resolvedRepository =
      repository ??
      MemoryCodexConnectionRepository(
        initialConnections: _defaultWorkspaceConnections(),
      );
  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    modelCatalogStore: modelCatalogStore,
    recoveryStore: recoveryStore,
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
    recoveryPersistenceDebounceDuration:
        recoveryPersistenceDebounceDuration ??
        const Duration(milliseconds: 250),
    now: now,
    laneBindingFactory:
        ({required laneId, required connectionId, required connection}) {
          final appServerClient = clientsById[connectionId]!;
          return ConnectionLaneBinding(
            laneId: laneId,
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: resolvedRepository,
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
}

ConnectionWorkspaceController buildWorkspaceControllerWithTrackedClients({
  required MemoryCodexConnectionRepository repository,
  required Map<String, List<FakeCodexAppServerClient>> clientsByConnectionId,
  ConnectionWorkspaceRecoveryStore? recoveryStore,
  Duration? recoveryPersistenceDebounceDuration,
  WorkspaceNow? now,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const ThrowingRemoteOwnerInspector(),
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const ThrowingRemoteOwnerControl(),
  void Function(FakeCodexAppServerClient client, String connectionId)?
  configureClient,
}) {
  return ConnectionWorkspaceController(
    connectionRepository: repository,
    recoveryStore: recoveryStore,
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
    recoveryPersistenceDebounceDuration:
        recoveryPersistenceDebounceDuration ??
        const Duration(milliseconds: 250),
    now: now,
    laneBindingFactory:
        ({required laneId, required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          configureClient?.call(appServerClient, connectionId);
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            laneId: laneId,
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
}

ConnectionWorkspaceController buildSingleConnectionWorkspaceController({
  required FakeCodexAppServerClient client,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const ThrowingRemoteOwnerInspector(),
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const ThrowingRemoteOwnerControl(),
  Duration? recoveryPersistenceDebounceDuration,
  WorkspaceNow? now,
  SavedConnection? connection,
}) {
  final savedConnection =
      connection ??
      SavedConnection(
        id: 'conn_primary',
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );
  final repository = MemoryCodexConnectionRepository(
    initialConnections: <SavedConnection>[savedConnection],
  );
  return ConnectionWorkspaceController(
    connectionRepository: repository,
    recoveryPersistenceDebounceDuration:
        recoveryPersistenceDebounceDuration ??
        const Duration(milliseconds: 250),
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
    now: now,
    laneBindingFactory:
        ({required laneId, required connectionId, required connection}) {
          return ConnectionLaneBinding(
            laneId: laneId,
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
  );
}

class ThrowingConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  const ThrowingConnectionWorkspaceRecoveryStore(this.error);

  final Object error;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    throw error;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {}
}

final class FakeRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const FakeRemoteHostProbe(this.capabilities);

  final CodexRemoteAppServerHostCapabilities capabilities;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return capabilities;
  }
}

final class ThrowingRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const ThrowingRemoteHostProbe(this.message);

  final String message;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    throw StateError(message);
  }
}

final class StaticRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const StaticRemoteOwnerInspector(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class ThrowingRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const ThrowingRemoteOwnerInspector();

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('owner inspection should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class MapRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const MapRemoteOwnerInspector(this.snapshotsByOwnerId);

  final Map<String, CodexRemoteAppServerOwnerSnapshot> snapshotsByOwnerId;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshotsByOwnerId[ownerId] ??
        notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class ThrowingRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const ThrowingRemoteOwnerControl();

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
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
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }
}

final class StaticRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const StaticRemoteOwnerControl(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }
}

typedef RemoteOwnerControlCall = ({
  ConnectionProfile profile,
  ConnectionSecrets secrets,
  String ownerId,
  String workspaceDir,
});

final class RecordingRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  final List<RemoteOwnerControlCall> startCalls = <RemoteOwnerControlCall>[];
  final List<RemoteOwnerControlCall> stopCalls = <RemoteOwnerControlCall>[];
  final List<RemoteOwnerControlCall> restartCalls = <RemoteOwnerControlCall>[];

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }
}

final class StatefulRemoteOwnerRuntime
    implements
        CodexRemoteAppServerOwnerInspector,
        CodexRemoteAppServerOwnerControl {
  StatefulRemoteOwnerRuntime({
    Map<String, CodexRemoteAppServerOwnerStatus>? statusesByOwnerId,
  }) : _statusesByOwnerId = Map<String, CodexRemoteAppServerOwnerStatus>.from(
         statusesByOwnerId ?? const <String, CodexRemoteAppServerOwnerStatus>{},
       );

  final Map<String, CodexRemoteAppServerOwnerStatus> _statusesByOwnerId;
  final List<RemoteOwnerControlCall> startCalls = <RemoteOwnerControlCall>[];
  final List<RemoteOwnerControlCall> stopCalls = <RemoteOwnerControlCall>[];
  final List<RemoteOwnerControlCall> restartCalls = <RemoteOwnerControlCall>[];

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.running;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.stopped;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.running;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  CodexRemoteAppServerOwnerSnapshot _snapshotFor(
    String ownerId, {
    required String workspaceDir,
  }) {
    return switch (_statusesByOwnerId[ownerId] ??
        CodexRemoteAppServerOwnerStatus.stopped) {
      CodexRemoteAppServerOwnerStatus.running => runningOwnerSnapshot(
        ownerId,
        workspaceDir: workspaceDir,
      ),
      CodexRemoteAppServerOwnerStatus.unhealthy =>
        CodexRemoteAppServerOwnerSnapshot(
          ownerId: ownerId,
          workspaceDir: workspaceDir,
          status: CodexRemoteAppServerOwnerStatus.unhealthy,
          sessionName: 'pocket-relay-$ownerId',
          endpoint: const CodexRemoteAppServerEndpoint(
            host: '127.0.0.1',
            port: 4100,
          ),
          detail: 'readyz failed',
        ),
      CodexRemoteAppServerOwnerStatus.missing ||
      CodexRemoteAppServerOwnerStatus.stopped => notRunningOwnerSnapshot(
        ownerId,
        workspaceDir: workspaceDir,
      ),
    };
  }
}

ConnectionProfile workspaceProfile(
  String label,
  String host, {
  String workspaceDir = '/workspace',
}) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: workspaceDir,
  );
}

CodexRemoteAppServerOwnerSnapshot notRunningOwnerSnapshot(
  String ownerId, {
  String workspaceDir = '/workspace',
}) {
  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: CodexRemoteAppServerOwnerStatus.stopped,
    sessionName: 'pocket-relay-$ownerId',
  );
}

CodexRemoteAppServerOwnerSnapshot runningOwnerSnapshot(
  String ownerId, {
  String workspaceDir = '/workspace',
}) {
  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: CodexRemoteAppServerOwnerStatus.running,
    sessionName: 'pocket-relay-$ownerId',
    endpoint: const CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
  );
}

CodexAppServerThreadHistory savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

Map<String, FakeCodexAppServerClient> buildClientsById([
  String firstConnectionId = 'conn_primary',
  String? secondConnectionId,
]) {
  final secondaryClients = secondConnectionId == null
      ? null
      : <String, FakeCodexAppServerClient>{
          secondConnectionId: FakeCodexAppServerClient(),
        };
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    ...?secondaryClients,
  };
}

Future<void> closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

Future<void> closeClientLists(
  Map<String, List<FakeCodexAppServerClient>> clientsByConnectionId,
) async {
  for (final clients in clientsByConnectionId.values) {
    for (final client in clients) {
      await client.close();
    }
  }
}

List<SavedConnection> _defaultWorkspaceConnections() {
  return <SavedConnection>[
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
  ];
}
