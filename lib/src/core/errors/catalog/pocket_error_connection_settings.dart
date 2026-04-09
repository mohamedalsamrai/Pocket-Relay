import 'package:pocket_relay/src/core/errors/pocket_error_base.dart';

abstract final class ConnectionSettingsPocketErrorCatalog {
  static const PocketErrorDefinition
  modelCatalogUnavailable = PocketErrorDefinition(
    code: 'PR-CONNSET-1101',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet did not produce a backend model catalog.',
  );
  static const PocketErrorDefinition
  modelCatalogRefreshFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1102',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet failed because the backend refresh call threw an error.',
  );
  static const PocketErrorDefinition
  modelCatalogConnectionCacheSaveFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1103',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet succeeded, but Pocket Relay could not save the connection-scoped cached model catalog.',
  );
  static const PocketErrorDefinition
  modelCatalogLastKnownCacheSaveFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1104',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet succeeded, but Pocket Relay could not save the shared last-known cached model catalog.',
  );
  static const PocketErrorDefinition
  modelCatalogCachePersistenceFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1105',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet succeeded, but Pocket Relay could not save either local model catalog cache.',
  );

  static const PocketErrorDefinition
  remoteRuntimeProbeFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1201',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Probing the remote target from the connection settings sheet failed before Pocket Relay could determine continuity support.',
  );

  static const List<PocketErrorDefinition> definitions =
      <PocketErrorDefinition>[
        modelCatalogUnavailable,
        modelCatalogRefreshFailed,
        modelCatalogConnectionCacheSaveFailed,
        modelCatalogLastKnownCacheSaveFailed,
        modelCatalogCachePersistenceFailed,
        remoteRuntimeProbeFailed,
      ];
}
