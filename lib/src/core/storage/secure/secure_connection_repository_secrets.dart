import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/persisted_json.dart';

import 'secure_connection_repository_keys.dart';
import 'secure_connection_repository_state.dart';

Future<void> persistSystemSecrets(
  SecureConnectionRepositoryState state,
  SavedSystem system,
) async {
  await writeSecret(
    state.secureStorage,
    systemPasswordKeyForSystem(system.id),
    system.secrets.password,
  );
  await writeSecret(
    state.secureStorage,
    systemPrivateKeyKeyForSystem(system.id),
    system.secrets.privateKeyPem,
  );
  await writeSecret(
    state.secureStorage,
    systemPrivateKeyPassphraseKeyForSystem(system.id),
    system.secrets.privateKeyPassphrase,
  );
}

Future<ConnectionSecrets> readSystemSecrets(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  return ConnectionSecrets(
    password: await readSecret(
      state.secureStorage,
      systemPasswordKeyForSystem(systemId),
    ),
    privateKeyPem: await readSecret(
      state.secureStorage,
      systemPrivateKeyKeyForSystem(systemId),
    ),
    privateKeyPassphrase: await readSecret(
      state.secureStorage,
      systemPrivateKeyPassphraseKeyForSystem(systemId),
    ),
  );
}

Future<void> deleteSystemSecrets(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  await state.secureStorage.delete(key: systemPasswordKeyForSystem(systemId));
  await state.secureStorage.delete(key: systemPrivateKeyKeyForSystem(systemId));
  await state.secureStorage.delete(
    key: systemPrivateKeyPassphraseKeyForSystem(systemId),
  );
}

Future<ConnectionSecrets> readLegacyConnectionSecrets(
  SecureConnectionRepositoryState state,
  String connectionId,
) async {
  return ConnectionSecrets(
    password: await readSecret(
      state.secureStorage,
      passwordKeyForConnection(connectionId),
    ),
    privateKeyPem: await readSecret(
      state.secureStorage,
      privateKeyKeyForConnection(connectionId),
    ),
    privateKeyPassphrase: await readSecret(
      state.secureStorage,
      privateKeyPassphraseKeyForConnection(connectionId),
    ),
  );
}

Future<SavedConnection?> readLegacySingletonConnection(
  SecureConnectionRepositoryState state,
) async {
  final rawProfile = await state.preferences.getString(
    legacySingletonProfileKey,
  );
  if (rawProfile == null || rawProfile.trim().isEmpty) {
    return null;
  }

  final decodedProfile = decodePersistedJsonRecord<ConnectionProfile>(
    rawProfile,
    subject: 'legacy singleton connection profile',
    decode: (json) => ConnectionProfile.fromJson(json),
  );
  if (decodedProfile.issue != null) {
    return null;
  }
  return SavedConnection(
    id: '',
    profile: decodedProfile.value!,
    secrets: ConnectionSecrets(
      password: await _readSecretOrEmptyOnFailure(
        state.secureStorage,
        legacySingletonPasswordKey,
      ),
      privateKeyPem: await _readSecretOrEmptyOnFailure(
        state.secureStorage,
        legacySingletonPrivateKeyKey,
      ),
      privateKeyPassphrase: await _readSecretOrEmptyOnFailure(
        state.secureStorage,
        legacySingletonPrivateKeyPassphraseKey,
      ),
    ),
  );
}

Future<void> deleteLegacyConnections(
  SecureConnectionRepositoryState state,
  List<String> connectionIds,
) async {
  for (final connectionId in connectionIds) {
    await deleteLegacyConnectionNamespace(state, connectionId);
  }
  await state.preferences.remove(legacyCatalogIndexKey);
}

Future<void> deleteLegacyConnectionNamespace(
  SecureConnectionRepositoryState state,
  String connectionId,
) async {
  await state.preferences.remove(profileKeyForConnection(connectionId));
  final legacyKeyPrefix = '$legacySecretKeyPrefix$connectionId.';
  final allSecureKeys = await state.secureStorage.readAll();
  for (final key in allSecureKeys.keys) {
    if (key.startsWith(legacyKeyPrefix)) {
      await state.secureStorage.delete(key: key);
    }
  }
}

Future<void> deleteLegacySingletonStorage(
  SecureConnectionRepositoryState state,
) async {
  await state.preferences.remove(legacySingletonProfileKey);
  await state.secureStorage.delete(key: legacySingletonPasswordKey);
  await state.secureStorage.delete(key: legacySingletonPrivateKeyKey);
  await state.secureStorage.delete(key: legacySingletonPrivateKeyPassphraseKey);
}

Future<void> writeSecret(
  FlutterSecureStorage secureStorage,
  String key,
  String value,
) async {
  if (value.trim().isEmpty) {
    await secureStorage.delete(key: key);
    return;
  }
  await secureStorage.write(key: key, value: value);
}

Future<String> readSecret(
  FlutterSecureStorage secureStorage,
  String key,
) async {
  return await secureStorage.read(key: key) ?? '';
}

Future<String> _readSecretOrEmptyOnFailure(
  FlutterSecureStorage secureStorage,
  String key,
) async {
  try {
    return await readSecret(secureStorage, key);
  } catch (_) {
    return '';
  }
}
