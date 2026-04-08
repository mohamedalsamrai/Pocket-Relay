import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

part 'connection_workspace_recovery_models.dart';

class ConnectionWorkspaceState {
  const ConnectionWorkspaceState({
    required this.isLoading,
    required this.catalog,
    this.systemCatalog = const SystemCatalogState.empty(),
    required this.liveConnectionIds,
    required this.selectedConnectionId,
    required this.viewport,
    this.recoveryLoadWarning,
    this.deviceContinuityWarnings =
        const ConnectionWorkspaceDeviceContinuityWarnings(),
    required this.savedSettingsReconnectRequiredConnectionIds,
    required this.transportReconnectRequiredConnectionIds,
    required this.transportRecoveryPhasesByConnectionId,
    required this.liveReattachPhasesByConnectionId,
    required this.recoveryDiagnosticsByConnectionId,
    required this.remoteRuntimeByConnectionId,
  });

  const ConnectionWorkspaceState.initial()
    : isLoading = true,
      catalog = const ConnectionCatalogState.empty(),
      systemCatalog = const SystemCatalogState.empty(),
      liveConnectionIds = const <String>[],
      selectedConnectionId = null,
      viewport = ConnectionWorkspaceViewport.liveLane,
      recoveryLoadWarning = null,
      deviceContinuityWarnings =
          const ConnectionWorkspaceDeviceContinuityWarnings(),
      savedSettingsReconnectRequiredConnectionIds = const <String>{},
      transportReconnectRequiredConnectionIds = const <String>{},
      transportRecoveryPhasesByConnectionId =
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      liveReattachPhasesByConnectionId =
          const <String, ConnectionWorkspaceLiveReattachPhase>{},
      recoveryDiagnosticsByConnectionId =
          const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
      remoteRuntimeByConnectionId =
          const <String, ConnectionRemoteRuntimeState>{};

  final bool isLoading;
  final ConnectionCatalogState catalog;
  final SystemCatalogState systemCatalog;
  final List<String> liveConnectionIds;
  final String? selectedConnectionId;
  final ConnectionWorkspaceViewport viewport;
  final PocketUserFacingError? recoveryLoadWarning;
  final ConnectionWorkspaceDeviceContinuityWarnings deviceContinuityWarnings;
  final Set<String> savedSettingsReconnectRequiredConnectionIds;
  final Set<String> transportReconnectRequiredConnectionIds;
  final Map<String, ConnectionWorkspaceTransportRecoveryPhase>
  transportRecoveryPhasesByConnectionId;
  final Map<String, ConnectionWorkspaceLiveReattachPhase>
  liveReattachPhasesByConnectionId;
  final Map<String, ConnectionWorkspaceRecoveryDiagnostics>
  recoveryDiagnosticsByConnectionId;
  final Map<String, ConnectionRemoteRuntimeState> remoteRuntimeByConnectionId;

  Set<String> get reconnectRequiredConnectionIds => <String>{
    ...savedSettingsReconnectRequiredConnectionIds,
    ...transportReconnectRequiredConnectionIds,
  };

  List<String> get savedConnectionIds => catalog.orderedConnectionIds;

  List<String> get nonLiveSavedConnectionIds {
    return <String>[
      for (final connectionId in catalog.orderedConnectionIds)
        if (!liveConnectionIds.contains(connectionId)) connectionId,
    ];
  }

  bool isConnectionLive(String connectionId) {
    return liveConnectionIds.contains(connectionId);
  }

  bool requiresReconnect(String connectionId) {
    return requiresSavedSettingsReconnect(connectionId) ||
        requiresTransportReconnect(connectionId);
  }

  bool requiresSavedSettingsReconnect(String connectionId) {
    return savedSettingsReconnectRequiredConnectionIds.contains(connectionId);
  }

  bool requiresTransportReconnect(String connectionId) {
    return transportReconnectRequiredConnectionIds.contains(connectionId);
  }

  ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhaseFor(
    String connectionId,
  ) {
    return transportRecoveryPhasesByConnectionId[connectionId];
  }

  ConnectionWorkspaceLiveReattachPhase? liveReattachPhaseFor(
    String connectionId,
  ) {
    return liveReattachPhasesByConnectionId[connectionId];
  }

  ConnectionWorkspaceRecoveryDiagnostics? recoveryDiagnosticsFor(
    String connectionId,
  ) {
    return recoveryDiagnosticsByConnectionId[connectionId];
  }

