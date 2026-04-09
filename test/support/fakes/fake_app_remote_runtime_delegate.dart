import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

AgentAdapterRemoteRuntimeDelegate fakeAppRemoteRuntimeDelegateFactory(
  AgentAdapterKind kind,
) {
  return const FakeAppRemoteRuntimeDelegate();
}

final class FakeAppRemoteRuntimeDelegate
    implements AgentAdapterRemoteRuntimeDelegate {
  const FakeAppRemoteRuntimeDelegate({
    this.notRunningDetail = 'Managed remote app-server is not running.',
  });

  final String? notRunningDetail;

  @override
  String buildSessionName(String ownerId) => 'pocket-relay-$ownerId';

  @override
  Future<ConnectionRemoteRuntimeState> probeRemoteRuntime({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    final normalizedOwnerId = ownerId ?? 'conn_primary';
    return ConnectionRemoteRuntimeState(
      hostCapability: const ConnectionRemoteHostCapabilityState.supported(),
      server: ConnectionRemoteServerState.notRunning(
        ownerId: normalizedOwnerId,
        sessionName: buildSessionName(normalizedOwnerId),
        detail: notRunningDetail,
      ),
    );
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
