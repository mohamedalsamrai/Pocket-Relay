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
    controller._applyStateWithoutRecoveryPersistence(
      const ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState.empty(),
        systemCatalog: SystemCatalogState.empty(),
        liveLanes: <ConnectionWorkspaceLiveLane>[],
        selectedLaneId: null,
        viewport: ConnectionWorkspaceViewport.savedConnections,
        recoveryLoadWarning: null,
        deviceContinuityWarnings: ConnectionWorkspaceDeviceContinuityWarnings(),
        savedSettingsReconnectRequiredConnectionIds: <String>{},
        transportReconnectRequiredLaneIds: <String>{},
        transportRecoveryPhasesByLaneId:
            <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        liveReattachPhasesByLaneId:
            <String, ConnectionWorkspaceLiveReattachPhase>{},
        recoveryDiagnosticsByLaneId:
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
  final firstLaneId = _nextWorkspaceLiveLaneId(controller, firstConnectionId);
  final firstBinding = await _loadWorkspaceLaneBinding(
    controller,
    connectionId: firstConnectionId,
    laneId: firstLaneId,
    initialDraftText: recoveryState?.connectionId == firstConnectionId
        ? recoveryState?.draftText
        : null,
  );
  if (controller._isDisposed) {
    firstBinding.dispose();
    return;
  }

  controller._laneRoster.putBinding(firstLaneId, firstBinding);
  controller._registerLiveBinding(firstLaneId, firstBinding);
  controller._applyStateWithoutRecoveryPersistence(
    ConnectionWorkspaceState(
      isLoading: false,
      catalog: catalog,
      systemCatalog: systemCatalog,
      liveLanes: <ConnectionWorkspaceLiveLane>[
        ConnectionWorkspaceLiveLane(
          laneId: firstLaneId,
          connectionId: firstConnectionId,
        ),
      ],
      selectedLaneId: firstLaneId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      recoveryLoadWarning: recoveryLoadWarning,
      deviceContinuityWarnings:
          const ConnectionWorkspaceDeviceContinuityWarnings(),
      savedSettingsReconnectRequiredConnectionIds: const <String>{},
      transportReconnectRequiredLaneIds: const <String>{},
      transportRecoveryPhasesByLaneId:
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      liveReattachPhasesByLaneId:
          const <String, ConnectionWorkspaceLiveReattachPhase>{},
      recoveryDiagnosticsByLaneId: _initialWorkspaceRecoveryDiagnostics(
        laneId: firstLaneId,
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
    firstLaneId,
    startedAt: controller._now(),
    origin: ConnectionWorkspaceRecoveryOrigin.coldStart,
  );
  controller._applyState(
    _withWorkspaceTransportReconnectStaged(controller._state, firstLaneId),
  );
  await _attemptWorkspaceTransportReconnect(
    controller,
    firstLaneId,
    firstBinding,
    threadId: recoveryState!.selectedThreadId!,
    hadVisibleConversationState: false,
  );
}

Future<void> _instantiateWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  await _instantiateWorkspaceAdditionalLiveLane(controller, connectionId);
}

Future<String> _instantiateWorkspaceAdditionalLiveLane(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final laneId = _nextWorkspaceLiveLaneId(controller, connectionId);
  final binding = await _loadWorkspaceLaneBinding(
    controller,
    connectionId: connectionId,
    laneId: laneId,
  );
  if (controller._isDisposed) {
    binding.dispose();
    return laneId;
  }
  controller._laneRoster.putBinding(laneId, binding);
  controller._registerLiveBinding(laneId, binding);
  final nextLiveLanes = controller._laneRoster.orderedLiveLanes(
    controller._state.catalog,
    <ConnectionWorkspaceLiveLane>[
      ...controller._state.liveLanes,
      ConnectionWorkspaceLiveLane(laneId: laneId, connectionId: connectionId),
    ],
  );
  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      liveLanes: nextLiveLanes,
      selectedLaneId: laneId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveLanes
                .map((lane) => lane.connectionId)
                .toList(growable: false),
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredLaneIds:
          _sanitizeWorkspaceTransportReconnectRequiredLaneIds(
            liveLaneIds: nextLiveLanes
                .map((lane) => lane.laneId)
                .toList(growable: false),
            transportReconnectRequiredLaneIds:
                controller._state.transportReconnectRequiredLaneIds,
          ),
      transportRecoveryPhasesByLaneId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            liveLaneIds: nextLiveLanes
                .map((lane) => lane.laneId)
                .toList(growable: false),
            transportRecoveryPhasesByLaneId:
                controller._state.transportRecoveryPhasesByLaneId,
          ),
      liveReattachPhasesByLaneId: _sanitizeWorkspaceLiveReattachPhases(
        liveLaneIds: nextLiveLanes
            .map((lane) => lane.laneId)
            .toList(growable: false),
        liveReattachPhasesByLaneId:
            controller._state.liveReattachPhasesByLaneId,
      ),
      recoveryDiagnosticsByLaneId: _sanitizeWorkspaceRecoveryDiagnostics(
        liveLaneIds: nextLiveLanes
            .map((lane) => lane.laneId)
            .toList(growable: false),
        recoveryDiagnosticsByLaneId:
            controller._state.recoveryDiagnosticsByLaneId,
      ),
    ),
  );
  await binding.sessionController.initialize();
  if (controller._isDisposed) {
    return laneId;
  }
  return laneId;
}

Future<ConnectionLaneBinding> _loadWorkspaceLaneBinding(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required String laneId,
  String? initialDraftText,
}) async {
  final binding = controller._laneBindingFactory(
    laneId: laneId,
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
  required String laneId,
  required ConnectionWorkspaceRecoveryState? recoveryState,
}) {
  if (recoveryState == null) {
    return const <String, ConnectionWorkspaceRecoveryDiagnostics>{};
  }

  final diagnostics = ConnectionWorkspaceRecoveryDiagnostics(
    lastBackgroundedAt: recoveryState?.backgroundedAt,
    lastBackgroundedLifecycleState: recoveryState?.backgroundedLifecycleState,
  );
  if (diagnostics == const ConnectionWorkspaceRecoveryDiagnostics()) {
    return const <String, ConnectionWorkspaceRecoveryDiagnostics>{};
  }

  return <String, ConnectionWorkspaceRecoveryDiagnostics>{laneId: diagnostics};
}
