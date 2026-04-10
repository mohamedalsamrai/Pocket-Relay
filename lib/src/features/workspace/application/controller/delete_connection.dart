part of '../connection_workspace_controller.dart';

Future<void> _deleteWorkspaceSavedConnectionImpl(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  await controller._connectionRepository.deleteConnection(connectionId);
  await controller._connectionCapabilityAssets.deleteConnectionModelCatalog(
    connectionId,
  );
  controller._remoteRuntimeController.forgetConnection(connectionId);
  final (nextCatalog, nextSystemCatalog) = await _loadWorkspaceCatalogState(
    controller,
  );
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      systemCatalog: nextSystemCatalog,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredLaneIds:
          _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
            liveLaneIds: controller._state.liveLaneIds,
            transportReconnectRequiredLaneIds:
                controller._state.transportReconnectRequiredLaneIds,
          ),
      transportRecoveryPhasesByLaneId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            liveLaneIds: controller._state.liveLaneIds,
            transportRecoveryPhasesByLaneId:
                controller._state.transportRecoveryPhasesByLaneId,
          ),
      liveReattachPhasesByLaneId: _sanitizeWorkspaceLiveReattachPhases(
        liveLaneIds: controller._state.liveLaneIds,
        liveReattachPhasesByLaneId:
            controller._state.liveReattachPhasesByLaneId,
      ),
      recoveryDiagnosticsByLaneId: _sanitizeWorkspaceRecoveryDiagnostics(
        liveLaneIds: controller._state.liveLaneIds,
        recoveryDiagnosticsByLaneId:
            controller._state.recoveryDiagnosticsByLaneId,
      ),
      remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
        catalog: nextCatalog,
        remoteRuntimeByConnectionId:
            controller._state.remoteRuntimeByConnectionId,
      ),
    ),
  );
}
