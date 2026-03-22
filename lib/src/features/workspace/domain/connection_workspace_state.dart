import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

enum ConnectionWorkspaceViewport { liveLane, dormantRoster }

enum ConnectionWorkspaceReconnectRequirement {
  savedSettings,
  transport,
  transportWithSavedSettings,
}

enum ConnectionWorkspaceTransportRecoveryPhase {
  lost,
  reconnecting,
  unavailable,
}

class ConnectionWorkspaceState {
  const ConnectionWorkspaceState({
    required this.isLoading,
    required this.catalog,
    required this.liveConnectionIds,
    required this.selectedConnectionId,
    required this.viewport,
    required this.savedSettingsReconnectRequiredConnectionIds,
    required this.transportReconnectRequiredConnectionIds,
    required this.transportRecoveryPhasesByConnectionId,
  });

  const ConnectionWorkspaceState.initial()
    : isLoading = true,
      catalog = const ConnectionCatalogState.empty(),
      liveConnectionIds = const <String>[],
      selectedConnectionId = null,
      viewport = ConnectionWorkspaceViewport.liveLane,
      savedSettingsReconnectRequiredConnectionIds = const <String>{},
      transportReconnectRequiredConnectionIds = const <String>{},
      transportRecoveryPhasesByConnectionId =
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{};

  final bool isLoading;
  final ConnectionCatalogState catalog;
  final List<String> liveConnectionIds;
  final String? selectedConnectionId;
  final ConnectionWorkspaceViewport viewport;
  final Set<String> savedSettingsReconnectRequiredConnectionIds;
  final Set<String> transportReconnectRequiredConnectionIds;
  final Map<String, ConnectionWorkspaceTransportRecoveryPhase>
  transportRecoveryPhasesByConnectionId;

  Set<String> get reconnectRequiredConnectionIds => <String>{
    ...savedSettingsReconnectRequiredConnectionIds,
    ...transportReconnectRequiredConnectionIds,
  };

  List<String> get dormantConnectionIds {
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

  bool get isShowingDormantRoster =>
      viewport == ConnectionWorkspaceViewport.dormantRoster;

  ConnectionWorkspaceState copyWith({
    bool? isLoading,
    ConnectionCatalogState? catalog,
    List<String>? liveConnectionIds,
    String? selectedConnectionId,
    ConnectionWorkspaceViewport? viewport,
    Set<String>? savedSettingsReconnectRequiredConnectionIds,
    Set<String>? transportReconnectRequiredConnectionIds,
    Map<String, ConnectionWorkspaceTransportRecoveryPhase>?
    transportRecoveryPhasesByConnectionId,
    bool clearSelectedConnectionId = false,
  }) {
    return ConnectionWorkspaceState(
      isLoading: isLoading ?? this.isLoading,
      catalog: catalog ?? this.catalog,
      liveConnectionIds: liveConnectionIds ?? this.liveConnectionIds,
      selectedConnectionId: clearSelectedConnectionId
          ? null
          : (selectedConnectionId ?? this.selectedConnectionId),
      viewport: viewport ?? this.viewport,
      savedSettingsReconnectRequiredConnectionIds:
          savedSettingsReconnectRequiredConnectionIds ??
          this.savedSettingsReconnectRequiredConnectionIds,
      transportReconnectRequiredConnectionIds:
          transportReconnectRequiredConnectionIds ??
          this.transportReconnectRequiredConnectionIds,
      transportRecoveryPhasesByConnectionId:
          transportRecoveryPhasesByConnectionId ??
          this.transportRecoveryPhasesByConnectionId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceState &&
        other.isLoading == isLoading &&
        other.catalog == catalog &&
        listEquals(other.liveConnectionIds, liveConnectionIds) &&
        other.selectedConnectionId == selectedConnectionId &&
        other.viewport == viewport &&
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
        );
  }

  @override
  int get hashCode => Object.hash(
    isLoading,
    catalog,
    Object.hashAll(liveConnectionIds),
    selectedConnectionId,
    viewport,
    Object.hashAllUnordered(savedSettingsReconnectRequiredConnectionIds),
    Object.hashAllUnordered(transportReconnectRequiredConnectionIds),
    Object.hashAllUnordered(
      transportRecoveryPhasesByConnectionId.entries.map(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}
