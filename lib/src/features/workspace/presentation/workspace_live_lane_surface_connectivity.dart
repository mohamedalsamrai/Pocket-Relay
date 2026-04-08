part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  Future<void> _refreshLaneRemoteRuntime() async {
    if (_isRefreshingLaneRemoteRuntime) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final connectionId = widget.laneBinding.connectionId;
    _setRefreshingLaneRemoteRuntime(true);
    try {
      await workspaceController.refreshRemoteRuntime(
        connectionId: connectionId,
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setRefreshingLaneRemoteRuntime(false);
      }
    }
  }

  Future<void> _runLaneRemoteServerAction(
    ConnectionSettingsRemoteServerActionId actionId,
  ) async {
    if (_activeLaneRemoteServerAction != null) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final connectionId = widget.laneBinding.connectionId;
    _setActiveLaneRemoteServerAction(actionId);
    try {
      final remoteRuntime = await switch (actionId) {
        ConnectionSettingsRemoteServerActionId.start =>
          workspaceController.startRemoteServer(connectionId: connectionId),
        ConnectionSettingsRemoteServerActionId.stop =>
          workspaceController.stopRemoteServer(connectionId: connectionId),
        ConnectionSettingsRemoteServerActionId.restart =>
          workspaceController.restartRemoteServer(connectionId: connectionId),
      };
      if (!mounted ||
          widget.workspaceController != workspaceController ||
          widget.laneBinding.connectionId != connectionId) {
        return;
      }

      if (!_didRemoteServerActionSucceed(actionId, remoteRuntime)) {
        _showTransientError(
          ConnectionLifecycleErrors.remoteServerActionFailure(
            actionId,
            remoteRuntime: remoteRuntime,
          ),
        );
      }
    } catch (error) {
      if (!mounted ||
          widget.workspaceController != workspaceController ||
          widget.laneBinding.connectionId != connectionId) {
        return;
      }

      _showTransientError(
        ConnectionLifecycleErrors.remoteServerActionFailure(
          actionId,
          remoteRuntime: workspaceController.state.remoteRuntimeFor(
            connectionId,
          ),
          error: error,
        ),
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setActiveLaneRemoteServerAction(null);
      }
    }
  }

  Future<void> _connectLaneTransport() async {
    if (_isConnectingLaneTransport ||
        widget.laneBinding.agentAdapterClient.isConnected) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final laneBinding = widget.laneBinding;
    final connectionId = laneBinding.connectionId;
    _setConnectingLaneTransport(true);
    try {
      await laneBinding.agentAdapterClient.connect(
        profile: laneBinding.sessionController.profile,
        secrets: laneBinding.sessionController.secrets,
      );
    } catch (error) {
      ConnectionRemoteRuntimeState? remoteRuntime;
      try {
        remoteRuntime = await workspaceController.refreshRemoteRuntime(
          connectionId: connectionId,
        );
      } catch (_) {
        remoteRuntime = workspaceController.state.remoteRuntimeFor(
          connectionId,
        );
      }
      if (!mounted ||
          widget.workspaceController != workspaceController ||
          widget.laneBinding != laneBinding) {
        return;
      }
      _showTransientError(
        ConnectionLifecycleErrors.connectLaneFailure(
          remoteRuntime: remoteRuntime,
          error: error,
        ),
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding == laneBinding) {
        _setConnectingLaneTransport(false);
      }
    }
  }

  Future<void> _connectLane() async {
    if (_isRefreshingLaneRemoteRuntime ||
        _isConnectingLaneTransport ||
        _activeLaneRemoteServerAction != null) {
      return;
    }

    final profile = widget.laneBinding.sessionController.profile;
    if (!profile.isRemote || !profile.isReady) {
      return;
    }

    final connectionId = widget.laneBinding.connectionId;
    final reconnectRequirement = widget.workspaceController.state
        .reconnectRequirementFor(connectionId);
    if (reconnectRequirement != null) {
      await _restartLane();
      return;
    }

    final remoteRuntime = await _prepareLaneRemoteRuntimeForConnect();
    if (!mounted || remoteRuntime == null) {
      return;
    }
    if (!remoteRuntime.hostCapability.isSupported ||
        !remoteRuntime.server.isConnectable) {
      _showTransientError(
        ConnectionLifecycleErrors.connectLaneFailure(
          remoteRuntime: remoteRuntime,
        ),
      );
      return;
    }

    await _connectLaneTransport();
  }

  Future<ConnectionRemoteRuntimeState?>
  _prepareLaneRemoteRuntimeForConnect() async {
    final connectionId = widget.laneBinding.connectionId;
    var remoteRuntime = widget.workspaceController.state.remoteRuntimeFor(
      connectionId,
    );

    if (_shouldRefreshLaneRemoteRuntime(remoteRuntime)) {
      await _refreshLaneRemoteRuntime();
      remoteRuntime = widget.workspaceController.state.remoteRuntimeFor(
        connectionId,
      );
    }

    final hostStatus =
        remoteRuntime?.hostCapability.status ??
        ConnectionRemoteHostCapabilityStatus.unknown;
    if (hostStatus == ConnectionRemoteHostCapabilityStatus.checking) {
      return null;
    }
    if (hostStatus != ConnectionRemoteHostCapabilityStatus.supported) {
      return remoteRuntime;
    }

    if (remoteRuntime?.server.status == ConnectionRemoteServerStatus.unknown) {
      await _refreshLaneRemoteRuntime();
      remoteRuntime = widget.workspaceController.state.remoteRuntimeFor(
        connectionId,
      );
    }

    switch (remoteRuntime?.server.status ??
        ConnectionRemoteServerStatus.unknown) {
      case ConnectionRemoteServerStatus.notRunning:
        await _runLaneRemoteServerAction(
          ConnectionSettingsRemoteServerActionId.start,
        );
        final nextRemoteRuntime = widget.workspaceController.state
            .remoteRuntimeFor(connectionId);
        return nextRemoteRuntime?.server.isConnectable == true
            ? nextRemoteRuntime
            : null;
      case ConnectionRemoteServerStatus.unhealthy:
        await _runLaneRemoteServerAction(
          ConnectionSettingsRemoteServerActionId.restart,
        );
        final nextRemoteRuntime = widget.workspaceController.state
            .remoteRuntimeFor(connectionId);
        return nextRemoteRuntime?.server.isConnectable == true
            ? nextRemoteRuntime
            : null;
      case ConnectionRemoteServerStatus.checking:
        return null;
      case ConnectionRemoteServerStatus.running:
      case ConnectionRemoteServerStatus.unknown:
        return remoteRuntime;
    }
  }

  bool _shouldRefreshLaneRemoteRuntime(
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    if (remoteRuntime == null) {
      return true;
    }

    final hostStatus = remoteRuntime.hostCapability.status;
    if (hostStatus == ConnectionRemoteHostCapabilityStatus.checking) {
      return false;
    }
    if (hostStatus == ConnectionRemoteHostCapabilityStatus.unknown ||
        hostStatus == ConnectionRemoteHostCapabilityStatus.probeFailed ||
        hostStatus == ConnectionRemoteHostCapabilityStatus.unsupported) {
      return true;
    }

    return remoteRuntime.server.status == ConnectionRemoteServerStatus.unknown;
  }

  Future<void> _disconnectLaneTransport() async {
    if (_isDisconnectingLaneTransport ||
        !widget.laneBinding.agentAdapterClient.isConnected) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final connectionId = widget.laneBinding.connectionId;
    _setDisconnectingLaneTransport(true);
    try {
      await workspaceController.disconnectConnection(connectionId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showTransientError(
        ConnectionLifecycleErrors.disconnectLaneFailure(error: error),
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setDisconnectingLaneTransport(false);
      }
    }
  }

  bool _didRemoteServerActionSucceed(
    ConnectionSettingsRemoteServerActionId actionId,
    ConnectionRemoteRuntimeState remoteRuntime,
  ) {
    if (!remoteRuntime.hostCapability.isSupported) {
      return false;
    }

    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start =>
        remoteRuntime.server.status == ConnectionRemoteServerStatus.running,
      ConnectionSettingsRemoteServerActionId.stop =>
        remoteRuntime.server.status == ConnectionRemoteServerStatus.notRunning,
      ConnectionSettingsRemoteServerActionId.restart =>
        remoteRuntime.server.status == ConnectionRemoteServerStatus.running,
    };
  }

  void _showTransientError(PocketUserFacingError error) {
    showPocketErrorSnackBar(context, error);
  }
}
