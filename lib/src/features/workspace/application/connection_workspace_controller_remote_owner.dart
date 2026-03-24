part of 'connection_workspace_controller.dart';

Future<ConnectionRemoteRuntimeState> _startWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    connectionId: connectionId,
    actionDetail: 'Starting remote Pocket Relay server…',
    runAction: ({required profile, required secrets, required ownerId}) =>
        controller._remoteAppServerOwnerControl.startOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: profile.workspaceDir,
        ),
  );
}

Future<ConnectionRemoteRuntimeState> _stopWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    connectionId: connectionId,
    actionDetail: 'Stopping remote Pocket Relay server…',
    runAction: ({required profile, required secrets, required ownerId}) =>
        controller._remoteAppServerOwnerControl.stopOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: profile.workspaceDir,
        ),
  );
}

Future<ConnectionRemoteRuntimeState> _restartWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    connectionId: connectionId,
    actionDetail: 'Restarting remote Pocket Relay server…',
    runAction: ({required profile, required secrets, required ownerId}) =>
        controller._remoteAppServerOwnerControl.restartOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: profile.workspaceDir,
        ),
  );
}

typedef _WorkspaceRemoteServerActionRunner =
    Future<CodexRemoteAppServerOwnerSnapshot> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required String ownerId,
    });

Future<ConnectionRemoteRuntimeState> _runWorkspaceRemoteServerAction(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required String actionDetail,
  required _WorkspaceRemoteServerActionRunner runAction,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  final savedConnection = await controller._connectionRepository.loadConnection(
    normalizedConnectionId,
  );
  if (savedConnection.profile.isLocal) {
    throw StateError(
      'Remote Pocket Relay server lifecycle is only available for remote connections.',
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

  final sessionName = buildPocketRelayRemoteOwnerSessionName(
    ownerId: normalizedConnectionId,
  );
  final existingRuntime = controller.state.remoteRuntimeFor(
    normalizedConnectionId,
  );
  final checkingRuntime = ConnectionRemoteRuntimeState(
    hostCapability:
        existingRuntime?.hostCapability ??
        const ConnectionRemoteHostCapabilityState.unknown(),
    server: ConnectionRemoteServerState.checking(
      ownerId: normalizedConnectionId,
      sessionName: sessionName,
      detail: actionDetail,
    ),
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
          normalizedConnectionId: checkingRuntime,
        },
      ),
    );
  }

  try {
    await runAction(
      profile: savedConnection.profile,
      secrets: savedConnection.secrets,
      ownerId: normalizedConnectionId,
    );
  } catch (_) {
    // Always re-probe after an explicit lifecycle action so runtime truth comes
    // from the remote host, even when the action itself fails.
  }

  return _refreshWorkspaceRemoteRuntime(
    controller,
    normalizedConnectionId,
    profile: savedConnection.profile,
    secrets: savedConnection.secrets,
  );
}
