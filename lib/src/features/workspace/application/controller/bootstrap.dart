part of '../connection_workspace_controller.dart';

Future<void> _initializeWorkspaceController(
  ConnectionWorkspaceController controller,
) async {
  final (catalog, systemCatalog) = await _loadWorkspaceCatalogState(controller);
  ConnectionWorkspaceRecoveryState? recoveryState;
  PocketUserFacingError? recoveryLoadWarning;
  try {
    recoveryState = await controller._recoveryPersistenceController
        .loadPersistedSnapshot();
  } catch (error) {
    recoveryLoadWarning =
        ConnectionWorkspaceRecoveryErrors.recoveryStateLoadFailed(error: error);
  }
  controller._recoveryPersistenceController.seedPersistedSnapshot(
    recoveryState,
  );
  if (catalog.isEmpty) {
    controller._applyState(
      const ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState.empty(),
        systemCatalog: SystemCatalogState.empty(),
        liveConnectionIds: <String>[],
        selectedConnectionId: null,
        viewport: ConnectionWorkspaceViewport.savedConnections,
        recoveryLoadWarning: null,
        deviceContinuityWarnings: ConnectionWorkspaceDeviceContinuityWarnings(),
        savedSettingsReconnectRequiredConnectionIds: <String>{},
        transportReconnectRequiredConnectionIds: <String>{},
        transportRecoveryPhasesByConnectionId:
            <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        liveReattachPhasesByConnectionId:
            <String, ConnectionWorkspaceLiveReattachPhase>{},
        recoveryDiagnosticsByConnectionId:
            <String, ConnectionWorkspaceRecoveryDiagnostics>{},
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{},
      ).copyWith(recoveryLoadWarning: recoveryLoadWarning),
    );
    return;
  }

  final restoredConnectionId = recoveryState?.connectionId;
  final firstConnectionId =
      restoredConnectionId != null &&
          catalog.connectionForId(restoredConnectionId) != null
      ? restoredConnectionId
      : catalog.orderedConnectionIds.first;
  final firstBinding = await _loadWorkspaceLaneBinding(
    controller,
    firstConnectionId,
    initialDraftText: recoveryState?.connectionId == firstConnectionId
        ? recoveryState?.draftText
        : null,
  );
  if (controller._isDisposed) {
    firstBinding.dispose();
    return;
  }

  controller._liveBindingRegistry.putBinding(firstConnectionId, firstBinding);
  controller._registerLiveBinding(firstConnectionId, firstBinding);
  controller._applyState(
    ConnectionWorkspaceState(
      isLoading: false,
      catalog: catalog,
      systemCatalog: systemCatalog,
      liveConnectionIds: <String>[firstConnectionId],
      selectedConnectionId: firstConnectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      recoveryLoadWarning: recoveryLoadWarning,
      deviceContinuityWarnings:
          const ConnectionWorkspaceDeviceContinuityWarnings(),
      savedSettingsReconnectRequiredConnectionIds: const <String>{},
      transportReconnectRequiredConnectionIds: const <String>{},
      transportRecoveryPhasesByConnectionId:
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      liveReattachPhasesByConnectionId:
          const <String, ConnectionWorkspaceLiveReattachPhase>{},
      recoveryDiagnosticsByConnectionId: _initialWorkspaceRecoveryDiagnostics(
        connectionId: firstConnectionId,
        recoveryState: recoveryState,
      ),
      remoteRuntimeByConnectionId:
          const <String, ConnectionRemoteRuntimeState>{},
    ),
  );
  await firstBinding.sessionController.initialize();
  if (controller._isDisposed ||
      recoveryState?.connectionId != firstConnectionId ||
      recoveryState?.selectedThreadId == null) {
    return;
  }

  controller._beginRecoveryAttempt(
    firstConnectionId,
    startedAt: controller._now(),
    origin: ConnectionWorkspaceRecoveryOrigin.coldStart,
  );
  controller._applyState(
    _withWorkspaceTransportReconnectStaged(
      controller._state,
      firstConnectionId,
    ),
  );
  await _attemptWorkspaceTransportReconnect(
    controller,
    firstConnectionId,
    firstBinding,
    threadId: recoveryState!.selectedThreadId!,
    hadVisibleConversationState: false,
  );
}

Future<void> _instantiateWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final binding = await _loadWorkspaceLaneBinding(controller, connectionId);
  if (controller._isDisposed) {
    binding.dispose();
    return;
  }
  controller._liveBindingRegistry.putBinding(connectionId, binding);
  controller._registerLiveBinding(connectionId, binding);
  final nextLiveConnectionIds = _orderWorkspaceLiveConnectionIds(
    controller,
    controller._liveBindingRegistry.connectionIds,
  );
  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      liveConnectionIds: nextLiveConnectionIds,
      selectedConnectionId: connectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.transportReconnectRequiredConnectionIds,
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                controller._state.transportRecoveryPhasesByConnectionId,
          ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: controller._state.catalog,
        liveConnectionIds: nextLiveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
    ),
  );
  await binding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
}

Future<ConnectionLaneBinding> _loadWorkspaceLaneBinding(
  ConnectionWorkspaceController controller,
  String connectionId, {
  String? initialDraftText,
}) async {
  final binding = controller._laneBindingFactory(
    connectionId: connectionId,
    connection: await controller._connectionRepository.loadConnection(
      connectionId,
    ),
  );
  if (initialDraftText != null && initialDraftText.isNotEmpty) {
    binding.restoreComposerDraft(initialDraftText);
  }
  return binding;
}

Map<String, ConnectionWorkspaceRecoveryDiagnostics>
_initialWorkspaceRecoveryDiagnostics({
  required String connectionId,
  required ConnectionWorkspaceRecoveryState? recoveryState,
}) {
  if (recoveryState?.connectionId != connectionId) {
    return const <String, ConnectionWorkspaceRecoveryDiagnostics>{};
  }

  final diagnostics = ConnectionWorkspaceRecoveryDiagnostics(
    lastBackgroundedAt: recoveryState?.backgroundedAt,
    lastBackgroundedLifecycleState: recoveryState?.backgroundedLifecycleState,
  );
  if (diagnostics == const ConnectionWorkspaceRecoveryDiagnostics()) {
    return const <String, ConnectionWorkspaceRecoveryDiagnostics>{};
  }

  return <String, ConnectionWorkspaceRecoveryDiagnostics>{
    connectionId: diagnostics,
  };
}
