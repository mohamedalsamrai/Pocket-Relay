part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  Widget? _buildLaneConnectionStrip(
    BuildContext context, {
    required ConnectionProfile profile,
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required bool isLaneBusy,
    required bool isRestartInProgress,
    required Widget? recoveryNotice,
  }) {
    final agentAdapterConnected =
        widget.laneBinding.agentAdapterClient.isConnected;
    final showSteadyStateStrip =
        !agentAdapterConnected ||
        reconnectRequirement != null ||
        transportRecoveryPhase != null ||
        liveReattachPhase != null ||
        recoveryNotice != null ||
        _isConnectingLaneTransport;
    if (!showSteadyStateStrip) {
      return null;
    }

    final primaryAction = _lanePrimaryActionFor(
      profile: profile,
      reconnectRequirement: reconnectRequirement,
      remoteRuntime: remoteRuntime,
      isLaneBusy: isLaneBusy,
      isRestartInProgress: isRestartInProgress,
    );
    if (primaryAction == null && recoveryNotice == null) {
      return null;
    }
    return _WorkspaceLaneConnectionStrip(
      primaryAction: primaryAction,
      notice: recoveryNotice,
    );
  }

  Widget? _buildLaneEmptyStateContent({
    required ConnectionProfile profile,
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required bool isLaneBusy,
    required bool isRestartInProgress,
    required Widget? recoveryNotice,
  }) {
    if (!profile.isRemote || !profile.isReady) {
      return null;
    }

    final workspacePath = profile.workspaceDir.trim();
    final primaryAction = _lanePrimaryActionFor(
      profile: profile,
      reconnectRequirement: reconnectRequirement,
      remoteRuntime: remoteRuntime,
      isLaneBusy: isLaneBusy,
      isRestartInProgress: isRestartInProgress,
    );
    if (workspacePath.isEmpty &&
        primaryAction == null &&
        recoveryNotice == null) {
      return null;
    }

    return _WorkspaceLaneEmptyStateContent(
      workspacePath: workspacePath.isEmpty ? null : workspacePath,
      primaryAction: primaryAction,
      notice: recoveryNotice,
    );
  }

  _WorkspaceLaneActionContract? _lanePrimaryActionFor({
    required ConnectionProfile profile,
    required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required bool isLaneBusy,
    required bool isRestartInProgress,
  }) {
    if (!profile.isRemote || !profile.isReady) {
      return null;
    }
    if (widget.laneBinding.agentAdapterClient.isConnected &&
        reconnectRequirement == null) {
      return null;
    }

    final isBusy =
        isLaneBusy ||
        _isRefreshingLaneRemoteRuntime ||
        _isConnectingLaneTransport ||
        _isDisconnectingLaneTransport ||
        _activeLaneRemoteServerAction != null ||
        isRestartInProgress;
    if (reconnectRequirement case final requirement?) {
      return _WorkspaceLaneActionContract(
        key: const ValueKey<String>('lane_connection_action_reconnect'),
        label: ConnectionWorkspaceCopy.reconnectActionFor(requirement),
        onPressed: isBusy
            ? null
            : () {
                unawaited(_restartLane());
              },
      );
    }
    final isCheckingRuntime =
        _isRefreshingLaneRemoteRuntime ||
        remoteRuntime?.hostCapability.status ==
            ConnectionRemoteHostCapabilityStatus.checking ||
        remoteRuntime?.server.status == ConnectionRemoteServerStatus.checking;

    return _WorkspaceLaneActionContract(
      key: const ValueKey<String>('lane_connection_action_connect'),
      label: ConnectionWorkspaceCopy.connectAction,
      onPressed: isBusy || isCheckingRuntime
          ? null
          : () {
              unawaited(_connectLane());
            },
    );
  }
}

class _WorkspaceLaneActionContract {
  const _WorkspaceLaneActionContract({
    required this.key,
    required this.label,
    required this.onPressed,
  });

  final Key key;
  final String label;
  final VoidCallback? onPressed;
}

class _WorkspaceLaneEmptyStateContent extends StatelessWidget {
  const _WorkspaceLaneEmptyStateContent({
    this.workspacePath,
    this.primaryAction,
    this.notice,
  });

  final String? workspacePath;
  final _WorkspaceLaneActionContract? primaryAction;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryAction = this.primaryAction;
    final workspacePath = this.workspacePath?.trim();
    final hasWorkspacePath = workspacePath != null && workspacePath.isNotEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasWorkspacePath) ...[
            Text(
              workspacePath,
              key: const ValueKey<String>('lane_empty_state_workspace_path'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          if (primaryAction != null) ...[
            if (hasWorkspacePath) const SizedBox(height: 14),
            FilledButton.tonal(
              key: primaryAction.key,
              onPressed: primaryAction.onPressed,
              child: Text(primaryAction.label),
            ),
          ],
          if (notice != null) ...[const SizedBox(height: 14), notice!],
        ],
      ),
    );
  }
}

class _WorkspaceLaneConnectionStrip extends StatelessWidget {
  const _WorkspaceLaneConnectionStrip({this.primaryAction, this.notice});

  final _WorkspaceLaneActionContract? primaryAction;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    final primaryAction = this.primaryAction;

    return DecoratedBox(
      key: const ValueKey<String>('lane_connection_status_strip'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.78),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (primaryAction != null)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.tonal(
                    key: primaryAction.key,
                    onPressed: primaryAction.onPressed,
                    child: Text(primaryAction.label),
                  ),
                ],
              ),
            if (notice != null) ...[const SizedBox(height: 12), notice!],
          ],
        ),
      ),
    );
  }
}
