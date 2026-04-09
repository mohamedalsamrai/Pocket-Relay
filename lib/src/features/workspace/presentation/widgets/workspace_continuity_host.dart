import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_continuity_lifecycle.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_background_grace_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_completion_alert_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_foreground_service_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_wake_lock_host.dart';

class WorkspaceContinuityHost extends StatelessWidget {
  const WorkspaceContinuityHost({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    required this.child,
    this.backgroundGraceController,
    this.foregroundServiceController,
    this.notificationPermissionController,
    this.displayWakeLockController,
    this.turnCompletionAlertController,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final Widget child;
  final BackgroundGraceController? backgroundGraceController;
  final ForegroundServiceController? foregroundServiceController;
  final NotificationPermissionController? notificationPermissionController;
  final DisplayWakeLockController? displayWakeLockController;
  final TurnCompletionAlertController? turnCompletionAlertController;

  @override
  Widget build(BuildContext context) {
    final resolvedNotificationPermissionController =
        notificationPermissionController ??
        const MethodChannelNotificationPermissionController();
    final warningCallbacks = WorkspaceDeviceContinuityWarningCallbacks(
      sink: workspaceController,
    );
    final lifecycleCallbacks = WorkspaceContinuityLifecycleCallbacks(
      sink: workspaceController,
    );

    return WorkspaceTurnActivityBuilder(
      workspaceController: workspaceController,
      builder: (context, hasActiveTurn) {
        return WorkspaceTurnForegroundServiceHost(
          hasActiveTurn: hasActiveTurn,
          onWarningChanged: warningCallbacks.foregroundService,
          foregroundServiceController:
              foregroundServiceController ??
              const MethodChannelForegroundServiceController(),
          notificationPermissionController:
              resolvedNotificationPermissionController,
          supportsForegroundService:
              platformPolicy.supportsActiveTurnForegroundService,
          child: WorkspaceTurnBackgroundGraceHost(
            hasActiveTurn: hasActiveTurn,
            onWarningChanged: warningCallbacks.backgroundGrace,
            backgroundGraceController:
                backgroundGraceController ??
                const MethodChannelBackgroundGraceController(),
            supportsBackgroundGrace:
                platformPolicy.supportsFiniteBackgroundGrace,
            child: WorkspaceAppLifecycleHost(
              onLifecycleStateChanged: lifecycleCallbacks.appLifecycle,
              child: WorkspaceTurnCompletionAlertHost(
                workspaceController: workspaceController,
                hasActiveTurn: hasActiveTurn,
                onWarningChanged: warningCallbacks.turnCompletionAlert,
                turnCompletionAlertController:
                    turnCompletionAlertController ??
                    const PlatformTurnCompletionAlertController(),
                notificationPermissionController:
                    resolvedNotificationPermissionController,
                supportsForegroundSignal:
                    platformPolicy.supportsForegroundTurnCompletionSignal,
                supportsBackgroundAlerts:
                    platformPolicy.supportsBackgroundTurnCompletionAlerts,
                requestNotificationPermissionWhileForegrounded:
                    platformPolicy.supportsBackgroundTurnCompletionAlerts &&
                    !platformPolicy.supportsActiveTurnForegroundService,
                child: WorkspaceTurnWakeLockHost(
                  hasActiveTurn: hasActiveTurn,
                  onWarningChanged: warningCallbacks.wakeLock,
                  displayWakeLockController:
                      displayWakeLockController ??
                      const WakelockPlusDisplayWakeLockController(),
                  supportsWakeLock: platformPolicy.supportsWakeLock,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
