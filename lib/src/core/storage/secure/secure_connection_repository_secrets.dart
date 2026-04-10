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
  await persistSystemSecretValues(state, system.id, system.secrets);
}

Future<void> persistSystemSecretValues(
  SecureConnectionRepositoryState state,
  String systemId,
  ConnectionSecrets secrets,
) async {
  await writeSecret(
    state.secureStorage,
    systemPasswordKeyForSystem(systemId),
    secrets.password,
  );
  await writeSecret(
    state.secureStorage,
    systemPrivateKeyKeyForSystem(systemId),
    secrets.privateKeyPem,
  );
  await writeSecret(
    state.secureStorage,
    systemPrivateKeyPassphraseKeyForSystem(systemId),
    secrets.privateKeyPassphrase,
  );
}

Future<ConnectionSecrets> readSystemSecrets(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  final persistedSecrets = await _readPersistedSystemSecrets(state, systemId);
  final fallbackSource = await loadSystemLegacySecretFallback(state, systemId);
  if (fallbackSource == null) {
    return persistedSecrets;
  }

  final fallbackResult = await _readLegacySystemSecretFallbackWithStatus(
    state,
    fallbackSource,
  );
  final mergedSecrets = _mergeConnectionSecrets(
    persistedSecrets,
    fallbackResult.secrets,
  );
  if (fallbackResult.allowCleanup) {
    await persistSystemSecretValues(state, systemId, mergedSecrets);
    await clearSystemLegacySecretFallback(state, systemId);
  }
  return mergedSecrets;
}

Future<LegacySystemSecretFallbackSource?> loadSystemLegacySecretFallback(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  final fallbacks = await _loadSystemLegacySecretFallbacks(state);
  return fallbacks[systemId];
}

Future<void> persistSystemLegacySecretFallback(
  SecureConnectionRepositoryState state,
  String systemId,
  LegacySystemSecretFallbackSource source,
) async {
  final fallbacks = await _loadSystemLegacySecretFallbacks(state);
  fallbacks[systemId] = source;
  await _persistSystemLegacySecretFallbacks(state, fallbacks);
}

Future<void> persistSystemLegacySecretFallbacks(
  SecureConnectionRepositoryState state,
  Map<String, LegacySystemSecretFallbackSource> fallbacksBySystemId,
) async {
  if (fallbacksBySystemId.isEmpty) {
    return;
  }
  final persistedFallbacks = await _loadSystemLegacySecretFallbacks(state);
  persistedFallbacks.addAll(fallbacksBySystemId);
  await _persistSystemLegacySecretFallbacks(state, persistedFallbacks);
}

Future<void> clearSystemLegacySecretFallback(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  final fallbacks = await _loadSystemLegacySecretFallbacks(state);
  if (fallbacks.remove(systemId) == null) {
    return;
  }
  await _persistSystemLegacySecretFallbacks(state, fallbacks);
}

