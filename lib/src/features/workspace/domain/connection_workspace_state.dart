import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

part 'connection_workspace_recovery_models.dart';

@immutable
class ConnectionWorkspaceLiveLane {
  const ConnectionWorkspaceLiveLane({
    required this.laneId,
    required this.connectionId,
  });

  final String laneId;
  final String connectionId;

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceLiveLane &&
        other.laneId == laneId &&
        other.connectionId == connectionId;
  }

  @override
  int get hashCode => Object.hash(laneId, connectionId);
}

class ConnectionWorkspaceState {
  const ConnectionWorkspaceState({
    required this.isLoading,
    required this.catalog,
    this.systemCatalog = const SystemCatalogState.empty(),
    required this.liveLanes,
    required this.selectedLaneId,
    required this.viewport,
    this.recoveryLoadWarning,
    this.deviceContinuityWarnings =
        const ConnectionWorkspaceDeviceContinuityWarnings(),
    required this.savedSettingsReconnectRequiredConnectionIds,
    required this.transportReconnectRequiredLaneIds,
    required this.transportRecoveryPhasesByLaneId,
    required this.liveReattachPhasesByLaneId,
    required this.recoveryDiagnosticsByLaneId,
    required this.remoteRuntimeByConnectionId,
  });

  const ConnectionWorkspaceState.initial()
    : isLoading = true,
      catalog = const ConnectionCatalogState.empty(),
      systemCatalog = const SystemCatalogState.empty(),
      liveLanes = const <ConnectionWorkspaceLiveLane>[],
      selectedLaneId = null,
      viewport = ConnectionWorkspaceViewport.liveLane,
      recoveryLoadWarning = null,
      deviceContinuityWarnings =
          const ConnectionWorkspaceDeviceContinuityWarnings(),
      savedSettingsReconnectRequiredConnectionIds = const <String>{},
      transportReconnectRequiredLaneIds = const <String>{},
      transportRecoveryPhasesByLaneId =
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      liveReattachPhasesByLaneId =
          const <String, ConnectionWorkspaceLiveReattachPhase>{},
      recoveryDiagnosticsByLaneId =
          const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
      remoteRuntimeByConnectionId =
          const <String, ConnectionRemoteRuntimeState>{};

  final bool isLoading;
  final ConnectionCatalogState catalog;
  final SystemCatalogState systemCatalog;
  final List<ConnectionWorkspaceLiveLane> liveLanes;
  final String? selectedLaneId;
  final ConnectionWorkspaceViewport viewport;
  final PocketUserFacingError? recoveryLoadWarning;
  final ConnectionWorkspaceDeviceContinuityWarnings deviceContinuityWarnings;
  final Set<String> savedSettingsReconnectRequiredConnectionIds;
  final Set<String> transportReconnectRequiredLaneIds;
  final Map<String, ConnectionWorkspaceTransportRecoveryPhase>
  transportRecoveryPhasesByLaneId;
  final Map<String, ConnectionWorkspaceLiveReattachPhase>
  liveReattachPhasesByLaneId;
  final Map<String, ConnectionWorkspaceRecoveryDiagnostics>
  recoveryDiagnosticsByLaneId;
  final Map<String, ConnectionRemoteRuntimeState> remoteRuntimeByConnectionId;

  List<String> get liveLaneIds =>
      liveLanes.map((lane) => lane.laneId).toList(growable: false);

  ConnectionWorkspaceLiveLane? liveLaneForId(String laneId) {
    for (final lane in liveLanes) {
      if (lane.laneId == laneId) {
        return lane;
      }
    }
    return null;
  }

  ConnectionWorkspaceLiveLane? get selectedLiveLane {
    final laneId = selectedLaneId;
    if (laneId == null) {
      return null;
    }
    return liveLaneForId(laneId);
  }

  String? get selectedConnectionId => selectedLiveLane?.connectionId;

  List<String> get liveConnectionIds {
    final orderedConnectionIds = <String>[];
    final seenConnectionIds = <String>{};
    for (final lane in liveLanes) {
      if (seenConnectionIds.add(lane.connectionId)) {
        orderedConnectionIds.add(lane.connectionId);
      }
    }
    return orderedConnectionIds;
  }

  Set<String> get reconnectRequiredConnectionIds => <String>{
    ...savedSettingsReconnectRequiredConnectionIds,
    for (final lane in liveLanes)
      if (transportReconnectRequiredLaneIds.contains(lane.laneId))
        lane.connectionId,
  };

  List<String> get savedConnectionIds => catalog.orderedConnectionIds;

