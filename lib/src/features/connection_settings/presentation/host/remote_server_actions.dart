part of '../connection_settings_host.dart';

Future<void> _runConnectionSettingsRemoteServerAction(
  _ConnectionSettingsHostState state,
  ConnectionSettingsRemoteServerActionId actionId,
) async {
  if (state._activeRemoteServerAction != null) {
    return;
  }

  final runner = switch (actionId) {
    ConnectionSettingsRemoteServerActionId.start =>
      state.widget.onStartRemoteServer,
    ConnectionSettingsRemoteServerActionId.stop => state.widget.onStopRemoteServer,
    ConnectionSettingsRemoteServerActionId.restart =>
      state.widget.onRestartRemoteServer,
  };
  final currentRuntime = state._remoteRuntime;
  if (runner == null || currentRuntime == null) {
    return;
  }

  state._remoteRuntimeRefreshDebounce?.cancel();
  state._remoteRuntimeRefreshToken += 1;

  state._setStateInternal(() {
    state._activeRemoteServerAction = actionId;
    state._remoteRuntime = currentRuntime.copyWith(
      server: ConnectionRemoteServerState.checking(
        ownerId: currentRuntime.server.ownerId,
        sessionName: currentRuntime.server.sessionName,
        detail: switch (actionId) {
          ConnectionSettingsRemoteServerActionId.start =>
            'Starting remote Pocket Relay server…',
          ConnectionSettingsRemoteServerActionId.stop =>
            'Stopping remote Pocket Relay server…',
          ConnectionSettingsRemoteServerActionId.restart =>
            'Restarting remote Pocket Relay server…',
        },
      ),
    );
  });

  try {
    final nextRuntime = await runner();
    if (!state.mounted) {
      return;
    }
    state._setStateInternal(() {
      state._remoteRuntime = nextRuntime;
    });
  } catch (error) {
    if (!state.mounted) {
      return;
    }
    final nextRuntime = await state._remoteRuntimeAfterServerActionFailure(
      error: error,
      fallbackRuntime: currentRuntime,
    );
    if (!state.mounted) {
      return;
    }
    state._setStateInternal(() {
      state._remoteRuntime = nextRuntime;
    });
  } finally {
    if (state.mounted) {
      state._setStateInternal(() {
        state._activeRemoteServerAction = null;
      });
    }
  }
}

Future<ConnectionRemoteRuntimeState>
_connectionSettingsRemoteRuntimeAfterServerActionFailure(
  _ConnectionSettingsHostState state, {
  required Object error,
  required ConnectionRemoteRuntimeState fallbackRuntime,
}) async {
  final refreshRemoteRuntime = state.widget.onRefreshRemoteRuntime;
  final payload = state._buildContract().saveAction.submitPayload;
  if (refreshRemoteRuntime != null && payload != null) {
    try {
      return await refreshRemoteRuntime(payload);
    } catch (refreshError) {
      return ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.probeFailed(
          detail: '$refreshError',
        ),
        server: fallbackRuntime.server,
      );
    }
  }

  return ConnectionRemoteRuntimeState(
    hostCapability: ConnectionRemoteHostCapabilityState.probeFailed(
      detail: '$error',
    ),
    server: fallbackRuntime.server,
  );
}
