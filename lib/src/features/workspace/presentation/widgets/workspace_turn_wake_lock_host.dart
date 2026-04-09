import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
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
  });

  final bool hasActiveTurn;
  final WorkspaceDeviceContinuityWarningChanged onWarningChanged;
  final Widget child;
  final DisplayWakeLockController displayWakeLockController;
  final bool? supportsWakeLock;

  @override
  Widget build(BuildContext context) {
    return DisplayWakeLockHost(
      displayWakeLockController: displayWakeLockController,
      supportsWakeLock: supportsWakeLock,
      keepDisplayAwake: hasActiveTurn,
      onWarningChanged: onWarningChanged,
      child: child,
    );
  }
}
