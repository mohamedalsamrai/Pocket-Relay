import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
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
  });

  final bool hasActiveTurn;
  final WorkspaceDeviceContinuityWarningChanged onWarningChanged;
  final Widget child;
  final BackgroundGraceController backgroundGraceController;
  final bool? supportsBackgroundGrace;

  @override
  Widget build(BuildContext context) {
    return BackgroundGraceHost(
      backgroundGraceController: backgroundGraceController,
      supportsBackgroundGrace: supportsBackgroundGrace,
      keepBackgroundGraceAlive: hasActiveTurn,
      onWarningChanged: onWarningChanged,
      child: child,
    );
  }
}
