part of '../connection_workspace_controller.dart';

Future<ConnectionRemoteRuntimeState> _refreshWorkspaceRemoteRuntime(
  ConnectionWorkspaceController controller,
  String connectionId, {
  ConnectionProfile? profile,
  ConnectionSecrets? secrets,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  ConnectionProfile resolvedProfile;
  ConnectionSecrets resolvedSecrets;
  if (profile != null && secrets != null) {
    resolvedProfile = profile;
    resolvedSecrets = secrets;
  } else {
    final savedConnection = await controller._connectionRepository
        .loadConnection(normalizedConnectionId);
    resolvedProfile = profile ?? savedConnection.profile;
    resolvedSecrets = secrets ?? savedConnection.secrets;
  }

  final refreshGeneration =
      (controller
              ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] ??
          0) +
      1;
  controller
          ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] =
      refreshGeneration;

  if (resolvedProfile.isLocal) {
    final nextRemoteRuntimeByConnectionId =
        Map<String, ConnectionRemoteRuntimeState>.from(
          controller._state.remoteRuntimeByConnectionId,
        )..remove(normalizedConnectionId);
    if (_canApplyWorkspaceRemoteRuntime(
      controller,
      connectionId: normalizedConnectionId,
      refreshGeneration: refreshGeneration,
    )) {
      controller._applyState(
        controller._state.copyWith(
          remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
            catalog: controller._state.catalog,
            remoteRuntimeByConnectionId: nextRemoteRuntimeByConnectionId,
          ),
        ),
      );
    }
    return const ConnectionRemoteRuntimeState.unknown();
  }

  if (_canApplyWorkspaceRemoteRuntime(
    controller,
    connectionId: normalizedConnectionId,
    refreshGeneration: refreshGeneration,
  )) {
    controller._applyState(
      controller._state.copyWith(
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
          ...controller._state.remoteRuntimeByConnectionId,
          normalizedConnectionId: controller._remoteRuntimeCoordinator
              .buildProbeCheckingRuntime(),
        },
      ),
    );
  }

  final nextRuntime = await controller._remoteRuntimeCoordinator.probe(
    profile: resolvedProfile,
    secrets: resolvedSecrets,
    ownerId: normalizedConnectionId,
    probeFailure: ConnectionLifecycleErrors.remoteRuntimeProbeFailure,
  );
  if (_canApplyWorkspaceRemoteRuntime(
    controller,
    connectionId: normalizedConnectionId,
    refreshGeneration: refreshGeneration,
  )) {
    controller._applyState(
      controller._state.copyWith(
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
          ...controller._state.remoteRuntimeByConnectionId,
          normalizedConnectionId: nextRuntime,
        },
      ),
    );
  }
  return nextRuntime;
}

bool _canApplyWorkspaceRemoteRuntime(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required int refreshGeneration,
}) {
  return !controller._isDisposed &&
      controller._state.catalog.connectionForId(connectionId) != null &&
      controller._remoteRuntimeRefreshGenerationByConnectionId[connectionId] ==
          refreshGeneration;
}

void _applyWorkspaceRemoteAttachRuntime(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required CodexRemoteAppServerOwnerSnapshot snapshot,
}) {
  final currentRuntime = controller._state.remoteRuntimeFor(connectionId);
  final currentHostCapability = currentRuntime?.hostCapability;
  final nextHostCapability = switch (currentHostCapability?.status) {
    null || ConnectionRemoteHostCapabilityStatus.checking =>
      const ConnectionRemoteHostCapabilityState.unknown(),
    _ => currentHostCapability!,
  };

  controller._applyState(
    controller._state.copyWith(
      remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
        ...controller._state.remoteRuntimeByConnectionId,
        connectionId: ConnectionRemoteRuntimeState(
          hostCapability: nextHostCapability,
          server: snapshot.toConnectionState(),
        ),
      },
    ),
  );
}
