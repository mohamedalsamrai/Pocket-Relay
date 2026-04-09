import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/remote_runtime/application/connection_remote_runtime_coordinator.dart';

void main() {
  test(
    'probe maps delegate failures into a probe-failed runtime state',
    () async {
      final delegate = _FakeRemoteRuntimeDelegate(
        probeError: StateError('ssh probe failed'),
      );
      final coordinator = ConnectionRemoteRuntimeCoordinator(
        remoteRuntimeDelegateFactory: (_) => delegate,
      );

      final runtime = await coordinator.probe(
        profile: _remoteProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'conn_primary',
        probeFailure: _probeFailure,
      );

      expect(delegate.probeCalls, 1);
      expect(
        runtime.hostCapability.status,
        ConnectionRemoteHostCapabilityStatus.probeFailed,
      );
      expect(
        runtime.hostCapability.detail,
        contains(
          '[${PocketErrorCatalog.connectionSettingsRemoteRuntimeProbeFailed.code}]',
        ),
      );
      expect(runtime.hostCapability.detail, contains('ssh probe failed'));
      expect(runtime.server.status, ConnectionRemoteServerStatus.unknown);
    },
  );

  test(
    'startRemoteServer re-probes after an action failure and returns runtime truth when the server is running',
    () async {
      final checkingStates = <ConnectionRemoteRuntimeState>[];
      final delegate = _FakeRemoteRuntimeDelegate(
        probeRuntime: const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(),
          server: ConnectionRemoteServerState.running(
            ownerId: 'conn_primary',
            sessionName: 'session-conn_primary',
            port: 4100,
          ),
        ),
        startError: StateError('start failed before refresh'),
      );
      final coordinator = ConnectionRemoteRuntimeCoordinator(
        remoteRuntimeDelegateFactory: (_) => delegate,
      );

      final runtime = await coordinator.startRemoteServer(
        profile: _remoteProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'conn_primary',
        currentRuntime: const ConnectionRemoteRuntimeState.unknown(),
        probeFailure: _probeFailure,
        onChecking: checkingStates.add,
      );

      expect(delegate.startCalls, 1);
      expect(delegate.probeCalls, 1);
      expect(
        checkingStates.single.server.status,
        ConnectionRemoteServerStatus.checking,
      );
      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.port, 4100);
    },
  );

  test(
    'restartRemoteServer rethrows the action error when the follow-up probe still does not report a running server',
    () async {
      final probedRuntimes = <ConnectionRemoteRuntimeState>[];
      final delegate = _FakeRemoteRuntimeDelegate(
        probeRuntime: const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(),
          server: ConnectionRemoteServerState.notRunning(
            ownerId: 'conn_primary',
            sessionName: 'session-conn_primary',
          ),
        ),
        restartError: StateError('restart failed'),
      );
      final coordinator = ConnectionRemoteRuntimeCoordinator(
        remoteRuntimeDelegateFactory: (_) => delegate,
      );

      await expectLater(
        () => coordinator.restartRemoteServer(
          profile: _remoteProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          ownerId: 'conn_primary',
          currentRuntime: const ConnectionRemoteRuntimeState.unknown(),
          probeFailure: _probeFailure,
          onProbedRuntime: probedRuntimes.add,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'restart failed',
          ),
        ),
      );

      expect(delegate.restartCalls, 1);
      expect(delegate.probeCalls, 1);
      expect(
        probedRuntimes.single.server.status,
        ConnectionRemoteServerStatus.notRunning,
      );
    },
  );
}

ConnectionProfile _remoteProfile() {
  return ConnectionProfile(
    label: 'Developer Box',
    host: 'devbox.local',
    port: 22,
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
    authMode: AuthMode.password,
    hostFingerprint: 'SHA256:test',
    dangerouslyBypassSandbox: false,
    ephemeralSession: false,
  );
}

PocketUserFacingError _probeFailure({Object? error}) {
  return PocketUserFacingError(
    definition: PocketErrorCatalog.connectionSettingsRemoteRuntimeProbeFailed,
    title: 'System check failed',
    message: 'Could not verify the remote target.',
  ).withNormalizedUnderlyingError(error);
}

final class _FakeRemoteRuntimeDelegate
    implements AgentAdapterRemoteRuntimeDelegate {
  _FakeRemoteRuntimeDelegate({
    this.probeRuntime = const ConnectionRemoteRuntimeState.unknown(),
    this.probeError,
    this.startError,
    this.stopError,
    this.restartError,
  });

  final ConnectionRemoteRuntimeState probeRuntime;
  final Object? probeError;
  final Object? startError;
  final Object? stopError;
  final Object? restartError;

  int probeCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int restartCalls = 0;

  @override
  String buildSessionName(String ownerId) => 'session-$ownerId';

  @override
  Future<ConnectionRemoteRuntimeState> probeRemoteRuntime({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    probeCalls += 1;
    if (probeError != null) {
      throw probeError!;
    }
    return probeRuntime;
  }

  @override
  Future<void> restartRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {
    restartCalls += 1;
    if (restartError != null) {
      throw restartError!;
    }
  }

  @override
  Future<void> startRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {
    startCalls += 1;
    if (startError != null) {
      throw startError!;
    }
  }

  @override
  Future<void> stopRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {
    stopCalls += 1;
    if (stopError != null) {
      throw stopError!;
    }
  }
}
