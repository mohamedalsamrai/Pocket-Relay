import 'dart:async';

import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

typedef WorkspaceLiveBindingListener = void Function();

final class WorkspaceLiveBindingRegistry {
  final Map<String, ConnectionLaneBinding> _bindings =
      <String, ConnectionLaneBinding>{};
  final Map<String, _WorkspaceLiveBindingRegistration> _registrations =
      <String, _WorkspaceLiveBindingRegistration>{};

  Iterable<String> get connectionIds => _bindings.keys;

  ConnectionLaneBinding? bindingFor(String connectionId) {
    return _bindings[connectionId];
  }

  void putBinding(String connectionId, ConnectionLaneBinding binding) {
    _bindings[connectionId] = binding;
  }

  ConnectionLaneBinding? removeBinding(String connectionId) {
    return _bindings.remove(connectionId);
  }

  void register({
    required String connectionId,
    required ConnectionLaneBinding binding,
    required WorkspaceLiveBindingListener listener,
    required StreamSubscription<AgentAdapterEvent>
    agentAdapterEventSubscription,
  }) {
    unregister(connectionId);
    _registrations[connectionId] = _WorkspaceLiveBindingRegistration(
      binding: binding,
      listener: listener,
      agentAdapterEventSubscription: agentAdapterEventSubscription,
    );
    binding.sessionController.addListener(listener);
    binding.composerDraftHost.addListener(listener);
  }

  void unregister(String connectionId) {
    final registration = _registrations.remove(connectionId);
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

  List<MapEntry<String, ConnectionLaneBinding>> detachAll() {
    final entries = _bindings.entries.toList();
    _bindings.clear();
    for (final connectionId in _registrations.keys.toList()) {
      unregister(connectionId);
    }
    return entries;
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
