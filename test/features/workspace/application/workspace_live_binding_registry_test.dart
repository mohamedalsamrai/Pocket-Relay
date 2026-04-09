import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_live_binding_registry.dart';

void main() {
  test('stores live bindings and detaches registered listeners', () async {
    final (:binding, :client) = _buildBinding();
    final registry = WorkspaceLiveBindingRegistry();
    var listenerCalls = 0;

    registry.putBinding('conn_primary', binding);
    registry.register(
      connectionId: 'conn_primary',
      binding: binding,
      listener: () {
        listenerCalls += 1;
      },
      agentAdapterEventSubscription: client.events.listen((_) {}),
    );

    expect(registry.bindingFor('conn_primary'), same(binding));
    expect(registry.connectionIds, contains('conn_primary'));

    binding.restoreComposerDraft('Draft');

    expect(listenerCalls, 1);

    final detachedBindings = registry.detachAll();

    expect(detachedBindings.single, same(binding));
    expect(registry.bindingFor('conn_primary'), isNull);

    binding.restoreComposerDraft('Draft after detach');

    expect(listenerCalls, 1);
  });

  test('unregister detaches listeners without removing the binding', () async {
    final (:binding, :client) = _buildBinding();
    final registry = WorkspaceLiveBindingRegistry();
    var listenerCalls = 0;

    registry.putBinding('conn_primary', binding);
    registry.register(
      connectionId: 'conn_primary',
      binding: binding,
      listener: () {
        listenerCalls += 1;
      },
      agentAdapterEventSubscription: client.events.listen((_) {}),
    );

    registry.unregister('conn_primary');
    binding.restoreComposerDraft('Detached draft');

    expect(listenerCalls, 0);
    expect(registry.bindingFor('conn_primary'), same(binding));
    expect(registry.removeBinding('conn_primary'), same(binding));
    expect(registry.bindingFor('conn_primary'), isNull);
  });
}

({ConnectionLaneBinding binding, FakeCodexAppServerClient client})
_buildBinding() {
  final client = FakeCodexAppServerClient();
  final savedProfile = SavedProfile(
    profile: ConnectionProfile.defaults().copyWith(
      label: 'Primary Box',
      host: 'primary.local',
      username: 'vince',
      workspaceDir: '/workspace',
    ),
    secrets: const ConnectionSecrets(password: 'secret'),
  );
  final repository = MemoryCodexConnectionRepository.single(
    connectionId: 'conn_primary',
    savedProfile: savedProfile,
  );
  final binding = ConnectionLaneBinding(
    connectionId: 'conn_primary',
    profileStore: ConnectionScopedProfileStore(
      connectionId: 'conn_primary',
      connectionRepository: repository,
    ),
    appServerClient: client,
    initialSavedProfile: savedProfile,
    ownsAppServerClient: false,
  );
  addTearDown(() async {
    binding.dispose();
    await client.dispose();
  });
  return (binding: binding, client: client);
}
