import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_lane_roster_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

void main() {
  test('orders live lanes by saved catalog order', () {
    final roster = WorkspaceLaneRosterController();
    final primary = _buildBinding('lane_primary', 'conn_primary');
    final secondary = _buildBinding('lane_secondary', 'conn_secondary');

    roster.putBinding('lane_secondary', secondary.binding);
    roster.putBinding('lane_primary', primary.binding);

    expect(
      roster.orderedLiveLanes(
        _catalog(<String>['conn_primary', 'conn_secondary', 'conn_tertiary']),
        const <ConnectionWorkspaceLiveLane>[
          ConnectionWorkspaceLiveLane(
            laneId: 'lane_secondary',
            connectionId: 'conn_secondary',
          ),
          ConnectionWorkspaceLiveLane(
            laneId: 'lane_primary',
            connectionId: 'conn_primary',
          ),
        ],
      ),
      const <ConnectionWorkspaceLiveLane>[
        ConnectionWorkspaceLiveLane(
          laneId: 'lane_primary',
          connectionId: 'conn_primary',
        ),
        ConnectionWorkspaceLiveLane(
          laneId: 'lane_secondary',
          connectionId: 'conn_secondary',
        ),
      ],
    );
  });

  test('plans selected lane fallback from the removed lane index', () {
    final roster = WorkspaceLaneRosterController();
    final primary = _buildBinding('lane_primary', 'conn_primary');
    final secondary = _buildBinding('lane_secondary', 'conn_secondary');
    final tertiary = _buildBinding('lane_tertiary', 'conn_tertiary');
    roster.putBinding('lane_primary', primary.binding);
    roster.putBinding('lane_secondary', secondary.binding);
    roster.putBinding('lane_tertiary', tertiary.binding);
    final state = _workspaceState(
      catalog: _catalog(<String>[
        'conn_primary',
        'conn_secondary',
        'conn_tertiary',
      ]),
      liveLanes: const <ConnectionWorkspaceLiveLane>[
        ConnectionWorkspaceLiveLane(
          laneId: 'lane_primary',
          connectionId: 'conn_primary',
        ),
        ConnectionWorkspaceLiveLane(
          laneId: 'lane_secondary',
          connectionId: 'conn_secondary',
        ),
        ConnectionWorkspaceLiveLane(
          laneId: 'lane_tertiary',
          connectionId: 'conn_tertiary',
        ),
      ],
      selectedLaneId: 'lane_secondary',
    );

    roster.removeBinding('lane_secondary');
    final plan = roster.planTerminationAfterRemoval(
      state: state,
      removedLaneId: 'lane_secondary',
    );

    expect(plan.liveLanes, const <ConnectionWorkspaceLiveLane>[
      ConnectionWorkspaceLiveLane(
        laneId: 'lane_primary',
        connectionId: 'conn_primary',
      ),
      ConnectionWorkspaceLiveLane(
        laneId: 'lane_tertiary',
        connectionId: 'conn_tertiary',
      ),
    ]);
    expect(plan.selectedLaneId, 'lane_tertiary');
    expect(plan.viewport, ConnectionWorkspaceViewport.liveLane);
  });

  test('plans dormant roster fallback after removing the last live lane', () {
    final roster = WorkspaceLaneRosterController();
    final primary = _buildBinding('lane_primary', 'conn_primary');
    roster.putBinding('lane_primary', primary.binding);
    final state = _workspaceState(
      catalog: _catalog(<String>['conn_primary', 'conn_secondary']),
      liveLanes: const <ConnectionWorkspaceLiveLane>[
        ConnectionWorkspaceLiveLane(
          laneId: 'lane_primary',
          connectionId: 'conn_primary',
        ),
      ],
      selectedLaneId: 'lane_primary',
    );

    roster.removeBinding('lane_primary');
    final plan = roster.planTerminationAfterRemoval(
      state: state,
      removedLaneId: 'lane_primary',
    );

    expect(plan.liveLanes, isEmpty);
    expect(plan.selectedLaneId, isNull);
    expect(plan.viewport, ConnectionWorkspaceViewport.savedConnections);
  });
}

({ConnectionLaneBinding binding, FakeCodexAppServerClient client})
_buildBinding(String laneId, String connectionId) {
  final client = FakeCodexAppServerClient();
  final savedProfile = SavedProfile(
    profile: _profile(connectionId),
    secrets: const ConnectionSecrets(password: 'secret'),
  );
  final repository = MemoryCodexConnectionRepository.single(
    connectionId: connectionId,
    savedProfile: savedProfile,
  );
  final binding = ConnectionLaneBinding(
    laneId: laneId,
    connectionId: connectionId,
    profileStore: ConnectionScopedProfileStore(
      connectionId: connectionId,
      connectionRepository: repository,
    ),
    appServerClient: client,
    initialSavedProfile: savedProfile,
    ownsAppServerClient: false,
  );
  addTearDown(() async {
    binding.dispose();
    await client.dispose();
  });
  return (binding: binding, client: client);
}

ConnectionCatalogState _catalog(List<String> connectionIds) {
  return ConnectionCatalogState(
    orderedConnectionIds: connectionIds,
    connectionsById: <String, SavedConnectionSummary>{
      for (final connectionId in connectionIds)
        connectionId: SavedConnectionSummary(
          id: connectionId,
          profile: _profile(connectionId),
        ),
    },
  );
}

ConnectionWorkspaceState _workspaceState({
  required ConnectionCatalogState catalog,
  required List<ConnectionWorkspaceLiveLane> liveLanes,
  required String? selectedLaneId,
}) {
  return ConnectionWorkspaceState(
    isLoading: false,
    catalog: catalog,
    liveLanes: liveLanes,
    selectedLaneId: selectedLaneId,
    viewport: ConnectionWorkspaceViewport.liveLane,
    savedSettingsReconnectRequiredConnectionIds: const <String>{},
    transportReconnectRequiredLaneIds: const <String>{},
    transportRecoveryPhasesByLaneId:
        const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
    liveReattachPhasesByLaneId:
        const <String, ConnectionWorkspaceLiveReattachPhase>{},
    recoveryDiagnosticsByLaneId:
        const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
    remoteRuntimeByConnectionId: const <String, ConnectionRemoteRuntimeState>{},
  );
}

ConnectionProfile _profile(String connectionId) {
  return ConnectionProfile.defaults().copyWith(
    label: connectionId,
    host: '$connectionId.local',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}
