import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';

class WorkspaceTurnBackgroundGraceHost extends StatelessWidget {
  const WorkspaceTurnBackgroundGraceHost({
    super.key,
    required this.hasActiveTurn,
    required this.onWarningChanged,
    required this.child,
    this.backgroundGraceController =
        const MethodChannelBackgroundGraceController(),
    this.supportsBackgroundGrace,
    this.appLifecycleVisibilityListenable,
  });

  final bool hasActiveTurn;
  final WorkspaceDeviceContinuityWarningChanged onWarningChanged;
  final Widget child;
  final BackgroundGraceController backgroundGraceController;
  final bool? supportsBackgroundGrace;
  final ValueListenable<AppLifecycleVisibility>?
  appLifecycleVisibilityListenable;

  @override
  Widget build(BuildContext context) {
    return BackgroundGraceHost(
      backgroundGraceController: backgroundGraceController,
      supportsBackgroundGrace: supportsBackgroundGrace,
      appLifecycleVisibilityListenable: appLifecycleVisibilityListenable,
      keepBackgroundGraceAlive: hasActiveTurn,
      onWarningChanged: onWarningChanged,
      child: child,
    );
  }
}
