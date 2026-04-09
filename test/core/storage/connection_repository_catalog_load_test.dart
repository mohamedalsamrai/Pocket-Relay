import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/connection_repository_test_support.dart';

void main() {
  registerConnectionRepositoryStorageLifecycle();

  test(
    'loadCatalog seeds a default saved connection when storage is empty',
    () async {
      final secureStorage = FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        catalog.connectionsById['conn_seed'],
        SavedConnectionSummary(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
        ),
      );
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['conn_seed'],
        }),
      );
      expect(
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            ConnectionProfile.defaults(),
            systemId: null,
          ).toJson(),
        ),
      );
      expect(
        await preferences.getString(systemIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': const <String>[],
        }),
      );
      expect(secureStorage.data, isEmpty);
    },
  );

  test(
    'loadCatalog ignores legacy singleton profile data once the migration window is closed',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'codex_pocket.profile': jsonEncode(
          ConnectionProfile.defaults()
              .copyWith(
                host: 'example.com',
                username: 'vince',
                workspaceDir: '/workspace/app',
              )
              .toJson(),
        ),
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'codex_pocket.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            ConnectionProfile.defaults(),
            systemId: null,
          ).toJson(),
        ),
      );
      expect(secureStorage.data[systemPasswordKey('conn_seed')], isNull);
      expect(secureStorage.data['codex_pocket.secret.password'], 'secret');
      expect(
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['conn_seed'],
        }),
      );
    },
  );

  test(
    'loadCatalog migrates the legacy singleton pocket relay profile into the seeded connection',
    () async {
      final legacyProfile = ConnectionProfile.defaults().copyWith(
        host: 'relay.example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
        hostFingerprint: 'SHA256:legacyfingerprint',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': jsonEncode(legacyProfile.toJson()),
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');
      final systemCatalog = await repository.loadSystemCatalog();
      final systemId = systemCatalog.orderedSystemIds.single;

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: legacyProfile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      expect(
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            legacyProfile,
            systemId: systemId,
          ).toJson(),
        ),
      );
      expect(
        await preferences.getString(systemProfileKey(systemId)),
        jsonEncode(systemProfileFromConnectionProfile(legacyProfile).toJson()),
      );
      expect(secureStorage.data[systemPasswordKey(systemId)], 'secret');
      expect(await preferences.getString('pocket_relay.profile'), isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], isNull);
    },
  );

  test(
    'loadCatalog upgrades a seeded default catalog entry with legacy singleton data',
    () async {
      final legacyProfile = ConnectionProfile.defaults().copyWith(
        host: 'relay.example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
        hostFingerprint: 'SHA256:legacyfingerprint',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': jsonEncode(legacyProfile.toJson()),
        'pocket_relay.connections.index': jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedConnectionIds': <String>['conn_seed'],
        }),
        'pocket_relay.connection.conn_seed.profile': jsonEncode(
          ConnectionProfile.defaults().toJson(),
        ),
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');
      final systemCatalog = await repository.loadSystemCatalog();
      final systemId = systemCatalog.orderedSystemIds.single;

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: legacyProfile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      expect(
        await preferences.getString(workspaceProfileKey('conn_seed')),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            legacyProfile,
            systemId: systemId,
          ).toJson(),
        ),
      );
      expect(
        await preferences.getString(systemProfileKey(systemId)),
        jsonEncode(systemProfileFromConnectionProfile(legacyProfile).toJson()),
      );
      expect(secureStorage.data[systemPasswordKey(systemId)], 'secret');
      expect(await preferences.getString('pocket_relay.profile'), isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], isNull);
    },
  );

  test(
    'loadCatalog migrates the legacy singleton profile even when legacy secrets are missing',
    () async {
      final legacyProfile = ConnectionProfile.defaults().copyWith(
        host: 'relay.example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': jsonEncode(legacyProfile.toJson()),
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: legacyProfile,
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(await preferences.getString('pocket_relay.profile'), isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], isNull);
    },
  );

  test(
    'loadSystemCatalog keeps a missing stored system label implicit while still deriving the legacy ssh identity for display',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        systemIndexKey(),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['system_seed'],
        }),
      );
      await preferences.setString(
        systemProfileKey('system_seed'),
        jsonEncode(<String, Object?>{
          'host': 'relay.example.com',
          'port': 2200,
          'username': 'vince',
          'authMode': AuthMode.password.name,
          'hostFingerprint': 'SHA256:shared',
        }),
      );
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final systemCatalog = await repository.loadSystemCatalog();
      final system = await repository.loadSystem('system_seed');

      expect(systemCatalog.orderedSystemIds, <String>['system_seed']);
      expect(systemCatalog.orderedSystems.single.profile.label, isEmpty);
      expect(
        systemCatalog.orderedSystems.single.profile.hasCustomLabel,
        isFalse,
      );
      expect(system.profile.label, isEmpty);
      expect(system.profile.displayLabel, 'vince@relay.example.com:2200');
      expect(system.profile.hasCustomLabel, isFalse);
    },
  );

  test(
    'loadWorkspaceCatalog ignores malformed persisted workspace profiles and rewrites the ordered index',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        workspaceIndexKey(),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['workspace_good', 'workspace_bad'],
        }),
      );
      await preferences.setString(
        workspaceProfileKey('workspace_good'),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            ConnectionProfile.defaults().copyWith(
              label: 'Good workspace',
              workspaceDir: '/workspace/good',
            ),
            systemId: null,
          ).toJson(),
        ),
      );
      await preferences.setString(
        workspaceProfileKey('workspace_bad'),
        '{not json',
      );
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final workspaceCatalog = await repository.loadWorkspaceCatalog();

      expect(workspaceCatalog.orderedWorkspaceIds, <String>['workspace_good']);
      expect(
        workspaceCatalog.workspaceForId('workspace_good')?.profile.workspaceDir,
        '/workspace/good',
      );
      expect(workspaceCatalog.workspaceForId('workspace_bad'), isNull);
      expect(
        await preferences.getString(workspaceProfileKey('workspace_bad')),
        isNull,
      );
      expect(
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['workspace_good'],
        }),
      );
    },
  );

  test(
    'loadWorkspaceCatalog drops malformed discovered workspace profiles from the rewritten index',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        workspaceIndexKey(),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['workspace_good'],
        }),
      );
      await preferences.setString(
        workspaceProfileKey('workspace_good'),
        jsonEncode(
          workspaceProfileFromConnectionProfile(
            ConnectionProfile.defaults().copyWith(
              label: 'Good workspace',
              workspaceDir: '/workspace/good',
            ),
            systemId: null,
          ).toJson(),
        ),
      );
      await preferences.setString(
        workspaceProfileKey('workspace_bad'),
        '{not json',
      );
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final firstLoad = await repository.loadWorkspaceCatalog();
      final secondLoad = await repository.loadWorkspaceCatalog();

      expect(firstLoad.orderedWorkspaceIds, <String>['workspace_good']);
      expect(secondLoad.orderedWorkspaceIds, <String>['workspace_good']);
      expect(
        await preferences.getString(workspaceProfileKey('workspace_bad')),
        isNull,
      );
      expect(
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['workspace_good'],
        }),
      );
    },
  );

  test(
    'loadSystemCatalog ignores malformed persisted system profiles and rewrites the ordered index',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        systemPasswordKey('system_bad'): 'stale-secret',
      });
      await preferences.setString(
        systemIndexKey(),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['system_good', 'system_bad'],
        }),
      );
      await preferences.setString(
        systemProfileKey('system_good'),
        jsonEncode(
          systemProfileFromConnectionProfile(
            ConnectionProfile.defaults().copyWith(
              host: 'relay.example.com',
              username: 'vince',
              label: 'Relay',
            ),
          ).toJson(),
        ),
      );
      await preferences.setString(systemProfileKey('system_bad'), '{not json');
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final systemCatalog = await repository.loadSystemCatalog();

      expect(systemCatalog.orderedSystemIds, <String>['system_good']);
      expect(
        systemCatalog.systemForId('system_good')?.profile.host,
        'relay.example.com',
      );
      expect(systemCatalog.systemForId('system_bad'), isNull);
      expect(
        await preferences.getString(systemProfileKey('system_bad')),
        isNull,
      );
      expect(secureStorage.data[systemPasswordKey('system_bad')], isNull);
      expect(
        await preferences.getString(systemIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['system_good'],
        }),
      );
    },
  );

  test(
    'loadSystemCatalog drops malformed discovered system profiles from the rewritten index',
    () async {
      final preferences = SharedPreferencesAsync();
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        systemPasswordKey('system_bad'): 'stale-secret',
      });
      await preferences.setString(
        systemIndexKey(),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['system_good'],
        }),
      );
      await preferences.setString(
        systemProfileKey('system_good'),
        jsonEncode(
          systemProfileFromConnectionProfile(
            ConnectionProfile.defaults().copyWith(
              host: 'relay.example.com',
              username: 'vince',
              label: 'Relay',
            ),
          ).toJson(),
        ),
      );
      await preferences.setString(systemProfileKey('system_bad'), '{not json');
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final firstLoad = await repository.loadSystemCatalog();
      final secondLoad = await repository.loadSystemCatalog();

      expect(firstLoad.orderedSystemIds, <String>['system_good']);
      expect(secondLoad.orderedSystemIds, <String>['system_good']);
      expect(
        await preferences.getString(systemProfileKey('system_bad')),
        isNull,
      );
      expect(secureStorage.data[systemPasswordKey('system_bad')], isNull);
      expect(
        await preferences.getString(systemIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['system_good'],
        }),
      );
    },
  );

  test(
    'loadCatalog ignores orphaned legacy secrets when the legacy profile is missing',
    () async {
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(secureStorage.data[systemPasswordKey('conn_seed')], isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], 'secret');
    },
  );

  test(
    'loadCatalog ignores malformed legacy singleton data instead of migrating it',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': '{not json',
      });
      final secureStorage = FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final connection = await repository.loadConnection('conn_seed');

      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(secureStorage.data[systemPasswordKey('conn_seed')], isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], 'secret');
      expect(await preferences.getString('pocket_relay.profile'), '{not json');
    },
  );

  test(
    'loadCatalog ignores legacy singleton secret read failures instead of aborting startup',
    () async {
      final legacyProfile = ConnectionProfile.defaults().copyWith(
        host: 'relay.example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.profile': jsonEncode(legacyProfile.toJson()),
      });
      final secureStorage = _ThrowingReadFakeFlutterSecureStorage(
        <String, String>{'pocket_relay.secret.password': 'secret'},
        keyToThrowOn: 'pocket_relay.secret.password',
      );
      final preferences = SharedPreferencesAsync();
      final repository = buildSecureConnectionRepository(
        secureStorage: secureStorage,
        preferences: preferences,
        connectionIdGenerator: () => 'conn_seed',
      );

      final catalog = await repository.loadCatalog();
      final connection = await repository.loadConnection('conn_seed');

      expect(catalog.orderedConnectionIds, <String>['conn_seed']);
      expect(
        connection,
        SavedConnection(
          id: 'conn_seed',
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      );
      expect(
        await preferences.getString('pocket_relay.profile'),
        jsonEncode(legacyProfile.toJson()),
      );
      expect(secureStorage.data['pocket_relay.secret.password'], 'secret');
    },
  );

  test(
    'loadCatalog rebuilds the index from namespaced profile keys when the index is missing',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.connection.conn_b.profile',
        jsonEncode(
          ConnectionProfile.defaults()
              .copyWith(
                label: 'Beta',
                host: 'beta.example.com',
                username: 'vince',
              )
              .toJson(),
        ),
      );
      await preferences.setString(
        'pocket_relay.connection.conn_a.profile',
        jsonEncode(
          ConnectionProfile.defaults()
              .copyWith(
                label: 'Alpha',
                host: 'alpha.example.com',
                username: 'vince',
              )
              .toJson(),
        ),
      );
      final repository = buildSecureConnectionRepository(
        secureStorage: FakeFlutterSecureStorage(<String, String>{}),
        preferences: preferences,
        connectionIdGenerator: () => 'conn_unused',
      );

      final catalog = await repository.loadCatalog();

      expect(catalog.orderedConnectionIds, <String>['conn_a', 'conn_b']);
      expect(
        await preferences.getString(workspaceIndexKey()),
        jsonEncode(<String, Object?>{
          'schemaVersion': 1,
          'orderedIds': <String>['conn_a', 'conn_b'],
        }),
      );
    },
  );
}

final class _ThrowingReadFakeFlutterSecureStorage
    extends FakeFlutterSecureStorage {
  _ThrowingReadFakeFlutterSecureStorage(
    super.data, {
    required this.keyToThrowOn,
  });

  final String keyToThrowOn;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == keyToThrowOn) {
      throw StateError('secure storage read failed');
    }
    return super.read(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}
