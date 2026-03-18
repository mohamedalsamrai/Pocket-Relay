import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'codex_connection_repository.dart';
import 'codex_conversation_handoff_store.dart';
import 'shared_preferences_async_migration.dart';

abstract interface class CodexConnectionHandoffStore {
  Future<SavedConversationHandoff> load(String connectionId);

  Future<void> save(String connectionId, SavedConversationHandoff handoff);

  Future<void> delete(String connectionId);
}

class SecureCodexConnectionHandoffStore implements CodexConnectionHandoffStore {
  static const _handoffKeyPrefix = 'pocket_relay.connection.';
  static const _handoffKeySuffix = '.conversation_handoff';
  static const _preferencesMigrationKey =
      'pocket_relay.connection_handoffs_async_migration_complete';
  static const _legacyMigrationCompleteKey =
      'pocket_relay.connection_handoffs_legacy_migration_complete';

  SecureCodexConnectionHandoffStore({
    required this.connectionRepository,
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  final CodexConnectionRepository connectionRepository;
  SharedPreferencesAsync? _preferences;
  final MemoryCodexConnectionHandoffStore _fallbackStore =
      MemoryCodexConnectionHandoffStore();
  Future<void>? _preferencesReady;

  @override
  Future<SavedConversationHandoff> load(String connectionId) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      return _fallbackStore.load(normalizedConnectionId);
    }

    await _ensurePreferencesReady();
    await _ensureLegacyMigrationIfNeeded(
      preferredConnectionId: normalizedConnectionId,
    );

    final rawHandoff = await preferences.getString(
      _handoffKeyForConnection(normalizedConnectionId),
    );
    if (rawHandoff == null || rawHandoff.trim().isEmpty) {
      return const SavedConversationHandoff();
    }

    return SavedConversationHandoff.fromJson(
      jsonDecode(rawHandoff) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(
    String connectionId,
    SavedConversationHandoff handoff,
  ) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      await _fallbackStore.save(normalizedConnectionId, handoff);
      return;
    }

    await _ensurePreferencesReady();
    final normalizedThreadId = handoff.normalizedResumeThreadId;
    final key = _handoffKeyForConnection(normalizedConnectionId);
    if (normalizedThreadId == null) {
      await preferences.remove(key);
      return;
    }

    await preferences.setString(key, jsonEncode(handoff.toJson()));
  }

  @override
  Future<void> delete(String connectionId) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      await _fallbackStore.delete(normalizedConnectionId);
      return;
    }

    await _ensurePreferencesReady();
    await preferences.remove(_handoffKeyForConnection(normalizedConnectionId));
  }

  Future<void> _ensurePreferencesReady() {
    if (_resolvedPreferences == null) {
      return Future<void>.value();
    }
    return _preferencesReady ??= ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: _preferencesMigrationKey,
    );
  }

  Future<void> _ensureLegacyMigrationIfNeeded({
    required String preferredConnectionId,
  }) async {
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      return;
    }

    final didMigrate =
        await preferences.getBool(_legacyMigrationCompleteKey) ?? false;
    if (didMigrate) {
      return;
    }

    final keyedConnectionIds = await _discoverKeyedConnectionIds(preferences);
    if (keyedConnectionIds.isNotEmpty) {
      await preferences.setBool(_legacyMigrationCompleteKey, true);
      return;
    }

    final legacyStore = SecureCodexConversationHandoffStore(
      preferences: preferences,
    );
    final legacyHandoff = await legacyStore.load();
    if (legacyHandoff.normalizedResumeThreadId == null) {
      await preferences.setBool(_legacyMigrationCompleteKey, true);
      return;
    }

    final catalog = await connectionRepository.loadCatalog();
    if (catalog.isEmpty) {
      await preferences.setBool(_legacyMigrationCompleteKey, true);
      return;
    }

    final targetConnectionId =
        catalog.connectionForId(preferredConnectionId) != null
        ? preferredConnectionId
        : catalog.orderedConnectionIds.first;
    await save(targetConnectionId, legacyHandoff);
    await preferences.setBool(_legacyMigrationCompleteKey, true);
  }

  Future<List<String>> _discoverKeyedConnectionIds(
    SharedPreferencesAsync preferences,
  ) async {
    final keys = await preferences.getKeys();
    final connectionIds = <String>[];

    for (final key in keys) {
      if (!key.startsWith(_handoffKeyPrefix) ||
          !key.endsWith(_handoffKeySuffix)) {
        continue;
      }

      final connectionId = key.substring(
        _handoffKeyPrefix.length,
        key.length - _handoffKeySuffix.length,
      );
      final normalizedConnectionId = connectionId.trim();
      if (normalizedConnectionId.isEmpty ||
          connectionIds.contains(normalizedConnectionId)) {
        continue;
      }
      connectionIds.add(normalizedConnectionId);
    }

    connectionIds.sort();
    return connectionIds;
  }

  SharedPreferencesAsync? get _resolvedPreferences {
    return _preferences ??= _tryCreatePreferences();
  }

  SharedPreferencesAsync? _tryCreatePreferences() {
    try {
      return SharedPreferencesAsync();
    } on StateError {
      return null;
    }
  }

  String _normalizeConnectionId(String connectionId) {
    final normalizedConnectionId = connectionId.trim();
    if (normalizedConnectionId.isEmpty) {
      throw ArgumentError.value(
        connectionId,
        'connectionId',
        'Connection id must not be empty.',
      );
    }
    return normalizedConnectionId;
  }

  String _handoffKeyForConnection(String connectionId) {
    return '$_handoffKeyPrefix$connectionId$_handoffKeySuffix';
  }
}

class MemoryCodexConnectionHandoffStore implements CodexConnectionHandoffStore {
  MemoryCodexConnectionHandoffStore({
    Map<String, SavedConversationHandoff>? initialValues,
  }) : _handoffsByConnectionId = initialValues == null
           ? <String, SavedConversationHandoff>{}
           : Map<String, SavedConversationHandoff>.from(initialValues);

  final Map<String, SavedConversationHandoff> _handoffsByConnectionId;

  @override
  Future<SavedConversationHandoff> load(String connectionId) async {
    return _handoffsByConnectionId[connectionId] ??
        const SavedConversationHandoff();
  }

  @override
  Future<void> save(
    String connectionId,
    SavedConversationHandoff handoff,
  ) async {
    if (handoff.normalizedResumeThreadId == null) {
      _handoffsByConnectionId.remove(connectionId);
      return;
    }
    _handoffsByConnectionId[connectionId] = handoff;
  }

  @override
  Future<void> delete(String connectionId) async {
    _handoffsByConnectionId.remove(connectionId);
  }
}
