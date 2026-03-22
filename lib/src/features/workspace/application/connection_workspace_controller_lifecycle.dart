part of 'connection_workspace_controller.dart';

Future<void> _initializeWorkspaceController(
  ConnectionWorkspaceController controller,
) async {
  final catalog = await controller._connectionRepository.loadCatalog();
  final recoveryState = await controller._recoveryStore.load();
  controller._lastPersistedRecoveryState = recoveryState;
  if (catalog.isEmpty) {
    controller._applyState(
      const ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState.empty(),
        liveConnectionIds: <String>[],
        selectedConnectionId: null,
        viewport: ConnectionWorkspaceViewport.dormantRoster,
        savedSettingsReconnectRequiredConnectionIds: <String>{},
        transportReconnectRequiredConnectionIds: <String>{},
        transportRecoveryPhasesByConnectionId:
            <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      ),
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

  controller._liveBindingsByConnectionId[firstConnectionId] = firstBinding;
  controller._registerLiveBinding(firstConnectionId, firstBinding);
  controller._applyState(
    ConnectionWorkspaceState(
      isLoading: false,
      catalog: catalog,
      liveConnectionIds: <String>[firstConnectionId],
      selectedConnectionId: firstConnectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      savedSettingsReconnectRequiredConnectionIds: const <String>{},
      transportReconnectRequiredConnectionIds: const <String>{},
      transportRecoveryPhasesByConnectionId:
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
    ),
  );
  await firstBinding.sessionController.initialize();
  if (controller._isDisposed ||
      recoveryState?.connectionId != firstConnectionId ||
      recoveryState?.selectedThreadId == null) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              ...controller._state.transportReconnectRequiredConnectionIds,
              firstConnectionId,
            },
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  ...controller._state.transportRecoveryPhasesByConnectionId,
                  firstConnectionId:
                      ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
                },
          ),
    ),
  );
  try {
    await _connectWorkspaceBindingTransport(firstBinding);
  } catch (_) {
    if (!controller._isDisposed) {
      controller._setTransportRecoveryPhase(
        firstConnectionId,
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
    }
    return;
  }

  await firstBinding.sessionController.selectConversationForResume(
    recoveryState!.selectedThreadId!,
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
  controller._liveBindingsByConnectionId[connectionId] = binding;
  controller._registerLiveBinding(connectionId, binding);
  final nextLiveConnectionIds = _orderWorkspaceLiveConnectionIds(
    controller,
    controller._liveBindingsByConnectionId.keys,
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
    ),
  );
  await binding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
}

Future<void> _reconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final previousBinding = controller._liveBindingsByConnectionId[connectionId];
  if (previousBinding == null) {
    return;
  }
  if (previousBinding.sessionController.sessionState.isBusy) {
    return;
  }

  final shouldReconnectTransport = controller._state.requiresTransportReconnect(
    connectionId,
  );
  final preservedLaneState = _preservedWorkspaceLaneState(previousBinding);
  final nextBinding = await _loadWorkspaceLaneBinding(
    controller,
    connectionId,
    initialDraftText: preservedLaneState.draftText,
  );
  if (controller._isDisposed) {
    nextBinding.dispose();
    return;
  }

  controller._liveBindingsByConnectionId[connectionId] = nextBinding;
  controller._unregisterLiveBinding(connectionId);
  controller._registerLiveBinding(connectionId, nextBinding);
  previousBinding.dispose();
  controller._applyState(
    controller._state.copyWith(
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              for (final reconnectConnectionId
                  in controller
                      ._state
                      .savedSettingsReconnectRequiredConnectionIds)
                if (reconnectConnectionId != connectionId)
                  reconnectConnectionId,
            },
          ),
      transportReconnectRequiredConnectionIds: shouldReconnectTransport
          ? controller._state.transportReconnectRequiredConnectionIds
          : _sanitizeWorkspaceReconnectRequiredIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                for (final reconnectConnectionId
                    in controller
                        ._state
                        .transportReconnectRequiredConnectionIds)
                  if (reconnectConnectionId != connectionId)
                    reconnectConnectionId,
              },
            ),
      transportRecoveryPhasesByConnectionId: shouldReconnectTransport
          ? _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    ...controller._state.transportRecoveryPhasesByConnectionId,
                    connectionId:
                        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
                  },
            )
          : _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    for (final entry
                        in controller
                            ._state
                            .transportRecoveryPhasesByConnectionId
                            .entries)
                      if (entry.key != connectionId) entry.key: entry.value,
                  },
            ),
    ),
  );
  await nextBinding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
  if (shouldReconnectTransport) {
    try {
      await _connectWorkspaceBindingTransport(nextBinding);
    } catch (_) {
      if (!controller._isDisposed) {
        controller._setTransportRecoveryPhase(
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
      }
      return;
    }
  }
  if (preservedLaneState.threadId != null) {
    await nextBinding.sessionController.selectConversationForResume(
      preservedLaneState.threadId!,
    );
    return;
  }
}