Future<ConnectionSecrets> _readPersistedSystemSecrets(
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

Future<({ConnectionSecrets secrets, bool allowCleanup})>
_readLegacySystemSecretFallbackWithStatus(
  SecureConnectionRepositoryState state,
  LegacySystemSecretFallbackSource fallbackSource,
) async {
  return switch (fallbackSource.kind) {
    LegacySystemSecretFallbackSourceKind.connection =>
      readLegacyConnectionSecretsWithStatus(
        state,
        fallbackSource.connectionId!,
      ),
    LegacySystemSecretFallbackSourceKind.singleton => (() async {
      final result = await readLegacySingletonConnectionWithStatus(state);
      return (
        secrets: result.connection?.secrets ?? const ConnectionSecrets(),
        allowCleanup: result.allowCleanup,
      );
    })(),
  };
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

Future<({ConnectionSecrets secrets, bool allowCleanup})>
readLegacyConnectionSecretsWithStatus(
  SecureConnectionRepositoryState state,
  String connectionId,
) async {
  final passwordResult = await _readSecretOrEmptyOnFailure(
    state.secureStorage,
    passwordKeyForConnection(connectionId),
  );
  final privateKeyResult = await _readSecretOrEmptyOnFailure(
    state.secureStorage,
    privateKeyKeyForConnection(connectionId),
  );
  final passphraseResult = await _readSecretOrEmptyOnFailure(
    state.secureStorage,
    privateKeyPassphraseKeyForConnection(connectionId),
  );
  return (
    secrets: ConnectionSecrets(
      password: passwordResult.value,
      privateKeyPem: privateKeyResult.value,
      privateKeyPassphrase: passphraseResult.value,
    ),
    allowCleanup:
        !passwordResult.readFailed &&
        !privateKeyResult.readFailed &&
        !passphraseResult.readFailed,
  );
}

Future<SavedConnection?> readLegacySingletonConnection(
  SecureConnectionRepositoryState state,
) async {
  final result = await readLegacySingletonConnectionWithStatus(state);
  return result.connection;
}

Future<({SavedConnection? connection, bool allowCleanup})>
readLegacySingletonConnectionWithStatus(
  SecureConnectionRepositoryState state,
) async {
  final rawProfile = await state.preferences.getString(
    legacySingletonProfileKey,
  );
  if (rawProfile == null || rawProfile.trim().isEmpty) {
    return (connection: null, allowCleanup: false);
  }

  final decodedProfile = decodePersistedJsonRecord<ConnectionProfile>(
    rawProfile,
    subject: 'legacy singleton connection profile',
    decode: (json) => ConnectionProfile.fromJson(json),
  );
  if (decodedProfile.issue != null) {
    return (connection: null, allowCleanup: false);
  }
  final passwordResult = await _readSecretOrEmptyOnFailure(
    state.secureStorage,
    legacySingletonPasswordKey,
  );
  final privateKeyResult = await _readSecretOrEmptyOnFailure(
    state.secureStorage,
    legacySingletonPrivateKeyKey,
  );
  final passphraseResult = await _readSecretOrEmptyOnFailure(
    state.secureStorage,
    legacySingletonPrivateKeyPassphraseKey,
  );
  return (
    connection: SavedConnection(
      id: '',
      profile: decodedProfile.value!,
      secrets: ConnectionSecrets(
        password: passwordResult.value,
        privateKeyPem: privateKeyResult.value,
        privateKeyPassphrase: passphraseResult.value,
      ),
    ),
    allowCleanup:
        !passwordResult.readFailed &&
        !privateKeyResult.readFailed &&
        !passphraseResult.readFailed,
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

Future<Map<String, LegacySystemSecretFallbackSource>>
_loadSystemLegacySecretFallbacks(SecureConnectionRepositoryState state) async {
  final rawFallbacks = await state.preferences.getString(
    systemLegacySecretFallbacksKey,
  );
  final normalizedRawFallbacks = rawFallbacks?.trim();
  if (normalizedRawFallbacks == null || normalizedRawFallbacks.isEmpty) {
    return <String, LegacySystemSecretFallbackSource>{};
  }

  final decodedFallbacks = decodePersistedJsonObject(
    normalizedRawFallbacks,
    subject: 'system legacy secret fallback map',
  );
  if (decodedFallbacks.issue != null) {
    return <String, LegacySystemSecretFallbackSource>{};
  }

  final fallbacksBySystemId = <String, LegacySystemSecretFallbackSource>{};
  for (final entry in decodedFallbacks.value!.entries) {
    final systemId = entry.key.trim();
    if (systemId.isEmpty) {
      continue;
    }
    final source = _decodeLegacySystemSecretFallbackSource(entry.value);
    if (source == null) {
      continue;
    }
    fallbacksBySystemId[systemId] = source;
  }
  return fallbacksBySystemId;
}

Future<void> _persistSystemLegacySecretFallbacks(
  SecureConnectionRepositoryState state,
  Map<String, LegacySystemSecretFallbackSource> fallbacksBySystemId,
) async {
  if (fallbacksBySystemId.isEmpty) {
    await state.preferences.remove(systemLegacySecretFallbacksKey);
    return;
  }

  await state.preferences.setString(
    systemLegacySecretFallbacksKey,
    jsonEncode(<String, Object?>{
      for (final entry in fallbacksBySystemId.entries)
        entry.key: _legacySystemSecretFallbackSourceToJson(entry.value),
    }),
  );
}

Map<String, Object?> _legacySystemSecretFallbackSourceToJson(
  LegacySystemSecretFallbackSource source,
) {
  return <String, Object?>{
    'kind': source.kind.name,
    if (source.connectionId case final connectionId?)
      'connectionId': connectionId,
  };
}

LegacySystemSecretFallbackSource? _decodeLegacySystemSecretFallbackSource(
  Object? json,
) {
  if (json is! Map) {
    return null;
  }

  final rawKind = json['kind'];
  if (rawKind is! String) {
    return null;
  }

  final kind = _legacySystemSecretFallbackSourceKindFromName(rawKind);
  if (kind == null) {
    return null;
  }

  final normalizedConnectionId = switch (json['connectionId']) {
    final String value => value.trim(),
    _ => null,
  };
  return switch (kind) {
    LegacySystemSecretFallbackSourceKind.connection
        when normalizedConnectionId != null &&
            normalizedConnectionId.isNotEmpty =>
      (kind: kind, connectionId: normalizedConnectionId),
    LegacySystemSecretFallbackSourceKind.singleton => (
      kind: kind,
      connectionId: null,
    ),
    _ => null,
  };
}

ConnectionSecrets _mergeConnectionSecrets(
  ConnectionSecrets persisted,
  ConnectionSecrets fallback,
) {
  return ConnectionSecrets(
    password: _preferNonEmpty(persisted.password, fallback.password),
    privateKeyPem: _preferNonEmpty(
      persisted.privateKeyPem,
      fallback.privateKeyPem,
    ),
    privateKeyPassphrase: _preferNonEmpty(
      persisted.privateKeyPassphrase,
      fallback.privateKeyPassphrase,
    ),
  );
}

String _preferNonEmpty(String preferred, String fallback) {
  return preferred.trim().isNotEmpty ? preferred : fallback;
}

LegacySystemSecretFallbackSourceKind?
_legacySystemSecretFallbackSourceKindFromName(String name) {
  for (final kind in LegacySystemSecretFallbackSourceKind.values) {
    if (kind.name == name) {
      return kind;
    }
  }
  return null;
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

Future<({String value, bool readFailed})> _readSecretOrEmptyOnFailure(
  FlutterSecureStorage secureStorage,
  String key,
) async {
  try {
    return (value: await readSecret(secureStorage, key), readFailed: false);
  } catch (_) {
    return (value: '', readFailed: true);
  }
}