  List<String> get nonLiveSavedConnectionIds {
    return <String>[
      for (final connectionId in catalog.orderedConnectionIds)
        if (!liveConnectionIds.contains(connectionId)) connectionId,
    ];
  }

  List<ConnectionWorkspaceLiveLane> lanesForConnection(String connectionId) {
    return liveLanes
        .where((lane) => lane.connectionId == connectionId)
        .toList(growable: false);
  }

  int openLaneCountForConnection(String connectionId) {
    return lanesForConnection(connectionId).length;
  }

  ConnectionWorkspaceLiveLane? primaryLiveLaneForConnection(
    String connectionId,
  ) {
    final selectedLane = selectedLiveLane;
    if (selectedLane?.connectionId == connectionId) {
      return selectedLane;
    }
    for (final lane in liveLanes) {
      if (lane.connectionId == connectionId) {
        return lane;
      }
    }
    return null;
  }

  String? primaryLiveLaneIdForConnection(String connectionId) {
    return primaryLiveLaneForConnection(connectionId)?.laneId;
  }

  bool isConnectionLive(String connectionId) {
    return openLaneCountForConnection(connectionId) > 0;
  }

  bool isLaneLive(String laneId) {
    return liveLaneForId(laneId) != null;
  }

  bool requiresReconnect(String connectionId) {
    return requiresSavedSettingsReconnect(connectionId) ||
        requiresTransportReconnect(connectionId);
  }

  bool requiresSavedSettingsReconnect(String connectionId) {
    return savedSettingsReconnectRequiredConnectionIds.contains(connectionId);
  }

  bool requiresTransportReconnect(String connectionId) {
    return lanesForConnection(
      connectionId,
    ).any((lane) => requiresTransportReconnectForLane(lane.laneId));
  }

  bool requiresTransportReconnectForLane(String laneId) {
    return transportReconnectRequiredLaneIds.contains(laneId);
  }

  ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhaseFor(
    String connectionId,
  ) {
    final laneId = primaryLiveLaneIdForConnection(connectionId);
    if (laneId == null) {
      return null;
    }
    return transportRecoveryPhaseForLane(laneId);
  }

  ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhaseForLane(
    String laneId,
  ) {
    return transportRecoveryPhasesByLaneId[laneId];
  }

  ConnectionWorkspaceLiveReattachPhase? liveReattachPhaseFor(
    String connectionId,
  ) {
    final laneId = primaryLiveLaneIdForConnection(connectionId);
    if (laneId == null) {
      return null;
    }
    return liveReattachPhaseForLane(laneId);
  }

  ConnectionWorkspaceLiveReattachPhase? liveReattachPhaseForLane(
    String laneId,
  ) {
    return liveReattachPhasesByLaneId[laneId];
  }

  ConnectionWorkspaceRecoveryDiagnostics? recoveryDiagnosticsFor(
    String connectionId,
  ) {
    final laneId = primaryLiveLaneIdForConnection(connectionId);
    if (laneId == null) {
      return null;
    }
    return recoveryDiagnosticsForLane(laneId);
  }

  ConnectionWorkspaceRecoveryDiagnostics? recoveryDiagnosticsForLane(
    String laneId,
  ) {
    return recoveryDiagnosticsByLaneId[laneId];
  }

  ConnectionWorkspaceTurnLivenessAssessment? turnLivenessAssessmentFor(
    String connectionId,
  ) {
    return recoveryDiagnosticsFor(connectionId)?.lastTurnLivenessAssessment;
  }

  ConnectionWorkspaceTurnLivenessAssessment? turnLivenessAssessmentForLane(
    String laneId,
  ) {
    return recoveryDiagnosticsForLane(laneId)?.lastTurnLivenessAssessment;
  }

  ConnectionRemoteRuntimeState? remoteRuntimeFor(String connectionId) {
    return remoteRuntimeByConnectionId[connectionId];
  }

  ConnectionWorkspaceReconnectRequirement? reconnectRequirementFor(
    String connectionId,
  ) {
    final requiresSavedSettings = requiresSavedSettingsReconnect(connectionId);
    final requiresTransport = requiresTransportReconnect(connectionId);
    if (requiresTransport) {
      return requiresSavedSettings
          ? ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings
          : ConnectionWorkspaceReconnectRequirement.transport;
    }
    if (requiresSavedSettings) {
      return ConnectionWorkspaceReconnectRequirement.savedSettings;
    }
    return null;
  }

  bool get isEmptyWorkspace => catalog.isEmpty;

  bool get isShowingLiveLane =>
      viewport == ConnectionWorkspaceViewport.liveLane;

  bool get isShowingSavedConnections =>
      viewport == ConnectionWorkspaceViewport.savedConnections;

