import 'package:pocket_relay/src/core/errors/pocket_error_base.dart';

abstract final class AppBootstrapPocketErrorCatalog {
  static const PocketErrorDefinition
  workspaceInitializationFailed = PocketErrorDefinition(
    code: 'PR-BOOT-1101',
    domain: PocketErrorDomain.appBootstrap,
    meaning:
        'Pocket Relay failed to initialize the workspace shell during app bootstrap.',
  );
  static const PocketErrorDefinition
  recoveryStateLoadFailed = PocketErrorDefinition(
    code: 'PR-BOOT-1102',
    domain: PocketErrorDomain.appBootstrap,
    meaning:
        'Pocket Relay could not restore the previously persisted local workspace recovery state during app bootstrap, so startup continued without that recovery snapshot.',
  );

  static const List<PocketErrorDefinition> definitions =
      <PocketErrorDefinition>[
        workspaceInitializationFailed,
        recoveryStateLoadFailed,
      ];
}
