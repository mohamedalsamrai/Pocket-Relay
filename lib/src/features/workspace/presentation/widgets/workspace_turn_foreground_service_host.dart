import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart';

class WorkspaceTurnForegroundServiceHost extends StatelessWidget {
  const WorkspaceTurnForegroundServiceHost({
    super.key,
    required this.workspaceController,
    required this.onWarningChanged,
    required this.child,
    this.foregroundServiceController =
        const MethodChannelForegroundServiceController(),
    this.notificationPermissionController =
        const MethodChannelNotificationPermissionController(),
    this.supportsForegroundService,
  });

  final ConnectionWorkspaceController workspaceController;
  final WorkspaceDeviceContinuityWarningChanged onWarningChanged;
  final Widget child;
  final ForegroundServiceController foregroundServiceController;
  final NotificationPermissionController notificationPermissionController;
  final bool? supportsForegroundService;

  @override
  Widget build(BuildContext context) {
    return WorkspaceTurnActivityBuilder(
      workspaceController: workspaceController,
      builder: (context, hasActiveTurn) {
        return ForegroundServiceHost(
          foregroundServiceController: foregroundServiceController,
          notificationPermissionController: notificationPermissionController,
          supportsForegroundService: supportsForegroundService,
          keepForegroundServiceRunning: hasActiveTurn,
          onWarningChanged: onWarningChanged,
          child: child,
        );
      },
    );
  }
}
