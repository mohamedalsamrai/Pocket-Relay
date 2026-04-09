import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';

import 'controller/controller_test_support.dart';

void main() {
  test('controller routes device continuity warnings by target', () {
    final controller = buildWorkspaceController(
      clientsById: <String, FakeCodexAppServerClient>{},
    );
    addTearDown(controller.dispose);

    final cases =
        <
          ({
            WorkspaceDeviceContinuityWarningTarget target,
            PocketUserFacingError? Function(
              ConnectionWorkspaceDeviceContinuityWarnings warnings,
            )
            read,
          })
        >[
          (
            target: WorkspaceDeviceContinuityWarningTarget.foregroundService,
            read: (warnings) => warnings.foregroundServiceWarning,
          ),
          (
            target: WorkspaceDeviceContinuityWarningTarget.backgroundGrace,
            read: (warnings) => warnings.backgroundGraceWarning,
          ),
          (
            target: WorkspaceDeviceContinuityWarningTarget.wakeLock,
            read: (warnings) => warnings.wakeLockWarning,
          ),
          (
            target: WorkspaceDeviceContinuityWarningTarget.turnCompletionAlert,
            read: (warnings) => warnings.turnCompletionAlertWarning,
          ),
        ];

    for (final entry in cases) {
      final warning = PocketUserFacingError(
        definition: PocketErrorCatalog.deviceWakeLockEnableFailed,
        title: 'Device continuity warning',
        message: entry.target.name,
      );

      controller.setDeviceContinuityWarning(entry.target, warning);

      expect(
        entry.read(controller.state.deviceContinuityWarnings),
        same(warning),
      );

      controller.setDeviceContinuityWarning(entry.target, null);

      expect(entry.read(controller.state.deviceContinuityWarnings), isNull);
    }
  });
}
