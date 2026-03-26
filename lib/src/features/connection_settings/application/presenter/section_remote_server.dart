part of '../connection_settings_presenter.dart';

ConnectionSettingsRemoteServerSectionContract? _buildRemoteServerSection(
  _ConnectionSettingsPresentationState state, {
  required ConnectionRemoteRuntimeState? remoteRuntime,
  required bool supportsRemoteServerStart,
  required bool supportsRemoteServerStop,
  required bool supportsRemoteServerRestart,
  required ConnectionSettingsRemoteServerActionId? activeRemoteServerAction,
}) {
  if (!state.isRemote || remoteRuntime == null) {
    return null;
  }

  final hasUnsavedChanges = state.hasChanges;
  final canTriggerActions = !hasUnsavedChanges;
  final (statusLabel, detail) = switch (remoteRuntime.hostCapability.status) {
    ConnectionRemoteHostCapabilityStatus.checking => (
      'Checking host',
      'Pocket Relay is checking whether the remote host can support tmux-based continuity.',
    ),
    ConnectionRemoteHostCapabilityStatus.probeFailed => (
      'Host check failed',
      remoteRuntime.hostCapability.detail ??
          'Pocket Relay could not verify the remote host.',
    ),
    ConnectionRemoteHostCapabilityStatus.unsupported => (
      'Host unsupported',
      remoteRuntime.hostCapability.detail ??
          'This remote host does not satisfy the Pocket Relay continuity prerequisites.',
    ),
    _ => switch (remoteRuntime.server.status) {
      ConnectionRemoteServerStatus.checking => (
        'Server action in progress',
        remoteRuntime.server.detail ??
            'Pocket Relay is waiting for the remote server state to settle.',
      ),
      ConnectionRemoteServerStatus.notRunning => (
        'Server stopped',
        remoteRuntime.server.detail ??
            'No Pocket Relay server is running for this connection.',
      ),
      ConnectionRemoteServerStatus.unhealthy => (
        'Server unhealthy',
        remoteRuntime.server.detail ??
            'The Pocket Relay server exists but is not healthy enough to use.',
      ),
      ConnectionRemoteServerStatus.running => (
        'Server running',
        remoteRuntime.server.detail ??
            'The Pocket Relay server is running and ready.',
      ),
      ConnectionRemoteServerStatus.unknown => (
        'Server unknown',
        'Pocket Relay has not checked the remote server state yet.',
      ),
    },
  };

  final actions = <ConnectionSettingsRemoteServerActionContract>[
    ConnectionSettingsRemoteServerActionContract(
      id: ConnectionSettingsRemoteServerActionId.start,
      label: 'Start server',
      isVisible: supportsRemoteServerStart,
      isEnabled:
          supportsRemoteServerStart &&
          canTriggerActions &&
          remoteRuntime.hostCapability.isSupported &&
          remoteRuntime.server.status ==
              ConnectionRemoteServerStatus.notRunning,
      isInProgress:
          activeRemoteServerAction ==
          ConnectionSettingsRemoteServerActionId.start,
    ),
    ConnectionSettingsRemoteServerActionContract(
      id: ConnectionSettingsRemoteServerActionId.stop,
      label: 'Stop server',
      isVisible: supportsRemoteServerStop,
      isEnabled:
          supportsRemoteServerStop &&
          canTriggerActions &&
          remoteRuntime.hostCapability.isSupported &&
          (remoteRuntime.server.status ==
                  ConnectionRemoteServerStatus.running ||
              remoteRuntime.server.status ==
                  ConnectionRemoteServerStatus.unhealthy),
      isInProgress:
          activeRemoteServerAction ==
          ConnectionSettingsRemoteServerActionId.stop,
    ),
    ConnectionSettingsRemoteServerActionContract(
      id: ConnectionSettingsRemoteServerActionId.restart,
      label: 'Restart server',
      isVisible: supportsRemoteServerRestart,
      isEnabled:
          supportsRemoteServerRestart &&
          canTriggerActions &&
          remoteRuntime.hostCapability.isSupported &&
          (remoteRuntime.server.status ==
                  ConnectionRemoteServerStatus.running ||
              remoteRuntime.server.status ==
                  ConnectionRemoteServerStatus.unhealthy),
      isInProgress:
          activeRemoteServerAction ==
          ConnectionSettingsRemoteServerActionId.restart,
    ),
  ];

  final helperDetail = hasUnsavedChanges
      ? '$detail Save or discard staged connection edits before changing remote server lifetime.'
      : detail;

  return ConnectionSettingsRemoteServerSectionContract(
    title: 'Remote server',
    statusLabel: statusLabel,
    detail: helperDetail,
    actions: actions,
  );
}
