import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_remote_runtime_controller.dart';

void main() {
  test('tracks current refresh generations by connection id', () {
    final controller = WorkspaceRemoteRuntimeController(
      remoteRuntimeDelegateFactory: (_) => _FakeRemoteRuntimeDelegate(),
    );

    final firstPrimaryGeneration = controller.beginRefresh('conn_primary');
    final secondPrimaryGeneration = controller.beginRefresh('conn_primary');
    final secondaryGeneration = controller.beginRefresh('conn_secondary');

    expect(firstPrimaryGeneration, 1);
    expect(secondPrimaryGeneration, 2);
    expect(secondaryGeneration, 1);
    expect(
      controller.isCurrentRefreshGeneration(
        connectionId: 'conn_primary',
        refreshGeneration: firstPrimaryGeneration,
      ),
      isFalse,
    );
    expect(
      controller.isCurrentRefreshGeneration(
        connectionId: 'conn_primary',
        refreshGeneration: secondPrimaryGeneration,
      ),
      isTrue,
    );

    controller.forgetConnection('conn_primary');

    expect(
      controller.isCurrentRefreshGeneration(
        connectionId: 'conn_primary',
        refreshGeneration: secondPrimaryGeneration,
      ),
      isFalse,
    );
    expect(
      controller.isCurrentRefreshGeneration(
        connectionId: 'conn_secondary',
        refreshGeneration: secondaryGeneration,
      ),
      isTrue,
    );
  });

  test('invalidates pending refreshes without reusing generations', () {
    final controller = WorkspaceRemoteRuntimeController(
      remoteRuntimeDelegateFactory: (_) => _FakeRemoteRuntimeDelegate(),
    );

    final staleGeneration = controller.beginRefresh('conn_primary');

    controller.invalidateRefreshes('conn_primary');

    expect(
      controller.isCurrentRefreshGeneration(
        connectionId: 'conn_primary',
        refreshGeneration: staleGeneration,
      ),
      isFalse,
    );
    expect(controller.beginRefresh('conn_primary'), staleGeneration + 2);
  });

  test(
    'delegates probes through the selected agent adapter runtime owner',
    () async {
      final delegate = _FakeRemoteRuntimeDelegate(
        probeRuntime: const ConnectionRemoteRuntimeState(
          hostCapability: ConnectionRemoteHostCapabilityState.supported(),
          server: ConnectionRemoteServerState.notRunning(
            ownerId: 'conn_primary',
          ),
        ),
      );
      final controller = WorkspaceRemoteRuntimeController(
        remoteRuntimeDelegateFactory: (_) => delegate,
      );

      final runtime = await controller.probe(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'conn_primary',
        probeFailure: ({error}) => PocketUserFacingError(
          definition:
              PocketErrorCatalog.connectionSettingsRemoteRuntimeProbeFailed,
          title: 'Probe failed',
          message: '$error',
        ),
      );

      expect(runtime.server.status, ConnectionRemoteServerStatus.notRunning);
      expect(delegate.probeCalls, 1);
      expect(delegate.lastOwnerId, 'conn_primary');
    },
  );
}

final class _FakeRemoteRuntimeDelegate
    implements AgentAdapterRemoteRuntimeDelegate {
  _FakeRemoteRuntimeDelegate({ConnectionRemoteRuntimeState? probeRuntime})
    : _probeRuntime =
          probeRuntime ??
          const ConnectionRemoteRuntimeState(
            hostCapability: ConnectionRemoteHostCapabilityState.unknown(),
            server: ConnectionRemoteServerState.unknown(),
          );

  final ConnectionRemoteRuntimeState _probeRuntime;
  int probeCalls = 0;
  String? lastOwnerId;

  @override
  String buildSessionName(String ownerId) => 'pocket-relay-$ownerId';

  @override
  Future<ConnectionRemoteRuntimeState> probeRemoteRuntime({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    probeCalls += 1;
    lastOwnerId = ownerId;
    return _probeRuntime;
  }

  @override
  Future<void> restartRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {}

  @override
  Future<void> startRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {}

  @override
  Future<void> stopRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {}
}
