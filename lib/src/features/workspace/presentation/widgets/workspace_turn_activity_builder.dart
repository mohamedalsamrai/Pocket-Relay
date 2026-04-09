import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_live_session_tracker.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_turn_activity.dart';

typedef WorkspaceTurnActivityWidgetBuilder =
    Widget Function(BuildContext context, bool hasActiveTurn);

class WorkspaceTurnActivityBuilder extends StatefulWidget {
  const WorkspaceTurnActivityBuilder({
    super.key,
    required this.workspaceController,
    required this.builder,
  });

  final ConnectionWorkspaceController workspaceController;
  final WorkspaceTurnActivityWidgetBuilder builder;

  @override
  State<WorkspaceTurnActivityBuilder> createState() =>
      _WorkspaceTurnActivityBuilderState();
}

class _WorkspaceTurnActivityBuilderState
    extends State<WorkspaceTurnActivityBuilder> {
  late final WorkspaceLiveSessionTracker _liveSessions;

  @override
  void initState() {
    super.initState();
    _liveSessions = WorkspaceLiveSessionTracker(widget.workspaceController)
      ..addListener(_handleLiveSessionsChanged);
  }

  @override
  void didUpdateWidget(covariant WorkspaceTurnActivityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceController == widget.workspaceController) {
      return;
    }

    _liveSessions.updateWorkspaceController(widget.workspaceController);
  }

  @override
  void dispose() {
    _liveSessions
      ..removeListener(_handleLiveSessionsChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      workspaceSessionControllersHaveContinuityActiveTurn(
        _liveSessions.sessionControllers,
      ),
    );
  }

  void _handleLiveSessionsChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }
}
