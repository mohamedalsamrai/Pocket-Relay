import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

typedef ConnectionRemoteRuntimeProbeFailureBuilder =
    PocketUserFacingError Function({Object? error});

const connectionRemoteRuntimeProbeCheckingState = ConnectionRemoteRuntimeState(
  hostCapability: ConnectionRemoteHostCapabilityState.checking(),
  server: ConnectionRemoteServerState.unknown(),
);

ConnectionRemoteRuntimeState buildConnectionRemoteRuntimeProbeFailureState(
  PocketUserFacingError error,
) {
  return ConnectionRemoteRuntimeState(
    hostCapability: ConnectionRemoteHostCapabilityState.probeFailed(
      detail: error.bodyWithCode,
    ),
    server: const ConnectionRemoteServerState.unknown(),
  );
}

final class ConnectionRemoteRuntimeCoordinator {
  ConnectionRemoteRuntimeCoordinator({
    required AgentAdapterRemoteRuntimeDelegateFactory
    remoteRuntimeDelegateFactory,
  }) : _remoteRuntimeDelegateFactory = remoteRuntimeDelegateFactory;

  final AgentAdapterRemoteRuntimeDelegateFactory _remoteRuntimeDelegateFactory;

  ConnectionRemoteRuntimeState buildProbeCheckingRuntime() {
    return connectionRemoteRuntimeProbeCheckingState;
  }

  ConnectionRemoteRuntimeState buildActionCheckingRuntime({
    required AgentAdapterRemoteRuntimeDelegate delegate,
    required String ownerId,
    required String detail,
    ConnectionRemoteRuntimeState? currentRuntime,
  }) {
    return ConnectionRemoteRuntimeState(
      hostCapability:
          currentRuntime?.hostCapability ??
          const ConnectionRemoteHostCapabilityState.unknown(),
      server: ConnectionRemoteServerState.checking(
        ownerId: ownerId,
        sessionName: delegate.buildSessionName(ownerId),
        detail: detail,
      ),
    );
  }

  Future<ConnectionRemoteRuntimeState> probe({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
    required ConnectionRemoteRuntimeProbeFailureBuilder probeFailure,
  }) async {
    final delegate = _remoteRuntimeDelegateFactory(profile.agentAdapter);
    return _probeWithDelegate(
      delegate,
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      probeFailure: probeFailure,
    );
  }

  Future<ConnectionRemoteRuntimeState> startRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    ConnectionRemoteRuntimeState? currentRuntime,
    required ConnectionRemoteRuntimeProbeFailureBuilder probeFailure,
    void Function(ConnectionRemoteRuntimeState runtime)? onChecking,
    void Function(ConnectionRemoteRuntimeState runtime)? onProbedRuntime,
  }) {
    return _runServerAction(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      currentRuntime: currentRuntime,
      probeFailure: probeFailure,
      onChecking: onChecking,
      onProbedRuntime: onProbedRuntime,
      actionDetail: 'Starting managed remote runtime…',
      runAction: (delegate) => delegate.startRemoteServer(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
      ),
      actionSucceeded: (runtime) =>
          runtime.server.status == ConnectionRemoteServerStatus.running,
    );
  }

  Future<ConnectionRemoteRuntimeState> stopRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    ConnectionRemoteRuntimeState? currentRuntime,
    required ConnectionRemoteRuntimeProbeFailureBuilder probeFailure,
    void Function(ConnectionRemoteRuntimeState runtime)? onChecking,
    void Function(ConnectionRemoteRuntimeState runtime)? onProbedRuntime,
  }) {
    return _runServerAction(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      currentRuntime: currentRuntime,
      probeFailure: probeFailure,
      onChecking: onChecking,
      onProbedRuntime: onProbedRuntime,
      actionDetail: 'Stopping managed remote runtime…',
      runAction: (delegate) => delegate.stopRemoteServer(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
      ),
      actionSucceeded: (runtime) =>
          runtime.server.status == ConnectionRemoteServerStatus.notRunning,
    );
  }

  Future<ConnectionRemoteRuntimeState> restartRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    ConnectionRemoteRuntimeState? currentRuntime,
    required ConnectionRemoteRuntimeProbeFailureBuilder probeFailure,
    void Function(ConnectionRemoteRuntimeState runtime)? onChecking,
    void Function(ConnectionRemoteRuntimeState runtime)? onProbedRuntime,
  }) {
    return _runServerAction(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      currentRuntime: currentRuntime,
      probeFailure: probeFailure,
      onChecking: onChecking,
      onProbedRuntime: onProbedRuntime,
      actionDetail: 'Restarting managed remote runtime…',
      runAction: (delegate) => delegate.restartRemoteServer(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
      ),
      actionSucceeded: (runtime) =>
          runtime.server.status == ConnectionRemoteServerStatus.running,
    );
  }

  Future<ConnectionRemoteRuntimeState> _probeWithDelegate(
    AgentAdapterRemoteRuntimeDelegate delegate, {
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required ConnectionRemoteRuntimeProbeFailureBuilder probeFailure,
    String? ownerId,
  }) async {
    try {
      return await delegate.probeRemoteRuntime(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
      );
    } catch (error) {
      return buildConnectionRemoteRuntimeProbeFailureState(
        probeFailure(error: error),
      );
    }
  }

  Future<ConnectionRemoteRuntimeState> _runServerAction({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String actionDetail,
    required ConnectionRemoteRuntimeProbeFailureBuilder probeFailure,
    required Future<void> Function(AgentAdapterRemoteRuntimeDelegate delegate)
    runAction,
    required bool Function(ConnectionRemoteRuntimeState runtime)
    actionSucceeded,
    ConnectionRemoteRuntimeState? currentRuntime,
    void Function(ConnectionRemoteRuntimeState runtime)? onChecking,
    void Function(ConnectionRemoteRuntimeState runtime)? onProbedRuntime,
  }) async {
    if (profile.isLocal) {
      throw StateError(
        'Managed remote app-server lifecycle is only available for remote connections.',
      );
    }

    final delegate = _remoteRuntimeDelegateFactory(profile.agentAdapter);
    onChecking?.call(
      buildActionCheckingRuntime(
        delegate: delegate,
        ownerId: ownerId,
        detail: actionDetail,
        currentRuntime: currentRuntime,
      ),
    );

    Object? actionError;
    StackTrace? actionStackTrace;
    try {
      await runAction(delegate);
    } catch (error, stackTrace) {
      actionError = error;
      actionStackTrace = stackTrace;
    }

    final nextRuntime = await _probeWithDelegate(
      delegate,
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      probeFailure: probeFailure,
    );
    onProbedRuntime?.call(nextRuntime);
    if (actionError != null && !actionSucceeded(nextRuntime)) {
      Error.throwWithStackTrace(actionError, actionStackTrace!);
    }
    return nextRuntime;
  }
}
