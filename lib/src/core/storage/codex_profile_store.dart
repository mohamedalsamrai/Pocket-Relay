import 'dart:convert';

import 'package:codex_pocket/src/core/models/connection_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class CodexProfileStore {
  Future<SavedProfile> load();

  Future<void> save(ConnectionProfile profile, ConnectionSecrets secrets);
}

class SecureCodexProfileStore implements CodexProfileStore {
  static const _profileKey = 'codex_pocket.profile';
  static const _passwordKey = 'codex_pocket.secret.password';
  static const _privateKeyKey = 'codex_pocket.secret.private_key';
  static const _privateKeyPassphraseKey =
      'codex_pocket.secret.private_key_passphrase';

  final FlutterSecureStorage _secureStorage;

  SecureCodexProfileStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<SavedProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawProfile = prefs.getString(_profileKey);
    final profile = rawProfile == null
        ? ConnectionProfile.defaults()
        : ConnectionProfile.fromJson(
            jsonDecode(rawProfile) as Map<String, dynamic>,
          );

    final password = await _secureStorage.read(key: _passwordKey) ?? '';
    final privateKeyPem = await _secureStorage.read(key: _privateKeyKey) ?? '';
    final privateKeyPassphrase =
        await _secureStorage.read(key: _privateKeyPassphraseKey) ?? '';

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));

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
    _savedProfile = SavedProfile(profile: profile, secrets: secrets);
  }
}
