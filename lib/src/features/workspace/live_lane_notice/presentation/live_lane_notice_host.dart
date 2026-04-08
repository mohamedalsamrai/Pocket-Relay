import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

import 'live_lane_notice_contract.dart';
import 'live_lane_notice_surface.dart';

class LiveLaneNoticeHost extends StatefulWidget {
  const LiveLaneNoticeHost({
    super.key,
    required this.workspaceController,
    required this.connectionId,
    required this.contract,
  });

  final ConnectionWorkspaceController workspaceController;
  final String connectionId;
  final LiveLaneNoticeContract contract;

  @override
  State<LiveLaneNoticeHost> createState() => _LiveLaneNoticeHostState();
}

class _LiveLaneNoticeHostState extends State<LiveLaneNoticeHost>
    with WidgetsBindingObserver {
  Timer? _dismissTimer;
  String? _dismissKey;
  Duration? _dismissRemaining;
  DateTime? _dismissStartedAt;
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
        oldWidget.contract == widget.contract) {
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
    if (_isForegroundVisible) {
      _resumeDismissal();
    } else {
      _pauseDismissal();
    }
  }

  bool get _isForegroundVisible =>
      _appLifecycleState == null || _appLifecycleState == AppLifecycleState.resumed;

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

    _resumeDismissal();
  }

  void _cancelDismissal() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _dismissKey = null;
    _dismissRemaining = null;
    _dismissStartedAt = null;
  }

  void _pauseDismissal() {
    final timer = _dismissTimer;
    final remaining = _dismissRemaining;
    final startedAt = _dismissStartedAt;
    if (timer == null || remaining == null || startedAt == null) {
      return;
    }

    final elapsed = DateTime.now().difference(startedAt);
    final nextRemaining = remaining - elapsed;
    _dismissTimer = null;
    _dismissStartedAt = null;
    _dismissRemaining =
        nextRemaining > Duration.zero ? nextRemaining : Duration.zero;
    timer.cancel();
  }

  void _resumeDismissal() {
    final dismissKey = _dismissKey;
    final remaining = _dismissRemaining;
    if (!_isForegroundVisible ||
        dismissKey == null ||
        remaining == null ||
        _dismissTimer != null) {
      return;
    }

    void dismissNotice() {
      if (!mounted || _dismissKey != dismissKey) {
        return;
      }
      _cancelDismissal();
      widget.workspaceController.dismissTurnLivenessNotice(widget.connectionId);
    }

    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dismissNotice();
      });
      return;
    }

    _dismissStartedAt = DateTime.now();
    _dismissTimer = Timer(remaining, dismissNotice);
  }

  @override
  Widget build(BuildContext context) {
    return LiveLaneNoticeSurface(contract: widget.contract);
  }
}
