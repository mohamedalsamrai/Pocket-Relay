import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_presentation.dart';

void main() {
  test(
    'successful live reattach stays in open lanes instead of needs attention',
    () {
      const connectionId = 'conn_primary';
      const laneId = 'lane_primary';
      final profile = ConnectionProfile.defaults().copyWith(
        label: 'Primary Box',
        host: 'primary.local',
        username: 'vince',
        workspaceDir: '/workspace',
        codexPath: 'codex',
      );
      const remoteRuntime = ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.supported(),
        server: ConnectionRemoteServerState.running(port: 7331),
      );
      final state = ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState(
          orderedConnectionIds: const <String>[connectionId],
          connectionsById: <String, SavedConnectionSummary>{
            connectionId: SavedConnectionSummary(
              id: connectionId,
              profile: profile,
            ),
          },
        ),
        liveLanes: const <ConnectionWorkspaceLiveLane>[
          ConnectionWorkspaceLiveLane(
            laneId: laneId,
            connectionId: connectionId,
          ),
        ],
        selectedLaneId: null,
        viewport: ConnectionWorkspaceViewport.savedConnections,
        savedSettingsReconnectRequiredConnectionIds: const <String>{},
        transportReconnectRequiredLaneIds: const <String>{},
        transportRecoveryPhasesByLaneId:
            const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        liveReattachPhasesByLaneId:
            const <String, ConnectionWorkspaceLiveReattachPhase>{
              laneId: ConnectionWorkspaceLiveReattachPhase.liveReattached,
            },
        recoveryDiagnosticsByLaneId:
            const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
        remoteRuntimeByConnectionId:
            const <String, ConnectionRemoteRuntimeState>{
              connectionId: remoteRuntime,
            },
      );

      final sections = connectionLifecycleSectionsFromState(
        state,
        isTransportConnected: (_) => true,
      );

      expect(
        sections.any(
          (section) =>
              section.id == ConnectionLifecycleSectionId.needsAttention,
        ),
        isFalse,
      );
      expect(sections.single.id, ConnectionLifecycleSectionId.openLanes);
      expect(sections.single.rows.single.connection.id, connectionId);
    },
  );

  test('fallback restore stays in open lanes instead of needs attention', () {
    const connectionId = 'conn_primary';
    const laneId = 'lane_primary';
    final profile = ConnectionProfile.defaults().copyWith(
      label: 'Primary Box',
      host: 'primary.local',
      username: 'vince',
      workspaceDir: '/workspace',
      codexPath: 'codex',
    );
    const remoteRuntime = ConnectionRemoteRuntimeState(
      hostCapability: ConnectionRemoteHostCapabilityState.supported(),
      server: ConnectionRemoteServerState.running(port: 7331),
    );
    final state = ConnectionWorkspaceState(
      isLoading: false,
      catalog: ConnectionCatalogState(
        orderedConnectionIds: const <String>[connectionId],
        connectionsById: <String, SavedConnectionSummary>{
          connectionId: SavedConnectionSummary(
            id: connectionId,
            profile: profile,
          ),
        },
      ),
      liveLanes: const <ConnectionWorkspaceLiveLane>[
        ConnectionWorkspaceLiveLane(laneId: laneId, connectionId: connectionId),
      ],
      selectedLaneId: null,
      viewport: ConnectionWorkspaceViewport.savedConnections,
      savedSettingsReconnectRequiredConnectionIds: const <String>{},
      transportReconnectRequiredLaneIds: const <String>{},
      transportRecoveryPhasesByLaneId:
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      liveReattachPhasesByLaneId:
          const <String, ConnectionWorkspaceLiveReattachPhase>{
            laneId: ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
          },
      recoveryDiagnosticsByLaneId:
          const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
      remoteRuntimeByConnectionId: const <String, ConnectionRemoteRuntimeState>{
        connectionId: remoteRuntime,
      },
    );

    final sections = connectionLifecycleSectionsFromState(
      state,
      isTransportConnected: (_) => true,
    );

    expect(
      sections.any(
        (section) => section.id == ConnectionLifecycleSectionId.needsAttention,
      ),
      isFalse,
    );
    expect(sections.single.id, ConnectionLifecycleSectionId.openLanes);
    expect(sections.single.rows.single.connection.id, connectionId);
  });

  test(
    'unsupported system capability stays off workspace rows and out of needs attention',
    () {
      const connectionId = 'conn_primary';
      final profile = ConnectionProfile.defaults().copyWith(
        label: 'Primary Box',
        host: 'primary.local',
        username: 'vince',
        workspaceDir: '/workspace',
        codexPath: 'codex',
      );
      const remoteRuntime = ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.unsupported(
          issues: <ConnectionRemoteHostCapabilityIssue>{
            ConnectionRemoteHostCapabilityIssue.remoteContinuityUnsupported,
          },
        ),
        server: ConnectionRemoteServerState.unknown(),
      );
      final state = ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState(
          orderedConnectionIds: const <String>[connectionId],
          connectionsById: <String, SavedConnectionSummary>{
            connectionId: SavedConnectionSummary(
              id: connectionId,
              profile: profile,
            ),
          },
        ),
        liveLanes: const <ConnectionWorkspaceLiveLane>[],
        selectedLaneId: null,
        viewport: ConnectionWorkspaceViewport.savedConnections,
        savedSettingsReconnectRequiredConnectionIds: const <String>{},
        transportReconnectRequiredLaneIds: const <String>{},
        transportRecoveryPhasesByLaneId:
            const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        liveReattachPhasesByLaneId:
            const <String, ConnectionWorkspaceLiveReattachPhase>{},
        recoveryDiagnosticsByLaneId:
            const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
        remoteRuntimeByConnectionId:
            const <String, ConnectionRemoteRuntimeState>{
              connectionId: remoteRuntime,
            },
      );

      final sections = connectionLifecycleSectionsFromState(
        state,
        isTransportConnected: (_) => false,
      );

      expect(sections.single.id, ConnectionLifecycleSectionId.savedConnections);
      expect(
        sections.single.rows.single.facts.where(
          (fact) => fact.label.startsWith('System:'),
        ),
        isEmpty,
      );
    },
  );
}