  ConnectionWorkspaceTurnLivenessAssessment? turnLivenessAssessmentFor(
    String connectionId,
  ) {
    return recoveryDiagnosticsFor(connectionId)?.lastTurnLivenessAssessment;
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
    List<String>? liveConnectionIds,
    String? selectedConnectionId,
    ConnectionWorkspaceViewport? viewport,
    PocketUserFacingError? recoveryLoadWarning,
    ConnectionWorkspaceDeviceContinuityWarnings? deviceContinuityWarnings,
    Set<String>? savedSettingsReconnectRequiredConnectionIds,
    Set<String>? transportReconnectRequiredConnectionIds,
    Map<String, ConnectionWorkspaceTransportRecoveryPhase>?
    transportRecoveryPhasesByConnectionId,
    Map<String, ConnectionWorkspaceLiveReattachPhase>?
    liveReattachPhasesByConnectionId,
    Map<String, ConnectionWorkspaceRecoveryDiagnostics>?
    recoveryDiagnosticsByConnectionId,
    Map<String, ConnectionRemoteRuntimeState>? remoteRuntimeByConnectionId,
    bool clearSelectedConnectionId = false,
    bool clearRecoveryLoadWarning = false,
  }) {
    return ConnectionWorkspaceState(
      isLoading: isLoading ?? this.isLoading,
      catalog: catalog ?? this.catalog,
      systemCatalog: systemCatalog ?? this.systemCatalog,
      liveConnectionIds: liveConnectionIds ?? this.liveConnectionIds,
      selectedConnectionId: clearSelectedConnectionId
          ? null
          : (selectedConnectionId ?? this.selectedConnectionId),
      viewport: viewport ?? this.viewport,
      recoveryLoadWarning: clearRecoveryLoadWarning
          ? null
          : (recoveryLoadWarning ?? this.recoveryLoadWarning),
      deviceContinuityWarnings:
          deviceContinuityWarnings ?? this.deviceContinuityWarnings,
      savedSettingsReconnectRequiredConnectionIds:
          savedSettingsReconnectRequiredConnectionIds ??
          this.savedSettingsReconnectRequiredConnectionIds,
      transportReconnectRequiredConnectionIds:
          transportReconnectRequiredConnectionIds ??
          this.transportReconnectRequiredConnectionIds,
      transportRecoveryPhasesByConnectionId:
          transportRecoveryPhasesByConnectionId ??
          this.transportRecoveryPhasesByConnectionId,
      liveReattachPhasesByConnectionId:
          liveReattachPhasesByConnectionId ??
          this.liveReattachPhasesByConnectionId,
      recoveryDiagnosticsByConnectionId:
          recoveryDiagnosticsByConnectionId ??
          this.recoveryDiagnosticsByConnectionId,
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
        listEquals(other.liveConnectionIds, liveConnectionIds) &&
        other.selectedConnectionId == selectedConnectionId &&
        other.viewport == viewport &&
        other.recoveryLoadWarning == recoveryLoadWarning &&
        other.deviceContinuityWarnings == deviceContinuityWarnings &&
        setEquals(
          other.savedSettingsReconnectRequiredConnectionIds,
          savedSettingsReconnectRequiredConnectionIds,
        ) &&
        setEquals(
          other.transportReconnectRequiredConnectionIds,
          transportReconnectRequiredConnectionIds,
        ) &&
        mapEquals(
          other.transportRecoveryPhasesByConnectionId,
          transportRecoveryPhasesByConnectionId,
        ) &&
        mapEquals(
          other.liveReattachPhasesByConnectionId,
          liveReattachPhasesByConnectionId,
        ) &&
        mapEquals(
          other.recoveryDiagnosticsByConnectionId,
          recoveryDiagnosticsByConnectionId,
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
    Object.hashAll(liveConnectionIds),
    selectedConnectionId,
    viewport,
    recoveryLoadWarning,
    deviceContinuityWarnings,
    Object.hashAllUnordered(savedSettingsReconnectRequiredConnectionIds),
    Object.hashAllUnordered(transportReconnectRequiredConnectionIds),
    Object.hashAllUnordered(
      transportRecoveryPhasesByConnectionId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      liveReattachPhasesByConnectionId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
    Object.hashAllUnordered(
      recoveryDiagnosticsByConnectionId.entries.map(
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
