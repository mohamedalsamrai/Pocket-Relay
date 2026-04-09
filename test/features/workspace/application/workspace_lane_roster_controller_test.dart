import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_lane_roster_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

void main() {
  test('orders live binding ids by saved catalog order', () {
    final roster = WorkspaceLaneRosterController();
    final primary = _buildBinding('conn_primary');
    final secondary = _buildBinding('conn_secondary');

    roster.putBinding('conn_secondary', secondary.binding);
    roster.putBinding('conn_primary', primary.binding);

    expect(
      roster.orderedLiveConnectionIds(
        _catalog(<String>['conn_primary', 'conn_secondary', 'conn_tertiary']),
      ),
      <String>['conn_primary', 'conn_secondary'],
    );
  });

  test('plans selected lane fallback from the removed lane index', () {
    final roster = WorkspaceLaneRosterController();
    final primary = _buildBinding('conn_primary');
    final secondary = _buildBinding('conn_secondary');
    final tertiary = _buildBinding('conn_tertiary');
    roster.putBinding('conn_primary', primary.binding);
    roster.putBinding('conn_secondary', secondary.binding);
    roster.putBinding('conn_tertiary', tertiary.binding);
    final state = _workspaceState(
      catalog: _catalog(<String>[
        'conn_primary',
        'conn_secondary',
        'conn_tertiary',
      ]),
      liveConnectionIds: <String>[
        'conn_primary',
        'conn_secondary',
        'conn_tertiary',
      ],
      selectedConnectionId: 'conn_secondary',
    );

    roster.removeBinding('conn_secondary');
    final plan = roster.planTerminationAfterRemoval(
      state: state,
      removedConnectionId: 'conn_secondary',
    );

    expect(plan.liveConnectionIds, <String>['conn_primary', 'conn_tertiary']);
    expect(plan.selectedConnectionId, 'conn_tertiary');
    expect(plan.viewport, ConnectionWorkspaceViewport.liveLane);
    expect(plan.shouldClearSelectedConnectionId, isFalse);
  });

  test('plans dormant roster fallback after removing the last live lane', () {
    final roster = WorkspaceLaneRosterController();
    final primary = _buildBinding('conn_primary');
    roster.putBinding('conn_primary', primary.binding);
    final state = _workspaceState(
      catalog: _catalog(<String>['conn_primary', 'conn_secondary']),
      liveConnectionIds: <String>['conn_primary'],
      selectedConnectionId: 'conn_primary',
    );

    roster.removeBinding('conn_primary');
    final plan = roster.planTerminationAfterRemoval(
      state: state,
      removedConnectionId: 'conn_primary',
    );

    expect(plan.liveConnectionIds, isEmpty);
    expect(plan.selectedConnectionId, isNull);
    expect(plan.viewport, ConnectionWorkspaceViewport.savedConnections);
    expect(plan.shouldClearSelectedConnectionId, isTrue);
  });
}

({ConnectionLaneBinding binding, FakeCodexAppServerClient client})
_buildBinding(String connectionId) {
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
  required List<String> liveConnectionIds,
  required String? selectedConnectionId,
}) {
  return ConnectionWorkspaceState(
    isLoading: false,
    catalog: catalog,
    liveConnectionIds: liveConnectionIds,
    selectedConnectionId: selectedConnectionId,
    viewport: ConnectionWorkspaceViewport.liveLane,
    savedSettingsReconnectRequiredConnectionIds: const <String>{},
    transportReconnectRequiredConnectionIds: const <String>{},
    transportRecoveryPhasesByConnectionId:
        const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
    liveReattachPhasesByConnectionId:
        const <String, ConnectionWorkspaceLiveReattachPhase>{},
    recoveryDiagnosticsByConnectionId:
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
