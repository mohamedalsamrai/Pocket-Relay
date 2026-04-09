import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
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
  final Set<ChatSessionController> _attachedSessionControllers =
      <ChatSessionController>{};

  @override
  void initState() {
    super.initState();
    widget.workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionListeners();
  }

  @override
  void didUpdateWidget(covariant WorkspaceTurnActivityBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceController == widget.workspaceController) {
      return;
    }

    oldWidget.workspaceController.removeListener(_handleWorkspaceChanged);
    _detachAllSessionListeners();
    widget.workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionListeners();
  }

  @override
  void dispose() {
    widget.workspaceController.removeListener(_handleWorkspaceChanged);
    _detachAllSessionListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      workspaceHasContinuityActiveTurn(widget.workspaceController),
    );
  }

  void _handleWorkspaceChanged() {
    _syncSessionListeners();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleSessionChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _syncSessionListeners() {
    final nextControllers = _liveSessionControllers().toSet();

    for (final controller in _attachedSessionControllers.difference(
      nextControllers,
    )) {
      controller.removeListener(_handleSessionChanged);
    }

    for (final controller in nextControllers.difference(
      _attachedSessionControllers,
    )) {
      controller.addListener(_handleSessionChanged);
    }

    _attachedSessionControllers
      ..clear()
      ..addAll(nextControllers);
  }

  void _detachAllSessionListeners() {
    for (final controller in _attachedSessionControllers) {
      controller.removeListener(_handleSessionChanged);
    }
    _attachedSessionControllers.clear();
  }

  Iterable<ChatSessionController> _liveSessionControllers() sync* {
    for (final entry in workspaceLiveSessionControllers(
      widget.workspaceController,
    )) {
      yield entry.sessionController;
    }
  }
}
