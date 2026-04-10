import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../codex_connection_catalog_recovery.dart';
import '../repository/connection_repository_contract.dart';
import 'secure_connection_repository_keys.dart';

typedef DeferredLegacyCatalogSnapshot = ({
  WorkspaceCatalogState workspaceCatalog,
  SystemCatalogState systemCatalog,
  Map<String, SavedWorkspace> workspacesById,
  Map<String, SavedSystem> systemsById,
  Map<String, SavedConnection> connectionsById,
});

final class SecureConnectionRepositoryState {
  SecureConnectionRepositoryState({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
    ConnectionIdGenerator? connectionIdGenerator,
    SystemIdGenerator? systemIdGenerator,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage(),
       preferences = preferences ?? SharedPreferencesAsync(),
       workspaceIdGenerator = connectionIdGenerator ?? generateConnectionId,
       systemIdGenerator = systemIdGenerator ?? generateSystemId;

  final FlutterSecureStorage secureStorage;
  final SharedPreferencesAsync preferences;
  final ConnectionIdGenerator workspaceIdGenerator;
  final SystemIdGenerator systemIdGenerator;
  late final CodexConnectionCatalogRecovery catalogRecovery =
      CodexConnectionCatalogRecovery(
        preferences: preferences,
        catalogIndexKey: legacyCatalogIndexKey,
        catalogSchemaVersion: legacyCatalogSchemaVersion,
        preferencesMigrationKey: catalogPreferencesMigrationKey,
        profileKeyPrefix: legacyProfileKeyPrefix,
        profileKeySuffix: legacyProfileKeySuffix,
      );
  Future<void>? normalizedCatalogsReady;
  DeferredLegacyCatalogSnapshot? deferredLegacyCatalogSnapshot;
}
