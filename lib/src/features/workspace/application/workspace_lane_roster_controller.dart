import 'dart:async';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_live_binding_registry.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

final class WorkspaceLaneRosterController {
  WorkspaceLaneRosterController({
    WorkspaceLiveBindingRegistry? liveBindingRegistry,
  }) : _liveBindingRegistry =
           liveBindingRegistry ?? WorkspaceLiveBindingRegistry();

  final WorkspaceLiveBindingRegistry _liveBindingRegistry;

  Iterable<String> get connectionIds => _liveBindingRegistry.connectionIds;

  ConnectionLaneBinding? bindingFor(String connectionId) {
    return _liveBindingRegistry.bindingFor(connectionId);
  }

  ConnectionLaneBinding? selectedBinding(ConnectionWorkspaceState state) {
    final selectedConnectionId = state.selectedConnectionId;
    if (selectedConnectionId == null) {
      return null;
    }
    return bindingFor(selectedConnectionId);
  }

  void putBinding(String connectionId, ConnectionLaneBinding binding) {
    _liveBindingRegistry.putBinding(connectionId, binding);
  }

  ConnectionLaneBinding? removeBinding(String connectionId) {
    return _liveBindingRegistry.removeBinding(connectionId);
  }

  void registerBinding({
    required String connectionId,
    required ConnectionLaneBinding binding,
    required WorkspaceLiveBindingListener listener,
    required StreamSubscription<AgentAdapterEvent>
    agentAdapterEventSubscription,
  }) {
    _liveBindingRegistry.register(
      connectionId: connectionId,
      binding: binding,
      listener: listener,
      agentAdapterEventSubscription: agentAdapterEventSubscription,
    );
  }

  void unregisterBinding(String connectionId) {
    _liveBindingRegistry.unregister(connectionId);
  }

  List<ConnectionLaneBinding> detachAllBindings() {
    return _liveBindingRegistry.detachAll();
  }

  List<String> orderedLiveConnectionIds(ConnectionCatalogState catalog) {
    final liveConnectionIdSet = connectionIds.toSet();
    return <String>[
      for (final connectionId in catalog.orderedConnectionIds)
        if (liveConnectionIdSet.contains(connectionId)) connectionId,
    ];
  }

  WorkspaceLaneTerminationPlan planTerminationAfterRemoval({
    required ConnectionWorkspaceState state,
    required String removedConnectionId,
  }) {
    final removalIndex = state.liveConnectionIds.indexOf(removedConnectionId);
    final nextLiveConnectionIds = orderedLiveConnectionIds(state.catalog);
    final nextSelectedConnectionId = _nextSelectedConnectionIdAfterRemoval(
      state: state,
      removedConnectionId: removedConnectionId,
      removalIndex: removalIndex,
      nextLiveConnectionIds: nextLiveConnectionIds,
    );
    return WorkspaceLaneTerminationPlan(
      liveConnectionIds: nextLiveConnectionIds,
      selectedConnectionId: nextSelectedConnectionId,
      viewport: _nextViewportAfterRemoval(
        state: state,
        removedConnectionId: removedConnectionId,
        nextSelectedConnectionId: nextSelectedConnectionId,
      ),
    );
  }
}

final class WorkspaceLaneTerminationPlan {
  const WorkspaceLaneTerminationPlan({
    required this.liveConnectionIds,
    required this.selectedConnectionId,
    required this.viewport,
  });

  final List<String> liveConnectionIds;
  final String? selectedConnectionId;
  final ConnectionWorkspaceViewport viewport;
}

String? _nextSelectedConnectionIdAfterRemoval({
  required ConnectionWorkspaceState state,
  required String removedConnectionId,
  required int removalIndex,
  required List<String> nextLiveConnectionIds,
}) {
  if (state.selectedConnectionId != removedConnectionId) {
    return state.selectedConnectionId;
  }
  if (nextLiveConnectionIds.isEmpty) {
    return null;
  }

  final nextIndex = removalIndex.clamp(0, nextLiveConnectionIds.length - 1);
  return nextLiveConnectionIds[nextIndex];
}

ConnectionWorkspaceViewport _nextViewportAfterRemoval({
  required ConnectionWorkspaceState state,
  required String removedConnectionId,
  required String? nextSelectedConnectionId,
}) {
  if (state.selectedConnectionId == removedConnectionId &&
      nextSelectedConnectionId == null) {
    return ConnectionWorkspaceViewport.savedConnections;
  }

  return state.viewport;
}
