import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

import 'live_lane_notice_contract.dart';
import 'live_lane_notice_surface.dart';

class LiveLaneNoticeHost extends StatefulWidget {
  const LiveLaneNoticeHost({
    super.key,
    required this.workspaceController,
    required this.connectionId,
    required this.isVisible,
    required this.contract,
  });

  final ConnectionWorkspaceController workspaceController;
  final String connectionId;
  final bool isVisible;
  final LiveLaneNoticeContract contract;

  @override
  State<LiveLaneNoticeHost> createState() => _LiveLaneNoticeHostState();
}

class _LiveLaneNoticeHostState extends State<LiveLaneNoticeHost>
    with WidgetsBindingObserver {
  Timer? _dismissTimer;
  String? _dismissKey;
  Duration? _dismissRemaining;
  Stopwatch? _dismissStopwatch;
  AppLifecycleState? _appLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
    _syncDismissal(widget.contract);
  }

  @override
  void didUpdateWidget(covariant LiveLaneNoticeHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectionId == widget.connectionId &&
        oldWidget.contract == widget.contract &&
        oldWidget.isVisible == widget.isVisible) {
      return;
    }
    _syncDismissal(widget.contract);
  }

  @override
  void dispose() {
    _cancelDismissal();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (_isDismissalVisible) {
      _resumeDismissal();
    } else {
      _pauseDismissal();
    }
  }

  bool get _isForegroundVisible =>
      appLifecycleStateIsForegroundVisible(_appLifecycleState);

  bool get _isDismissalVisible => _isForegroundVisible && widget.isVisible;

  void _syncDismissal(LiveLaneNoticeContract contract) {
    final dismissibleEntry = contract.dismissibleEntry;
    if (dismissibleEntry == null) {
      _cancelDismissal();
      return;
    }

    if (_dismissKey != dismissibleEntry.key) {
      _cancelDismissal();
      _dismissKey = dismissibleEntry.key;
      _dismissRemaining = dismissibleEntry.dismissAfterVisibleDuration;
    }

    if (_isDismissalVisible) {
      _resumeDismissal();
    } else {
      _pauseDismissal();
    }
  }

  void _cancelDismissal() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _dismissKey = null;
    _dismissRemaining = null;
    _dismissStopwatch = null;
  }

  void _pauseDismissal() {
    final timer = _dismissTimer;
    final remaining = _dismissRemaining;
    final stopwatch = _dismissStopwatch;
    if (timer == null || remaining == null || stopwatch == null) {
      return;
    }

    stopwatch.stop();
    final elapsed = stopwatch.elapsed;
    final nextRemaining = remaining - elapsed;
    _dismissTimer = null;
    _dismissStopwatch = null;
    _dismissRemaining = nextRemaining > Duration.zero
        ? nextRemaining
        : Duration.zero;
    timer.cancel();
  }

  void _resumeDismissal() {
    final dismissKey = _dismissKey;
    final remaining = _dismissRemaining;
    final dismissAction = widget.contract.dismissibleEntry?.dismissAction;
    if (!_isDismissalVisible ||
        dismissKey == null ||
        remaining == null ||
        dismissAction == null ||
        _dismissTimer != null) {
      return;
    }

    void dismissNotice() {
      if (!mounted || _dismissKey != dismissKey) {
        return;
      }
      _cancelDismissal();
      switch (dismissAction) {
        case LiveLaneNoticeDismissAction.finishedWhileAway:
          widget.workspaceController.dismissFinishedWhileAwayNotice(
            widget.connectionId,
          );
      }
    }

    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dismissNotice();
      });
      return;
    }

    _dismissStopwatch = Stopwatch()..start();
    _dismissTimer = Timer(remaining, dismissNotice);
  }

  @override
  Widget build(BuildContext context) {
    return LiveLaneNoticeSurface(contract: widget.contract);
  }
}
