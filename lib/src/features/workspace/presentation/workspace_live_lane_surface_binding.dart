part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  void _resetLaneViewFlags() {
    _isOpeningConnectionSettings = false;
    _isRestartingLane = false;
    _isRefreshingLaneRemoteRuntime = false;
    _isConnectingLaneTransport = false;
    _isDisconnectingLaneTransport = false;
    _activeLaneRemoteServerAction = null;
  }

  void _attachLaneBindingListeners(ConnectionLaneBinding laneBinding) {
    laneBinding.sessionController.addListener(_handleLaneBindingChange);
    _laneAgentAdapterEventSubscription = laneBinding.agentAdapterClient.events
        .listen((_) {
          if (!mounted) {
            return;
          }
          setState(() {});
        });
  }

  void _detachLaneBindingListeners(ConnectionLaneBinding laneBinding) {
    laneBinding.sessionController.removeListener(_handleLaneBindingChange);
    unawaited(
      _laneAgentAdapterEventSubscription?.cancel() ?? Future<void>.value(),
    );
    _laneAgentAdapterEventSubscription = null;
  }

  void _handleLaneBindingChange() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _setOpeningConnectionSettings(bool value) {
    setState(() {
      _isOpeningConnectionSettings = value;
    });
  }

  void _setRestartingLane(bool value) {
    setState(() {
      _isRestartingLane = value;
    });
  }

  void _setRefreshingLaneRemoteRuntime(bool value) {
    setState(() {
      _isRefreshingLaneRemoteRuntime = value;
    });
  }

  void _setConnectingLaneTransport(bool value) {
    setState(() {
      _isConnectingLaneTransport = value;
    });
  }

  void _setDisconnectingLaneTransport(bool value) {
    setState(() {
      _isDisconnectingLaneTransport = value;
    });
  }

  void _setActiveLaneRemoteServerAction(
    ConnectionSettingsRemoteServerActionId? value,
  ) {
    setState(() {
      _activeLaneRemoteServerAction = value;
    });
  }
}
