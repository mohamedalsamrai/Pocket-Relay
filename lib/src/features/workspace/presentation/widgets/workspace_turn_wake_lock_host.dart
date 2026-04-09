import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';

class WorkspaceTurnWakeLockHost extends StatelessWidget {
  const WorkspaceTurnWakeLockHost({
    super.key,
    required this.hasActiveTurn,
    required this.onWarningChanged,
    required this.child,
    this.displayWakeLockController =
        const WakelockPlusDisplayWakeLockController(),
    this.supportsWakeLock,
    this.appLifecycleVisibilityListenable,
  });

  final bool hasActiveTurn;
  final WorkspaceDeviceContinuityWarningChanged onWarningChanged;
  final Widget child;
  final DisplayWakeLockController displayWakeLockController;
  final bool? supportsWakeLock;
  final ValueListenable<AppLifecycleVisibility>?
  appLifecycleVisibilityListenable;

  @override
  Widget build(BuildContext context) {
    return DisplayWakeLockHost(
      displayWakeLockController: displayWakeLockController,
      supportsWakeLock: supportsWakeLock,
      appLifecycleVisibilityListenable: appLifecycleVisibilityListenable,
      keepDisplayAwake: hasActiveTurn,
      onWarningChanged: onWarningChanged,
      child: child,
    );
  }
}
