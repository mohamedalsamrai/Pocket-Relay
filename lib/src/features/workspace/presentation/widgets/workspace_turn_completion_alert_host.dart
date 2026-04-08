import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

class WorkspaceTurnCompletionAlertHost extends StatefulWidget {
  const WorkspaceTurnCompletionAlertHost({
    super.key,
    required this.workspaceController,
    required this.child,
    this.turnCompletionAlertController =
        const PlatformTurnCompletionAlertController(),
    this.notificationPermissionController =
        const MethodChannelNotificationPermissionController(),
    this.supportsForegroundSignal,
    this.supportsBackgroundAlerts,
    this.requestNotificationPermissionWhileForegrounded = false,
  });

  final ConnectionWorkspaceController workspaceController;
  final Widget child;
  final TurnCompletionAlertController turnCompletionAlertController;
  final NotificationPermissionController notificationPermissionController;
  final bool? supportsForegroundSignal;
  final bool? supportsBackgroundAlerts;
  final bool requestNotificationPermissionWhileForegrounded;

  @override
  State<WorkspaceTurnCompletionAlertHost> createState() =>
      _WorkspaceTurnCompletionAlertHostState();
}

class _WorkspaceTurnCompletionAlertHostState
    extends State<WorkspaceTurnCompletionAlertHost> {
  final _completionAlertsController =
      StreamController<TurnCompletionAlertRequest>.broadcast();
  final Map<String, ChatSessionController> _attachedControllersByConnectionId =
      <String, ChatSessionController>{};
  final Map<String, StreamSubscription<ChatSessionTurnCompletedEvent>>
  _completionSubscriptionsByConnectionId =
      <String, StreamSubscription<ChatSessionTurnCompletedEvent>>{};

  @override
  void initState() {
    super.initState();
    widget.workspaceController.addListener(_handleWorkspaceChanged);
    _syncSessionListeners();
  }

  @override
  void didUpdateWidget(covariant WorkspaceTurnCompletionAlertHost oldWidget) {
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
    unawaited(_completionAlertsController.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TurnCompletionAlertHost(
      completionAlerts: _completionAlertsController.stream,
      hasActiveTurn: _hasActiveTurnAcrossLiveLanes(),
      turnCompletionAlertController: widget.turnCompletionAlertController,
      notificationPermissionController: widget.notificationPermissionController,
      supportsForegroundSignal: widget.supportsForegroundSignal,
      supportsBackgroundAlerts: widget.supportsBackgroundAlerts,
      requestNotificationPermissionWhileForegrounded:
          widget.requestNotificationPermissionWhileForegrounded,
      onWarningChanged:
          widget.workspaceController.setTurnCompletionAlertWarning,
      child: widget.child,
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
    final nextControllersByConnectionId = <String, ChatSessionController>{
      for (final connectionId
          in widget.workspaceController.state.liveConnectionIds)
        if (widget.workspaceController.bindingForConnectionId(connectionId)
            case final binding?)
          connectionId: binding.sessionController,
    };

    final currentConnectionIds = _attachedControllersByConnectionId.keys
        .toSet();
    final nextConnectionIds = nextControllersByConnectionId.keys.toSet();

    for (final connectionId in currentConnectionIds.difference(
      nextConnectionIds,
    )) {
      _detachController(connectionId);
    }

    for (final entry in nextControllersByConnectionId.entries) {
      final existingController = _attachedControllersByConnectionId[entry.key];
      if (identical(existingController, entry.value)) {
        continue;
      }
      if (existingController != null) {
        _detachController(entry.key);
      }
      _attachController(entry.key, entry.value);
    }
  }

  void _attachController(
    String connectionId,
    ChatSessionController controller,
  ) {
    controller.addListener(_handleSessionChanged);
    _attachedControllersByConnectionId[connectionId] = controller;
    _completionSubscriptionsByConnectionId[connectionId] = controller
        .turnCompletedEvents
        .listen((event) => _handleTurnCompleted(connectionId, event));
  }

  void _detachController(String connectionId) {
    final controller = _attachedControllersByConnectionId.remove(connectionId);
    controller?.removeListener(_handleSessionChanged);
    unawaited(
      _completionSubscriptionsByConnectionId.remove(connectionId)?.cancel() ??
          Future<void>.value(),
    );
  }

  void _detachAllSessionListeners() {
    for (final connectionId
        in _attachedControllersByConnectionId.keys.toList()) {
      _detachController(connectionId);
    }
  }

  void _handleTurnCompleted(
    String connectionId,
    ChatSessionTurnCompletedEvent event,
  ) {
    _completionAlertsController.add(
      TurnCompletionAlertRequest(
        id: '$connectionId:${event.turnId}',
        title: 'Turn completed',
        body: _completionAlertBodyFor(connectionId),
      ),
    );
  }

  String _completionAlertBodyFor(String connectionId) {
    final connection = widget.workspaceController.state.catalog.connectionForId(
      connectionId,
    );
    final label = connection?.profile.label.trim() ?? '';
    if (label.isEmpty) {
      return 'Return to Pocket Relay to review the latest response.';
    }
    return '$label is ready to review.';
  }

  bool _hasActiveTurnAcrossLiveLanes() {
    for (final controller in _attachedControllersByConnectionId.values) {
      if (_sessionHasActiveTurn(controller.sessionState)) {
        return true;
      }
    }

    return false;
  }

  bool _sessionHasActiveTurn(TranscriptSessionState sessionState) {
    if (_turnKeepsWorkspaceActivity(sessionState.sessionActiveTurn)) {
      return true;
    }

    for (final timeline in sessionState.timelinesByThreadId.values) {
      if (_turnKeepsWorkspaceActivity(timeline.activeTurn)) {
        return true;
      }
    }

    return false;
  }

  bool _turnKeepsWorkspaceActivity(TranscriptActiveTurnState? activeTurn) {
    return activeTurn?.timer.isRunning == true;
  }
}
