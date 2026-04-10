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

  Iterable<String> get laneIds => _liveBindingRegistry.laneIds;

  ConnectionLaneBinding? bindingForLaneId(String laneId) {
    return _liveBindingRegistry.bindingFor(laneId);
  }

  ConnectionLaneBinding? bindingForConnection(
    ConnectionWorkspaceState state,
    String connectionId,
  ) {
    final laneId = state.primaryLiveLaneIdForConnection(connectionId);
    if (laneId == null) {
      return null;
    }
    return bindingForLaneId(laneId);
  }

  ConnectionLaneBinding? selectedBinding(ConnectionWorkspaceState state) {
    final selectedLaneId = state.selectedLaneId;
    if (selectedLaneId == null) {
      return null;
    }
    return bindingForLaneId(selectedLaneId);
  }

  void putBinding(String laneId, ConnectionLaneBinding binding) {
    _liveBindingRegistry.putBinding(laneId, binding);
  }

  ConnectionLaneBinding? removeBinding(String laneId) {
    return _liveBindingRegistry.removeBinding(laneId);
  }

  void registerBinding({
    required String laneId,
    required ConnectionLaneBinding binding,
    required WorkspaceLiveBindingListener listener,
    required StreamSubscription<AgentAdapterEvent>
    agentAdapterEventSubscription,
  }) {
    _liveBindingRegistry.register(
      laneId: laneId,
      binding: binding,
      listener: listener,
      agentAdapterEventSubscription: agentAdapterEventSubscription,
    );
  }

  void unregisterBinding(String laneId) {
    _liveBindingRegistry.unregister(laneId);
  }

  List<ConnectionLaneBinding> detachAllBindings() {
    return _liveBindingRegistry.detachAll();
  }

  List<ConnectionWorkspaceLiveLane> orderedLiveLanes(
    ConnectionCatalogState catalog,
    List<ConnectionWorkspaceLiveLane> liveLanes,
  ) {
    final liveLanesByConnectionId = <String, List<ConnectionWorkspaceLiveLane>>{
      for (final connectionId in catalog.orderedConnectionIds)
        connectionId: <ConnectionWorkspaceLiveLane>[],
    };
    for (final lane in liveLanes) {
      final connectionLanes =
          liveLanesByConnectionId[lane.connectionId] ??
          <ConnectionWorkspaceLiveLane>[];
      connectionLanes.add(lane);
      liveLanesByConnectionId[lane.connectionId] = connectionLanes;
    }

    return <ConnectionWorkspaceLiveLane>[
      for (final connectionId in catalog.orderedConnectionIds)
        ...?liveLanesByConnectionId[connectionId],
    ];
  }

  WorkspaceLaneTerminationPlan planTerminationAfterRemoval({
    required ConnectionWorkspaceState state,
    required String removedLaneId,
  }) {
    final removalIndex = state.liveLaneIds.indexOf(removedLaneId);
    final nextLiveLanes = orderedLiveLanes(
      state.catalog,
      <ConnectionWorkspaceLiveLane>[
        for (final lane in state.liveLanes)
          if (lane.laneId != removedLaneId) lane,
      ],
    );
    final nextSelectedLaneId = _nextSelectedLaneIdAfterRemoval(
      state: state,
      removedLaneId: removedLaneId,
      removalIndex: removalIndex,
      nextLiveLanes: nextLiveLanes,
    );
    return WorkspaceLaneTerminationPlan(
      liveLanes: nextLiveLanes,
      selectedLaneId: nextSelectedLaneId,
      viewport: _nextViewportAfterRemoval(
        state: state,
        removedLaneId: removedLaneId,
        nextSelectedLaneId: nextSelectedLaneId,
      ),
    );
  }
}

final class WorkspaceLaneTerminationPlan {
  const WorkspaceLaneTerminationPlan({
    required this.liveLanes,
    required this.selectedLaneId,
    required this.viewport,
  });

  final List<ConnectionWorkspaceLiveLane> liveLanes;
  final String? selectedLaneId;
  final ConnectionWorkspaceViewport viewport;
}

String? _nextSelectedLaneIdAfterRemoval({
  required ConnectionWorkspaceState state,
  required String removedLaneId,
  required int removalIndex,
  required List<ConnectionWorkspaceLiveLane> nextLiveLanes,
}) {
  if (state.selectedLaneId != removedLaneId) {
    return state.selectedLaneId;
  }
  if (nextLiveLanes.isEmpty) {
    return null;
  }

  final nextIndex = removalIndex.clamp(0, nextLiveLanes.length - 1);
  return nextLiveLanes[nextIndex].laneId;
}

ConnectionWorkspaceViewport _nextViewportAfterRemoval({
  required ConnectionWorkspaceState state,
  required String removedLaneId,
  required String? nextSelectedLaneId,
}) {
  if (state.selectedLaneId == removedLaneId && nextSelectedLaneId == null) {
    return ConnectionWorkspaceViewport.savedConnections;
  }

  return state.viewport;
}
