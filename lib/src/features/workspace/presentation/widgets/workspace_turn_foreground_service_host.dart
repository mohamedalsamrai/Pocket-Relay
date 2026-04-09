import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';

class WorkspaceTurnForegroundServiceHost extends StatelessWidget {
  const WorkspaceTurnForegroundServiceHost({
    super.key,
    required this.hasActiveTurn,
    required this.onWarningChanged,
    required this.child,
    this.foregroundServiceController =
        const MethodChannelForegroundServiceController(),
    this.notificationPermissionController =
        const MethodChannelNotificationPermissionController(),
    this.supportsForegroundService,
  });

  final bool hasActiveTurn;
  final WorkspaceDeviceContinuityWarningChanged onWarningChanged;
  final Widget child;
  final ForegroundServiceController foregroundServiceController;
  final NotificationPermissionController notificationPermissionController;
  final bool? supportsForegroundService;

  @override
  Widget build(BuildContext context) {
    return ForegroundServiceHost(
      foregroundServiceController: foregroundServiceController,
      notificationPermissionController: notificationPermissionController,
      supportsForegroundService: supportsForegroundService,
      keepForegroundServiceRunning: hasActiveTurn,
      onWarningChanged: onWarningChanged,
      child: child,
    );
  }
}
