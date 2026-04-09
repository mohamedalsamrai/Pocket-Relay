part of 'connection_workspace_controller.dart';

Future<ConnectionRemoteRuntimeState> _startWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    connectionId: connectionId,
  ).start();
}

Future<ConnectionRemoteRuntimeState> _stopWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    connectionId: connectionId,
  ).stop();
}

Future<ConnectionRemoteRuntimeState> _restartWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    connectionId: connectionId,
  ).restart();
}

extension on Future<_WorkspaceRemoteServerActionContext> {
  Future<ConnectionRemoteRuntimeState> start() async {
    final context = await this;
    final nextRuntime = await context.controller._remoteRuntimeCoordinator
        .startRemoteServer(
          profile: context.savedConnection.profile,
          secrets: context.savedConnection.secrets,
          ownerId: context.connectionId,
          currentRuntime: context.controller.state.remoteRuntimeFor(
            context.connectionId,
          ),
          probeFailure: ConnectionLifecycleErrors.remoteRuntimeProbeFailure,
          onChecking: (checkingRuntime) {
            _applyWorkspaceRemoteServerActionCheckingRuntime(
              context.controller,
              connectionId: context.connectionId,
              refreshGeneration: context.refreshGeneration,
              checkingRuntime: checkingRuntime,
            );
          },
        );
    _applyWorkspaceRemoteServerActionResultRuntime(
      context.controller,
      connectionId: context.connectionId,
      refreshGeneration: context.refreshGeneration,
      nextRuntime: nextRuntime,
    );
    return nextRuntime;
  }

  Future<ConnectionRemoteRuntimeState> stop() async {
    final context = await this;
    final nextRuntime = await context.controller._remoteRuntimeCoordinator
        .stopRemoteServer(
          profile: context.savedConnection.profile,
          secrets: context.savedConnection.secrets,
          ownerId: context.connectionId,
          currentRuntime: context.controller.state.remoteRuntimeFor(
            context.connectionId,
          ),
          probeFailure: ConnectionLifecycleErrors.remoteRuntimeProbeFailure,
          onChecking: (checkingRuntime) {
            _applyWorkspaceRemoteServerActionCheckingRuntime(
              context.controller,
              connectionId: context.connectionId,
              refreshGeneration: context.refreshGeneration,
              checkingRuntime: checkingRuntime,
            );
          },
        );
    _applyWorkspaceRemoteServerActionResultRuntime(
      context.controller,
      connectionId: context.connectionId,
      refreshGeneration: context.refreshGeneration,
      nextRuntime: nextRuntime,
    );
    return nextRuntime;
  }

  Future<ConnectionRemoteRuntimeState> restart() async {
    final context = await this;
    final nextRuntime = await context.controller._remoteRuntimeCoordinator
        .restartRemoteServer(
          profile: context.savedConnection.profile,
          secrets: context.savedConnection.secrets,
          ownerId: context.connectionId,
          currentRuntime: context.controller.state.remoteRuntimeFor(
            context.connectionId,
          ),
          probeFailure: ConnectionLifecycleErrors.remoteRuntimeProbeFailure,
          onChecking: (checkingRuntime) {
            _applyWorkspaceRemoteServerActionCheckingRuntime(
              context.controller,
              connectionId: context.connectionId,
              refreshGeneration: context.refreshGeneration,
              checkingRuntime: checkingRuntime,
            );
          },
        );
    _applyWorkspaceRemoteServerActionResultRuntime(
      context.controller,
      connectionId: context.connectionId,
      refreshGeneration: context.refreshGeneration,
      nextRuntime: nextRuntime,
    );
    return nextRuntime;
  }
}

final class _WorkspaceRemoteServerActionContext {
  const _WorkspaceRemoteServerActionContext({
    required this.controller,
    required this.connectionId,
    required this.savedConnection,
    required this.refreshGeneration,
  });

  final ConnectionWorkspaceController controller;
  final String connectionId;
  final SavedConnection savedConnection;
  final int refreshGeneration;
}

Future<_WorkspaceRemoteServerActionContext> _runWorkspaceRemoteServerAction(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  final savedConnection = await controller._connectionRepository.loadConnection(
    normalizedConnectionId,
  );
  if (savedConnection.profile.isLocal) {
    throw StateError(
      'Managed remote app-server lifecycle is only available for remote connections.',
    );
  }

  final refreshGeneration =
      (controller
              ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] ??
          0) +
      1;
  controller
          ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] =
      refreshGeneration;
  return _WorkspaceRemoteServerActionContext(
    controller: controller,
    connectionId: normalizedConnectionId,
    savedConnection: savedConnection,
    refreshGeneration: refreshGeneration,
  );
}

void _applyWorkspaceRemoteServerActionCheckingRuntime(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required int refreshGeneration,
  required ConnectionRemoteRuntimeState checkingRuntime,
}) {
  if (!_canApplyWorkspaceRemoteRuntime(
    controller,
    connectionId: connectionId,
    refreshGeneration: refreshGeneration,
  )) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
        ...controller._state.remoteRuntimeByConnectionId,
        connectionId: checkingRuntime,
      },
    ),
  );
}

void _applyWorkspaceRemoteServerActionResultRuntime(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required int refreshGeneration,
  required ConnectionRemoteRuntimeState nextRuntime,
}) {
  if (!_canApplyWorkspaceRemoteRuntime(
    controller,
    connectionId: connectionId,
    refreshGeneration: refreshGeneration,
  )) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
        ...controller._state.remoteRuntimeByConnectionId,
        connectionId: nextRuntime,
      },
    ),
  );
}
