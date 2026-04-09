import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/remote_runtime/application/connection_remote_runtime_coordinator.dart';

final class WorkspaceRemoteRuntimeController {
  WorkspaceRemoteRuntimeController({
    required AgentAdapterRemoteRuntimeDelegateFactory
    remoteRuntimeDelegateFactory,
  }) : _coordinator = ConnectionRemoteRuntimeCoordinator(
         remoteRuntimeDelegateFactory: remoteRuntimeDelegateFactory,
       );

  final ConnectionRemoteRuntimeCoordinator _coordinator;
  final Map<String, int> _refreshGenerationByConnectionId = <String, int>{};

  int beginRefresh(String connectionId) {
    final refreshGeneration =
        (_refreshGenerationByConnectionId[connectionId] ?? 0) + 1;
    _refreshGenerationByConnectionId[connectionId] = refreshGeneration;
    return refreshGeneration;
  }

  bool isCurrentRefreshGeneration({
    required String connectionId,
    required int refreshGeneration,
  }) {
    return _refreshGenerationByConnectionId[connectionId] == refreshGeneration;
  }

  void forgetConnection(String connectionId) {
    _refreshGenerationByConnectionId.remove(connectionId);
  }

  void invalidateRefreshes(String connectionId) {
    final currentGeneration = _refreshGenerationByConnectionId[connectionId];
    if (currentGeneration == null) {
      return;
    }
    _refreshGenerationByConnectionId[connectionId] = currentGeneration + 1;
  }

  ConnectionRemoteRuntimeState buildProbeCheckingRuntime() {
    return _coordinator.buildProbeCheckingRuntime();
  }

  Future<ConnectionRemoteRuntimeState> probe({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
    required ConnectionRemoteRuntimeProbeFailureBuilder probeFailure,
  }) {
    return _coordinator.probe(
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
    return _coordinator.startRemoteServer(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      currentRuntime: currentRuntime,
      probeFailure: probeFailure,
      onChecking: onChecking,
      onProbedRuntime: onProbedRuntime,
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
    return _coordinator.stopRemoteServer(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      currentRuntime: currentRuntime,
      probeFailure: probeFailure,
      onChecking: onChecking,
      onProbedRuntime: onProbedRuntime,
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
    return _coordinator.restartRemoteServer(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      currentRuntime: currentRuntime,
      probeFailure: probeFailure,
      onChecking: onChecking,
      onProbedRuntime: onProbedRuntime,
    );
  }
}