  bool get isShowingSavedSystems =>
      viewport == ConnectionWorkspaceViewport.savedSystems;

  ConnectionWorkspaceState copyWith({
    bool? isLoading,
    ConnectionCatalogState? catalog,
    SystemCatalogState? systemCatalog,
    List<ConnectionWorkspaceLiveLane>? liveLanes,
    String? selectedLaneId,
    ConnectionWorkspaceViewport? viewport,
    PocketUserFacingError? recoveryLoadWarning,
    ConnectionWorkspaceDeviceContinuityWarnings? deviceContinuityWarnings,
    Set<String>? savedSettingsReconnectRequiredConnectionIds,
    Set<String>? transportReconnectRequiredLaneIds,
    Map<String, ConnectionWorkspaceTransportRecoveryPhase>?
    transportRecoveryPhasesByLaneId,
    Map<String, ConnectionWorkspaceLiveReattachPhase>?
    liveReattachPhasesByLaneId,
    Map<String, ConnectionWorkspaceRecoveryDiagnostics>?
    recoveryDiagnosticsByLaneId,
    Map<String, ConnectionRemoteRuntimeState>? remoteRuntimeByConnectionId,
    bool clearSelectedLaneId = false,
    bool clearRecoveryLoadWarning = false,
  }) {
    return ConnectionWorkspaceState(
      isLoading: isLoading ?? this.isLoading,
      catalog: catalog ?? this.catalog,
      systemCatalog: systemCatalog ?? this.systemCatalog,
      liveLanes: liveLanes ?? this.liveLanes,
      selectedLaneId: clearSelectedLaneId
          ? null
          : (selectedLaneId ?? this.selectedLaneId),
      viewport: viewport ?? this.viewport,
      recoveryLoadWarning: clearRecoveryLoadWarning
          ? null
          : (recoveryLoadWarning ?? this.recoveryLoadWarning),
      deviceContinuityWarnings:
          deviceContinuityWarnings ?? this.deviceContinuityWarnings,
      savedSettingsReconnectRequiredConnectionIds:
          savedSettingsReconnectRequiredConnectionIds ??
          this.savedSettingsReconnectRequiredConnectionIds,
      transportReconnectRequiredLaneIds:
          transportReconnectRequiredLaneIds ??
          this.transportReconnectRequiredLaneIds,
      transportRecoveryPhasesByLaneId:
          transportRecoveryPhasesByLaneId ??
          this.transportRecoveryPhasesByLaneId,
      liveReattachPhasesByLaneId:
          liveReattachPhasesByLaneId ?? this.liveReattachPhasesByLaneId,
      recoveryDiagnosticsByLaneId:
          recoveryDiagnosticsByLaneId ?? this.recoveryDiagnosticsByLaneId,
      remoteRuntimeByConnectionId:
          remoteRuntimeByConnectionId ?? this.remoteRuntimeByConnectionId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceState &&
        other.isLoading == isLoading &&
        other.catalog == catalog &&
        other.systemCatalog == systemCatalog &&
        listEquals(other.liveLanes, liveLanes) &&
        other.selectedLaneId == selectedLaneId &&
        other.viewport == viewport &&
        other.recoveryLoadWarning == recoveryLoadWarning &&
        other.deviceContinuityWarnings == deviceContinuityWarnings &&
        setEquals(
          other.savedSettingsReconnectRequiredConnectionIds,
          savedSettingsReconnectRequiredConnectionIds,
        ) &&
        setEquals(
          other.transportReconnectRequiredLaneIds,
          transportReconnectRequiredLaneIds,
        ) &&
        mapEquals(
          other.transportRecoveryPhasesByLaneId,
          transportRecoveryPhasesByLaneId,
        ) &&
        mapEquals(
          other.liveReattachPhasesByLaneId,
          liveReattachPhasesByLaneId,
        ) &&
        mapEquals(
          other.recoveryDiagnosticsByLaneId,
          recoveryDiagnosticsByLaneId,
        ) &&
        mapEquals(
          other.remoteRuntimeByConnectionId,
          remoteRuntimeByConnectionId,
        );
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    catalog,
    systemCatalog,
    Object.hashAll(liveLanes),
    selectedLaneId,
    viewport,
    recoveryLoadWarning,
    deviceContinuityWarnings,
    Object.hashAllUnordered(savedSettingsReconnectRequiredConnectionIds),
    Object.hashAllUnordered(transportReconnectRequiredLaneIds),
    Object.hashAllUnordered(
      transportRecoveryPhasesByLaneId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      liveReattachPhasesByLaneId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      recoveryDiagnosticsByLaneId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      remoteRuntimeByConnectionId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}