Future<void> _resumeWorkspaceConversation(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required String threadId,
}) async {
  if (controller._state.isConnectionLive(connectionId)) {
    final previousBinding =
        controller._liveBindingsByConnectionId[connectionId];
    if (previousBinding == null) {
      return;
    }
    if (previousBinding.sessionController.sessionState.isBusy) {
      return;
    }

    final nextBinding = await _loadWorkspaceLaneBinding(
      controller,
      connectionId,
    );
    if (controller._isDisposed) {
      nextBinding.dispose();
      return;
    }
    controller._liveBindingsByConnectionId[connectionId] = nextBinding;
    controller._unregisterLiveBinding(connectionId);
    controller._registerLiveBinding(connectionId, nextBinding);
    final didNotifyStateChange = controller._applyState(
      controller._state.copyWith(
        selectedConnectionId: connectionId,
        viewport: ConnectionWorkspaceViewport.liveLane,
        savedSettingsReconnectRequiredConnectionIds:
            _sanitizeWorkspaceReconnectRequiredIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                for (final reconnectConnectionId
                    in controller
                        ._state
                        .savedSettingsReconnectRequiredConnectionIds)
                  if (reconnectConnectionId != connectionId)
                    reconnectConnectionId,
              },
            ),
        transportReconnectRequiredConnectionIds:
            _sanitizeWorkspaceReconnectRequiredIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                for (final reconnectConnectionId
                    in controller
                        ._state
                        .transportReconnectRequiredConnectionIds)
                  if (reconnectConnectionId != connectionId)
                    reconnectConnectionId,
              },
            ),
        transportRecoveryPhasesByConnectionId:
            _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    for (final entry
                        in controller
                            ._state
                            .transportRecoveryPhasesByConnectionId
                            .entries)
                      if (entry.key != connectionId) entry.key: entry.value,
                  },
            ),
      ),
    );
    previousBinding.dispose();
    if (!didNotifyStateChange) {
      controller._notifyBindingChange();
    }
    await nextBinding.sessionController.initialize();
    if (controller._isDisposed) {
      return;
    }
    await nextBinding.sessionController.selectConversationForResume(threadId);
    return;
  }

  await _instantiateWorkspaceConnection(controller, connectionId);
  if (controller._isDisposed) {
    return;
  }

  final binding = controller._liveBindingsByConnectionId[connectionId];
  if (binding == null) {
    return;
  }

  await binding.sessionController.selectConversationForResume(threadId);
}

Future<void> _deleteDormantWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  await controller._connectionRepository.deleteConnection(connectionId);
  await controller._modelCatalogStore.delete(connectionId);
  final nextCatalog = await controller._connectionRepository.loadCatalog();
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.transportReconnectRequiredConnectionIds,
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                controller._state.transportRecoveryPhasesByConnectionId,
          ),
    ),
  );
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

Future<void> _handleWorkspaceAppLifecycleState(
  ConnectionWorkspaceController controller,
  AppLifecycleState state,
) async {
  switch (state) {
    case AppLifecycleState.inactive:
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: controller._now(),
      );
      return;
    case AppLifecycleState.hidden:
    case AppLifecycleState.paused:
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: controller._now(),
      );
      return;
    case AppLifecycleState.resumed:
      final selectedConnectionId = controller._state.selectedConnectionId;
      if (selectedConnectionId == null ||
          !controller._state.isConnectionLive(selectedConnectionId) ||
          !controller._state.requiresTransportReconnect(selectedConnectionId) ||
          controller._state.requiresSavedSettingsReconnect(
            selectedConnectionId,
          )) {
        return;
      }

      final binding =
          controller._liveBindingsByConnectionId[selectedConnectionId];
      if (binding == null || binding.sessionController.sessionState.isBusy) {
        return;
      }

      await _reconnectWorkspaceConnection(controller, selectedConnectionId);
      return;
    case AppLifecycleState.detached:
      return;
  }
}

({String? threadId, String draftText}) _preservedWorkspaceLaneState(
  ConnectionLaneBinding binding,
) {
  return (
    threadId: _normalizedWorkspaceThreadId(
      binding.sessionController.sessionState.currentThreadId ??
          binding.sessionController.sessionState.rootThreadId ??
          binding
              .sessionController
              .historicalConversationRestoreState
              ?.threadId,
    ),
    draftText: binding.composerDraftHost.draft.text,
  );
}

String? _normalizedWorkspaceThreadId(String? value) {
  final normalizedValue = value?.trim();
  if (normalizedValue == null || normalizedValue.isEmpty) {
    return null;
  }
  return normalizedValue;
}

Future<void> _connectWorkspaceBindingTransport(ConnectionLaneBinding binding) {
  if (binding.appServerClient.isConnected) {
    return Future<void>.value();
  }

  return binding.appServerClient.connect(
    profile: binding.sessionController.profile,
    secrets: binding.sessionController.secrets,
  );
}
