import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsyncPlatform? originalAsyncPlatform;

  setUp(() {
    originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'load migrates the legacy singleton handoff into the selected connection id',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'codex_pocket.conversation_handoff': jsonEncode(<String, Object?>{
          'resumeThreadId': 'thread_legacy',
        }),
      });

      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: ConnectionProfile.defaults().copyWith(label: 'Secondary'),
            secrets: const ConnectionSecrets(),
          ),
        ],
      );
      final preferences = SharedPreferencesAsync();
      final store = SecureCodexConnectionHandoffStore(
        connectionRepository: repository,
        preferences: preferences,
      );

      final handoff = await store.load('conn_secondary');

      expect(
        handoff,
        const SavedConversationHandoff(resumeThreadId: 'thread_legacy'),
      );
      expect(
        await preferences.getString(
          'pocket_relay.connection.conn_secondary.conversation_handoff',
        ),
        jsonEncode(<String, Object?>{'resumeThreadId': 'thread_legacy'}),
      );
      expect(
        await preferences.getString(
          'pocket_relay.connection.conn_primary.conversation_handoff',
        ),
        isNull,
      );
    },
  );

  test(
    'load does not remigrate the legacy singleton handoff once keyed handoffs exist',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'codex_pocket.conversation_handoff': jsonEncode(<String, Object?>{
          'resumeThreadId': 'thread_legacy',
        }),
      });

      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          ),
        ],
      );
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.connection.conn_primary.conversation_handoff',
        jsonEncode(<String, Object?>{'resumeThreadId': 'thread_keyed'}),
      );
      final store = SecureCodexConnectionHandoffStore(
        connectionRepository: repository,
        preferences: preferences,
      );

      final handoff = await store.load('conn_primary');

      expect(
        handoff,
        const SavedConversationHandoff(resumeThreadId: 'thread_keyed'),
      );
    },
  );

  test('save and delete isolate handoffs by connection id', () async {
    final repository = MemoryCodexConnectionRepository(
      initialConnections: <SavedConnection>[
        SavedConnection(
          id: 'conn_a',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
        SavedConnection(
          id: 'conn_b',
          profile: ConnectionProfile.defaults().copyWith(label: 'B'),
          secrets: const ConnectionSecrets(),
        ),
      ],
    );
    final preferences = SharedPreferencesAsync();
    final store = SecureCodexConnectionHandoffStore(
      connectionRepository: repository,
      preferences: preferences,
    );

    await store.save(
      'conn_a',
      const SavedConversationHandoff(resumeThreadId: 'thread_a'),
    );
    await store.save(
      'conn_b',
      const SavedConversationHandoff(resumeThreadId: 'thread_b'),
    );
    await store.delete('conn_a');

    expect(await store.load('conn_a'), const SavedConversationHandoff());
    expect(
      await store.load('conn_b'),
      const SavedConversationHandoff(resumeThreadId: 'thread_b'),
    );
  });
}
