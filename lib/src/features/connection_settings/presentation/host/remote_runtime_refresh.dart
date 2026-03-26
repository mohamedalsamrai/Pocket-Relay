part of '../connection_settings_host.dart';

void _scheduleConnectionSettingsRemoteRuntimeRefresh(
  _ConnectionSettingsHostState state, {
  bool immediate = false,
}) {
  state._remoteRuntimeRefreshDebounce?.cancel();
  final onRefreshRemoteRuntime = state.widget.onRefreshRemoteRuntime;
  if (onRefreshRemoteRuntime == null) {
    if (state._remoteRuntime != state.widget.initialRemoteRuntime) {
      state._setStateInternal(() {
        state._remoteRuntime = state.widget.initialRemoteRuntime;
      });
    }
    return;
  }

  if (state._formState.draft.connectionMode != ConnectionMode.remote) {
    if (state._remoteRuntime != null) {
      state._setStateInternal(() {
        state._remoteRuntime = null;
      });
    }
    return;
  }

  final probePayload = state._buildContract().saveAction.submitPayload;
  if (probePayload == null) {
    const nextRuntime = ConnectionRemoteRuntimeState.unknown();
    if (state._remoteRuntime != nextRuntime) {
      state._setStateInternal(() {
        state._remoteRuntime = nextRuntime;
      });
    }
    return;
  }

  const checkingRuntime = ConnectionRemoteRuntimeState(
    hostCapability: ConnectionRemoteHostCapabilityState.checking(),
    server: ConnectionRemoteServerState.unknown(),
  );
  if ((!immediate || state._remoteRuntime == null) &&
      state._remoteRuntime != checkingRuntime) {
    state._setStateInternal(() {
      state._remoteRuntime = checkingRuntime;
    });
  }

  final refreshToken = ++state._remoteRuntimeRefreshToken;
  Future<void> runProbe() async {
    try {
      final remoteRuntime = await onRefreshRemoteRuntime(probePayload);
      if (!state.mounted || refreshToken != state._remoteRuntimeRefreshToken) {
        return;
      }
      state._setStateInternal(() {
        state._remoteRuntime = remoteRuntime;
      });
    } catch (error) {
      if (!state.mounted || refreshToken != state._remoteRuntimeRefreshToken) {
        return;
      }
      state._setStateInternal(() {
        state._remoteRuntime = ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.probeFailed(
            detail: '$error',
          ),
          server: const ConnectionRemoteServerState.unknown(),
        );
      });
    }
  }

  if (immediate) {
    unawaited(runProbe());
    return;
  }

  state._remoteRuntimeRefreshDebounce = Timer(
    const Duration(milliseconds: 350),
    () {
      unawaited(runProbe());
    },
  );
}
