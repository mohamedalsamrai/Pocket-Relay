import 'dart:async';

import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

typedef WorkspaceLiveBindingListener = void Function();

final class WorkspaceLiveBindingRegistry {
  final Map<String, ConnectionLaneBinding> _bindings =
      <String, ConnectionLaneBinding>{};
  final Map<String, _WorkspaceLiveBindingRegistration> _registrations =
      <String, _WorkspaceLiveBindingRegistration>{};

  Iterable<String> get laneIds => _bindings.keys;

  ConnectionLaneBinding? bindingFor(String laneId) {
    return _bindings[laneId];
  }

  void putBinding(String laneId, ConnectionLaneBinding binding) {
    _bindings[laneId] = binding;
  }

  ConnectionLaneBinding? removeBinding(String laneId) {
    return _bindings.remove(laneId);
  }

  void register({
    required String laneId,
    required ConnectionLaneBinding binding,
    required WorkspaceLiveBindingListener listener,
    required StreamSubscription<AgentAdapterEvent>
    agentAdapterEventSubscription,
  }) {
    unregister(laneId);
    _registrations[laneId] = _WorkspaceLiveBindingRegistration(
      binding: binding,
      listener: listener,
      agentAdapterEventSubscription: agentAdapterEventSubscription,
    );
    binding.sessionController.addListener(listener);
    binding.composerDraftHost.addListener(listener);
  }

  void unregister(String laneId) {
    final registration = _registrations.remove(laneId);
    if (registration == null) {
      return;
    }

    registration.binding.sessionController.removeListener(
      registration.listener,
    );
    registration.binding.composerDraftHost.removeListener(
      registration.listener,
    );
    unawaited(registration.agentAdapterEventSubscription.cancel());
  }

  List<ConnectionLaneBinding> detachAll() {
    final bindings = _bindings.values.toList();
    _bindings.clear();
    for (final laneId in _registrations.keys.toList()) {
      unregister(laneId);
    }
    return bindings;
  }
}

final class _WorkspaceLiveBindingRegistration {
  const _WorkspaceLiveBindingRegistration({
    required this.binding,
    required this.listener,
    required this.agentAdapterEventSubscription,
  });

  final ConnectionLaneBinding binding;
  final WorkspaceLiveBindingListener listener;
  final StreamSubscription<AgentAdapterEvent> agentAdapterEventSubscription;
}
