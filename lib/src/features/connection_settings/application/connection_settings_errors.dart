import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class ConnectionSettingsErrors {
  static PocketUserFacingError modelCatalogUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionSettingsModelCatalogUnavailable,
      title: 'Model refresh failed',
      message: 'Could not load models from the backend.',
    );
  }

  static PocketUserFacingError modelCatalogRefreshFailed({Object? error}) {
    return PocketUserFacingError(
      definition:
          PocketErrorCatalog.connectionSettingsModelCatalogRefreshFailed,
      title: 'Model refresh failed',
      message: 'Could not load models from the backend.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError remoteRuntimeProbeFailed({Object? error}) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionSettingsRemoteRuntimeProbeFailed,
      title: 'Host check failed',
      message: 'Could not verify the remote target.',
    ).withNormalizedUnderlyingError(error);
  }
}
