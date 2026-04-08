import 'package:pocket_relay/src/core/errors/pocket_error_base.dart';

abstract final class DeviceCapabilityPocketErrorCatalog {
  static const PocketErrorDefinition
  foregroundServicePermissionQueryFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1101',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not verify notification permission before trying to enable the Android foreground service used for active-turn continuity.',
  );
  static const PocketErrorDefinition
  foregroundServicePermissionRequestFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1102',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not request notification permission before trying to enable the Android foreground service used for active-turn continuity.',
  );
  static const PocketErrorDefinition
  foregroundServiceEnableFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1103',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not enable or disable the Android foreground service used for active-turn continuity.',
  );
  static const PocketErrorDefinition
  backgroundGraceEnableFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1104',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not enable or disable the finite background-grace host used to preserve an active turn while the app is backgrounded.',
  );
  static const PocketErrorDefinition
  wakeLockEnableFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1105',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not enable or disable the display wake lock used to preserve an active turn while the app remains in the foreground.',
  );
  static const PocketErrorDefinition
  turnCompletionAlertPermissionQueryFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1106',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not verify notification permission before trying to post a finished-turn completion alert.',
  );
  static const PocketErrorDefinition
  turnCompletionAlertPermissionRequestFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1107',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not request notification permission needed for finished-turn completion alerts.',
  );
  static const PocketErrorDefinition
  turnCompletionAlertNotificationUpdateFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1108',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not post, replace, or clear the finished-turn completion alert notification.',
  );
  static const PocketErrorDefinition
  turnCompletionAlertForegroundSignalFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1109',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not emit the in-app finished-turn completion signal while the app remained in the foreground.',
  );

  static const List<PocketErrorDefinition> definitions =
      <PocketErrorDefinition>[
        foregroundServicePermissionQueryFailed,
        foregroundServicePermissionRequestFailed,
        foregroundServiceEnableFailed,
        backgroundGraceEnableFailed,
        wakeLockEnableFailed,
        turnCompletionAlertPermissionQueryFailed,
        turnCompletionAlertPermissionRequestFailed,
        turnCompletionAlertNotificationUpdateFailed,
        turnCompletionAlertForegroundSignalFailed,
      ];
}
