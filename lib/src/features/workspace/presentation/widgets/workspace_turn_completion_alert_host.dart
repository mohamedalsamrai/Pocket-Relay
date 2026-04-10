import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_live_session_tracker.dart';

class WorkspaceTurnCompletionAlertHost extends StatefulWidget {
  const WorkspaceTurnCompletionAlertHost({
    super.key,
    required this.workspaceController,
    required this.hasActiveTurn,
    required this.onWarningChanged,
    required this.child,
    this.turnCompletionAlertController =
        const PlatformTurnCompletionAlertController(),
    this.notificationPermissionController =
        const MethodChannelNotificationPermissionController(),
    this.supportsForegroundSignal,
    this.supportsBackgroundAlerts,
    this.requestNotificationPermissionWhileForegrounded = false,
    this.appLifecycleVisibilityListenable,
  });

  final ConnectionWorkspaceController workspaceController;
  final bool hasActiveTurn;
  final WorkspaceDeviceContinuityWarningChanged onWarningChanged;
  final Widget child;
  final TurnCompletionAlertController turnCompletionAlertController;
  final NotificationPermissionController notificationPermissionController;
  final bool? supportsForegroundSignal;
  final bool? supportsBackgroundAlerts;
  final bool requestNotificationPermissionWhileForegrounded;
  final ValueListenable<AppLifecycleVisibility>?
  appLifecycleVisibilityListenable;

  @override
  State<WorkspaceTurnCompletionAlertHost> createState() =>
      _WorkspaceTurnCompletionAlertHostState();
}

class _WorkspaceTurnCompletionAlertHostState
    extends State<WorkspaceTurnCompletionAlertHost> {
  final _completionAlertsController =
      StreamController<TurnCompletionAlertRequest>.broadcast();
  late final WorkspaceLiveSessionTracker _liveSessions;
  final Map<String, ChatSessionController> _completionControllersByLaneId =
      <String, ChatSessionController>{};
  final Map<String, String> _connectionIdsByLaneId = <String, String>{};
  final Map<String, StreamSubscription<ChatSessionTurnCompletedEvent>>
  _completionSubscriptionsByLaneId =
      <String, StreamSubscription<ChatSessionTurnCompletedEvent>>{};

  @override
  void initState() {
    super.initState();
    _liveSessions = WorkspaceLiveSessionTracker(widget.workspaceController)
      ..addListener(_handleLiveSessionsChanged);
    _syncCompletionSubscriptions();
  }

  @override
  void didUpdateWidget(covariant WorkspaceTurnCompletionAlertHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceController == widget.workspaceController) {
      return;
    }

    _liveSessions.updateWorkspaceController(widget.workspaceController);
    _syncCompletionSubscriptions();
  }

  @override
  void dispose() {
    _liveSessions
      ..removeListener(_handleLiveSessionsChanged)
      ..dispose();
    _detachAllCompletionSubscriptions();
    unawaited(_completionAlertsController.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TurnCompletionAlertHost(
      completionAlerts: _completionAlertsController.stream,
      hasActiveTurn: widget.hasActiveTurn,
      turnCompletionAlertController: widget.turnCompletionAlertController,
      notificationPermissionController: widget.notificationPermissionController,
      supportsForegroundSignal: widget.supportsForegroundSignal,
      supportsBackgroundAlerts: widget.supportsBackgroundAlerts,
      requestNotificationPermissionWhileForegrounded:
          widget.requestNotificationPermissionWhileForegrounded,
      appLifecycleVisibilityListenable: widget.appLifecycleVisibilityListenable,
      onWarningChanged: widget.onWarningChanged,
      child: widget.child,
    );
  }

  void _handleLiveSessionsChanged() {
    _syncCompletionSubscriptions();
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _syncCompletionSubscriptions() {
    final nextEntriesByLaneId = <String, WorkspaceLiveSessionControllerEntry>{
      for (final entry in workspaceLiveSessionControllers(
        widget.workspaceController,
      ))
        entry.laneId: entry,
    };

    final currentLaneIds = _completionControllersByLaneId.keys.toSet();
    final nextLaneIds = nextEntriesByLaneId.keys.toSet();

    for (final laneId in currentLaneIds.difference(nextLaneIds)) {
      _detachCompletionSubscription(laneId);
    }

    for (final entry in nextEntriesByLaneId.entries) {
      final existingController = _completionControllersByLaneId[entry.key];
      if (identical(existingController, entry.value.sessionController) &&
          _connectionIdsByLaneId[entry.key] == entry.value.connectionId) {
        continue;
      }
      if (existingController != null) {
        _detachCompletionSubscription(entry.key);
      }
      _attachCompletionSubscription(
        entry.key,
        connectionId: entry.value.connectionId,
        controller: entry.value.sessionController,
      );
    }
  }

  void _attachCompletionSubscription(
    String laneId, {
    required String connectionId,
    required ChatSessionController controller,
  }) {
    _completionControllersByLaneId[laneId] = controller;
    _connectionIdsByLaneId[laneId] = connectionId;
    _completionSubscriptionsByLaneId[laneId] = controller.turnCompletedEvents
        .listen((event) => _handleTurnCompleted(laneId, event));
  }

  void _detachCompletionSubscription(String laneId) {
    _completionControllersByLaneId.remove(laneId);
    _connectionIdsByLaneId.remove(laneId);
    unawaited(
      _completionSubscriptionsByLaneId.remove(laneId)?.cancel() ??
          Future<void>.value(),
    );
  }

  void _detachAllCompletionSubscriptions() {
    for (final laneId in _completionControllersByLaneId.keys.toList()) {
      _detachCompletionSubscription(laneId);
    }
  }

  void _handleTurnCompleted(
    String laneId,
    ChatSessionTurnCompletedEvent event,
  ) {
    final connectionId = _connectionIdsByLaneId[laneId];
    if (connectionId == null) {
      return;
    }
    _completionAlertsController.add(
      TurnCompletionAlertRequest(
        id: '$laneId:${event.turnId}',
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
}
