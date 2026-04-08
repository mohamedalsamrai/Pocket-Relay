import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';

import 'connection_settings_system_templates.dart';

abstract interface class ConnectionCapabilityAssets {
  Future<ConnectionModelCatalog?> loadConnectionModelCatalog(
    String connectionId,
  );

  Future<void> saveConnectionModelCatalog(ConnectionModelCatalog catalog);

  Future<void> deleteConnectionModelCatalog(String connectionId);

  Future<ConnectionModelCatalog?> loadLastKnownConnectionModelCatalog();

  Future<void> saveLastKnownConnectionModelCatalog(
    ConnectionModelCatalog catalog,
  );

  Future<List<ConnectionSettingsSystemTemplate>> loadReusableSystemTemplates();
}

final class NoopConnectionCapabilityAssets
    implements ConnectionCapabilityAssets {
  const NoopConnectionCapabilityAssets();

  @override
  Future<ConnectionModelCatalog?> loadConnectionModelCatalog(
    String connectionId,
  ) async => null;

  @override
  Future<void> saveConnectionModelCatalog(
    ConnectionModelCatalog catalog,
  ) async {}

  @override
  Future<void> deleteConnectionModelCatalog(String connectionId) async {}

  @override
  Future<ConnectionModelCatalog?> loadLastKnownConnectionModelCatalog() async =>
      null;

  @override
  Future<void> saveLastKnownConnectionModelCatalog(
    ConnectionModelCatalog catalog,
  ) async {}

  @override
  Future<List<ConnectionSettingsSystemTemplate>>
  loadReusableSystemTemplates() async {
    return const <ConnectionSettingsSystemTemplate>[];
  }
}

final class StoreBackedConnectionCapabilityAssets
    implements ConnectionCapabilityAssets {
  StoreBackedConnectionCapabilityAssets({
    required CodexConnectionRepository connectionRepository,
    ConnectionModelCatalogStore? modelCatalogStore,
  }) : _connectionRepository = connectionRepository,
       _modelCatalogStore =
           modelCatalogStore ?? const NoopConnectionModelCatalogStore();

  final CodexConnectionRepository _connectionRepository;
  final ConnectionModelCatalogStore _modelCatalogStore;

  @override
  Future<ConnectionModelCatalog?> loadConnectionModelCatalog(
    String connectionId,
  ) {
    return _modelCatalogStore.load(_normalizeConnectionId(connectionId));
  }

  @override
  Future<void> saveConnectionModelCatalog(ConnectionModelCatalog catalog) {
    return _modelCatalogStore.save(_normalizeCatalog(catalog));
  }

  @override
  Future<void> deleteConnectionModelCatalog(String connectionId) {
    return _modelCatalogStore.delete(_normalizeConnectionId(connectionId));
  }

  @override
  Future<ConnectionModelCatalog?> loadLastKnownConnectionModelCatalog() {
    return _modelCatalogStore.loadLastKnown();
  }

  @override
  Future<void> saveLastKnownConnectionModelCatalog(
    ConnectionModelCatalog catalog,
  ) {
    return _modelCatalogStore.saveLastKnown(_normalizeCatalog(catalog));
  }

  @override
  Future<List<ConnectionSettingsSystemTemplate>>
  loadReusableSystemTemplates() async {
    final catalog = await _connectionRepository.loadSystemCatalog();
    final systems = <SavedSystem>[];
    for (final systemId in catalog.orderedSystemIds) {
      try {
        systems.add(await _connectionRepository.loadSystem(systemId));
      } catch (error, stackTrace) {
        debugPrint(
          'Failed to load system $systemId for reusable system template: '
          '$error | $stackTrace',
        );
      }
    }

    return deriveConnectionSettingsSystemTemplatesFromSystems(systems);
  }
}

ConnectionModelCatalog _normalizeCatalog(ConnectionModelCatalog catalog) {
  return ConnectionModelCatalog(
    connectionId: _normalizeConnectionId(catalog.connectionId),
    fetchedAt: catalog.fetchedAt,
    models: catalog.models,
  );
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
