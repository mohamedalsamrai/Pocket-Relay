import 'dart:convert';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_async_migration.dart';

abstract class CodexProfileStore {
  Future<SavedProfile> load();

  Future<void> save(ConnectionProfile profile, ConnectionSecrets secrets);
}

class SecureCodexProfileStore implements CodexProfileStore {
  static const _profileKey = 'pocket_relay.profile';
  static const _preferencesMigrationKey =
      'pocket_relay.preferences_async_migration_complete';
  static const _passwordKey = 'pocket_relay.secret.password';
  static const _privateKeyKey = 'pocket_relay.secret.private_key';
  static const _privateKeyPassphraseKey =
      'pocket_relay.secret.private_key_passphrase';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesAsync _preferences;
  Future<void>? _preferencesReady;

  SecureCodexProfileStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<SavedProfile> load() async {
    await _ensurePreferencesReady();
    final rawProfile = await _preferences.getString(_profileKey);
    final profile = rawProfile == null
        ? ConnectionProfile.defaults()
        : ConnectionProfile.fromJson(
            jsonDecode(rawProfile) as Map<String, dynamic>,
          );

    final password = await _readSecret(_passwordKey);
    final privateKeyPem = await _readSecret(_privateKeyKey);
    final privateKeyPassphrase = await _readSecret(_privateKeyPassphraseKey);

    return SavedProfile(
      profile: profile,
      secrets: ConnectionSecrets(
        password: password,
        privateKeyPem: privateKeyPem,
        privateKeyPassphrase: privateKeyPassphrase,
      ),
    );
  }

  @override
  Future<void> save(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) async {
    await _ensurePreferencesReady();
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));

    await _writeSecret(_passwordKey, secrets.password);
    await _writeSecret(_privateKeyKey, secrets.privateKeyPem);
    await _writeSecret(_privateKeyPassphraseKey, secrets.privateKeyPassphrase);
  }

  Future<void> _writeSecret(String key, String value) async {
    if (value.trim().isEmpty) {
      await _secureStorage.delete(key: key);
      return;
    }

    await _secureStorage.write(key: key, value: value);
  }

  Future<String> _readSecret(String key) async {
    return await _secureStorage.read(key: key) ?? '';
  }

  Future<void> _ensurePreferencesReady() {
    return _preferencesReady ??= _migrateLegacyPreferencesIfNeeded();
  }

  Future<void> _migrateLegacyPreferencesIfNeeded() async {
    await ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: _preferencesMigrationKey,
    );
  }
}

class MemoryCodexProfileStore implements CodexProfileStore {
  MemoryCodexProfileStore({SavedProfile? initialValue})
    : _savedProfile =
          initialValue ??
          SavedProfile(
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          );

  SavedProfile _savedProfile;

  @override
  Future<SavedProfile> load() async => _savedProfile;

  @override
  Future<void> save(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) async {
    _savedProfile = _savedProfile.copyWith(profile: profile, secrets: secrets);
  }
}
