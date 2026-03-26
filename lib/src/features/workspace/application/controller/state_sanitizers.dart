part of '../connection_workspace_controller.dart';

Set<String> _sanitizeWorkspaceReconnectRequiredIds({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Set<String> reconnectRequiredConnectionIds,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String>{
    for (final connectionId in reconnectRequiredConnectionIds)
      if (catalog.connectionForId(connectionId) != null &&
          liveConnectionIdSet.contains(connectionId))
        connectionId,
  };
}

Map<String, ConnectionWorkspaceTransportRecoveryPhase>
_sanitizeWorkspaceTransportRecoveryPhases({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Map<String, ConnectionWorkspaceTransportRecoveryPhase>
  transportRecoveryPhasesByConnectionId,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String, ConnectionWorkspaceTransportRecoveryPhase>{
    for (final entry in transportRecoveryPhasesByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null &&
          liveConnectionIdSet.contains(entry.key))
        entry.key: entry.value,
  };
}

Map<String, ConnectionWorkspaceLiveReattachPhase>
_sanitizeWorkspaceLiveReattachPhases({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Map<String, ConnectionWorkspaceLiveReattachPhase>
  liveReattachPhasesByConnectionId,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String, ConnectionWorkspaceLiveReattachPhase>{
    for (final entry in liveReattachPhasesByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null &&
          liveConnectionIdSet.contains(entry.key))
        entry.key: entry.value,
  };
}

Map<String, ConnectionWorkspaceRecoveryDiagnostics>
_sanitizeWorkspaceRecoveryDiagnostics({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Map<String, ConnectionWorkspaceRecoveryDiagnostics>
  recoveryDiagnosticsByConnectionId,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String, ConnectionWorkspaceRecoveryDiagnostics>{
    for (final entry in recoveryDiagnosticsByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null &&
          liveConnectionIdSet.contains(entry.key))
        entry.key: entry.value,
  };
}

Map<String, ConnectionRemoteRuntimeState> _sanitizeWorkspaceRemoteRuntimes({
  required ConnectionCatalogState catalog,
  required Map<String, ConnectionRemoteRuntimeState>
  remoteRuntimeByConnectionId,
}) {
  return <String, ConnectionRemoteRuntimeState>{
    for (final entry in remoteRuntimeByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null) entry.key: entry.value,
  };
}
