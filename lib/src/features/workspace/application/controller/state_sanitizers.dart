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

Set<String> _sanitizeWorkspaceTransportReconnectRequiredLaneIds({
  required List<String> liveLaneIds,
  required Set<String> transportReconnectRequiredLaneIds,
}) {
  final liveLaneIdSet = liveLaneIds.toSet();
  return <String>{
    for (final laneId in transportReconnectRequiredLaneIds)
      if (liveLaneIdSet.contains(laneId)) laneId,
  };
}

Map<String, ConnectionWorkspaceTransportRecoveryPhase>
_sanitizeWorkspaceTransportRecoveryPhases({
  required List<String> liveLaneIds,
  required Map<String, ConnectionWorkspaceTransportRecoveryPhase>
  transportRecoveryPhasesByLaneId,
}) {
  final liveLaneIdSet = liveLaneIds.toSet();
  return <String, ConnectionWorkspaceTransportRecoveryPhase>{
    for (final entry in transportRecoveryPhasesByLaneId.entries)
      if (liveLaneIdSet.contains(entry.key)) entry.key: entry.value,
  };
}

Map<String, ConnectionWorkspaceLiveReattachPhase>
_sanitizeWorkspaceLiveReattachPhases({
  required List<String> liveLaneIds,
  required Map<String, ConnectionWorkspaceLiveReattachPhase>
  liveReattachPhasesByLaneId,
}) {
  final liveLaneIdSet = liveLaneIds.toSet();
  return <String, ConnectionWorkspaceLiveReattachPhase>{
    for (final entry in liveReattachPhasesByLaneId.entries)
      if (liveLaneIdSet.contains(entry.key)) entry.key: entry.value,
  };
}

Map<String, ConnectionWorkspaceRecoveryDiagnostics>
_sanitizeWorkspaceRecoveryDiagnostics({
  required List<String> liveLaneIds,
  required Map<String, ConnectionWorkspaceRecoveryDiagnostics>
  recoveryDiagnosticsByLaneId,
}) {
  final liveLaneIdSet = liveLaneIds.toSet();
  return <String, ConnectionWorkspaceRecoveryDiagnostics>{
    for (final entry in recoveryDiagnosticsByLaneId.entries)
      if (liveLaneIdSet.contains(entry.key)) entry.key: entry.value,
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
