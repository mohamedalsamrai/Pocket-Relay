import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

abstract final class ConnectionWorkspaceCopy {
  static const String workspaceTitle = 'Connections';
  static const String openLanesSectionTitle = 'Open lanes';
  static const String savedSectionTitle = 'Saved';
  static const String savedConnectionsTitle = 'Saved connections';
  static const String savedConnectionsMenuLabel = savedConnectionsTitle;
  static const String conversationHistoryMenuLabel = 'Conversation history';
  static const String mobileSavedConnectionsDescription =
      'Jump back to an open lane or open another saved connection.';
  static const String desktopSidebarDescription =
      'Keep multiple lanes open while every saved connection stays visible in one inventory.';
  static const String desktopSavedConnectionsDescription =
      'Open another saved connection or jump back to a lane that is already open.';
  static const String addConnectionAction = 'Add connection';
  static const String addConnectionProgress = 'Adding…';
  static const String openLaneAction = 'Open lane';
  static const String goToLaneAction = 'Go to lane';
  static const String openingLaneAction = 'Opening…';
  static const String editAction = 'Edit';
  static const String saveProgress = 'Saving…';
  static const String deleteAction = 'Delete';
  static const String deleteProgress = 'Deleting…';
  static const String startServerAction = 'Start server';
  static const String startServerProgress = 'Starting…';
  static const String stopServerAction = 'Stop server';
  static const String stopServerProgress = 'Stopping…';
  static const String restartServerAction = 'Restart server';
  static const String restartServerProgress = 'Restarting…';
  static const String closeLaneAction = 'Close lane';
  static const String openConnectionBadge = 'Open';
  static const String currentConnectionBadge = 'Current';
  static const String savedSettingsReconnectBadge = 'Changes pending';
  static const String savedSettingsReconnectAction = 'Apply changes';
  static const String savedSettingsReconnectProgress = 'Applying changes…';
  static const String savedSettingsReconnectMenuAction = 'Apply saved settings';
  static const String savedSettingsReconnectMenuProgress =
      'Applying saved settings…';
  static const String transportReconnectBadge = 'Reconnect needed';
  static const String transportReconnectAction = 'Reconnect';
  static const String transportReconnectProgress = 'Reconnecting…';
  static const String transportReconnectMenuAction = 'Reconnect lane';
  static const String transportReconnectMenuProgress = 'Reconnecting lane…';
  static const String transportLostNoticeTitle = 'Live transport lost';
  static const String transportLostNoticeMessage =
      'Pocket Relay lost the live connection to Codex. Your draft is preserved below until the lane reconnects.';
  static const String reconnectingNoticeTitle =
      'Reconnecting to remote session';
  static const String reconnectingNoticeMessage =
      'Pocket Relay is reconnecting this lane to Codex before it can continue. Your draft is preserved below.';
  static const String transportUnavailableNoticeTitle =
      'Remote session unavailable';
  static const String transportUnavailableNoticeMessage =
      'Pocket Relay could not reconnect this lane to Codex. Your draft is preserved below. Try reconnecting again.';
  static const String remoteContinuityUnavailableNoticeTitle =
      'Remote continuity unavailable';
  static const String remoteContinuityUnavailableNoticeMessage =
      'This host does not currently satisfy Pocket Relay continuity requirements. Verify SSH access, tmux, and codex, then reconnect this lane.';
  static const String remoteServerStoppedNoticeTitle = 'Remote server stopped';
  static const String remoteServerStoppedNoticeMessage =
      'The Pocket Relay server for this connection is not running. Start it from saved connections, then reconnect this lane.';
  static const String remoteServerUnhealthyNoticeTitle =
      'Remote server unhealthy';
  static const String remoteServerUnhealthyNoticeMessage =
      'The Pocket Relay server exists but is not healthy enough to accept connections. Restart it from saved connections, then reconnect this lane.';
  static const String restoringConversationNoticeTitle =
      'Restoring conversation';
  static const String restoringConversationNoticeMessage =
      'Pocket Relay is restoring this transcript from Codex after live reattach could not continue directly. Your draft is preserved below.';
  static const String remoteServerRunningSummary = 'Server running';
  static const String remoteServerStoppedSummary = 'Server stopped';
  static const String remoteServerUnhealthySummary = 'Server unhealthy';
  static const String remoteHostUnsupportedSummary = 'Host unsupported';
  static const String remoteHostProbeFailedSummary = 'Host check failed';
  static const String remoteHostCheckingSummary = 'Checking host';
  static const String remoteServerCheckingSummary = 'Checking server';
  static const String collapseSidebarAction = 'Collapse sidebar';
  static const String expandSidebarAction = 'Expand sidebar';
  static const String workspaceNotSet = 'Workspace not set';
  static const String hostNotSet = 'Host not set';
  static const String remoteConnectionNotConfigured =
      'Remote connection not configured';
  static const String emptyWorkspaceTitle = 'No saved connections yet.';
  static const String emptyWorkspaceMessage =
      'Add your first connection to open a new lane.';
  static String connectionSubtitle(ConnectionProfile profile) {
    final host = profile.host.trim();
    final workspaceDir = profile.workspaceDir.trim();

    return switch (profile.connectionMode) {
      ConnectionMode.remote when host.isNotEmpty && workspaceDir.isNotEmpty =>
        '$host · $workspaceDir',
      ConnectionMode.remote when host.isNotEmpty => '$host · $workspaceNotSet',
      ConnectionMode.remote when workspaceDir.isNotEmpty =>
        '$hostNotSet · $workspaceDir',
      ConnectionMode.remote => remoteConnectionNotConfigured,
      ConnectionMode.local when workspaceDir.isNotEmpty =>
        'Local Codex · $workspaceDir',
      ConnectionMode.local => 'Local Codex · $workspaceNotSet',
    };
  }

  static String compactSavedConnectionLabel(ConnectionProfile profile) {
    final host = profile.host.trim();
    final workspaceDir = profile.workspaceDir.trim();

    return switch (profile.connectionMode) {
      ConnectionMode.remote when host.isNotEmpty => host,
      ConnectionMode.remote when workspaceDir.isNotEmpty => hostNotSet,
      ConnectionMode.remote => remoteConnectionNotConfigured,
      ConnectionMode.local when workspaceDir.isNotEmpty => 'Local Codex',
      ConnectionMode.local => workspaceNotSet,
    };
  }

  static String reconnectBadgeFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectBadge,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectBadge,
    };
  }

  static String reconnectActionFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectAction,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectAction,
    };
  }

  static String reconnectProgressFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectProgress,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectProgress,
    };
  }

  static String reconnectMenuActionFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectMenuAction,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectMenuAction,
    };
  }

  static String reconnectMenuProgressFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectMenuProgress,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectMenuProgress,
    };
  }

  static String? savedConnectionRemoteStatusSummary(
    ConnectionProfile profile,
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    if (profile.connectionMode == ConnectionMode.local ||
        remoteRuntime == null) {
      return null;
    }

    return switch (remoteRuntime.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.checking =>
        remoteHostCheckingSummary,
      ConnectionRemoteHostCapabilityStatus.probeFailed =>
        remoteHostProbeFailedSummary,
      ConnectionRemoteHostCapabilityStatus.unsupported =>
        remoteHostUnsupportedSummary,
      ConnectionRemoteHostCapabilityStatus.unknown => null,
      ConnectionRemoteHostCapabilityStatus.supported => switch (remoteRuntime
          .server
          .status) {
        ConnectionRemoteServerStatus.checking => remoteServerCheckingSummary,
        ConnectionRemoteServerStatus.notRunning => remoteServerStoppedSummary,
        ConnectionRemoteServerStatus.unhealthy => remoteServerUnhealthySummary,
        ConnectionRemoteServerStatus.running => remoteServerRunningSummary,
        ConnectionRemoteServerStatus.unknown => null,
      },
    };
  }

  static String remoteServerActionLabel(
    ConnectionSettingsRemoteServerActionId actionId,
  ) {
    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start => startServerAction,
      ConnectionSettingsRemoteServerActionId.stop => stopServerAction,
      ConnectionSettingsRemoteServerActionId.restart => restartServerAction,
    };
  }

  static String remoteServerActionProgressLabel(
    ConnectionSettingsRemoteServerActionId actionId,
  ) {
    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start => startServerProgress,
      ConnectionSettingsRemoteServerActionId.stop => stopServerProgress,
      ConnectionSettingsRemoteServerActionId.restart => restartServerProgress,
    };
  }

  static String openConnectionFailureMessage({
    required ConnectionProfile profile,
    ConnectionRemoteRuntimeState? remoteRuntime,
    Object? error,
  }) {
    final runtimeDetail = _remoteRuntimeFailureDetail(remoteRuntime);
    if (runtimeDetail != null) {
      return 'Could not open lane. $runtimeDetail';
    }

    final errorDetail = _normalizedErrorDetail(error);
    if (errorDetail != null) {
      return 'Could not open lane. $errorDetail';
    }

    return switch (profile.connectionMode) {
      ConnectionMode.remote =>
        'Could not open lane. Verify the saved connection and remote Pocket Relay server, then try again.',
      ConnectionMode.local =>
        'Could not open lane. Verify the saved connection, then try again.',
    };
  }

  static String remoteServerActionFailureMessage(
    ConnectionSettingsRemoteServerActionId actionId, {
    ConnectionRemoteRuntimeState? remoteRuntime,
    Object? error,
  }) {
    final actionLabel = remoteServerActionLabel(actionId);
    final runtimeDetail = _remoteRuntimeFailureDetail(remoteRuntime);
    if (runtimeDetail != null) {
      return 'Could not ${actionLabel.toLowerCase()}. $runtimeDetail';
    }

    final errorDetail = _normalizedErrorDetail(error);
    if (errorDetail != null) {
      return 'Could not ${actionLabel.toLowerCase()}. $errorDetail';
    }

    return 'Could not ${actionLabel.toLowerCase()}.';
  }

  static String? _remoteRuntimeFailureDetail(
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    if (remoteRuntime == null) {
      return null;
    }

    return switch (remoteRuntime.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.checking =>
        'Pocket Relay is still checking the remote host.',
      ConnectionRemoteHostCapabilityStatus.probeFailed =>
        remoteRuntime.hostCapability.detail ??
            'Pocket Relay could not verify the remote host.',
      ConnectionRemoteHostCapabilityStatus.unsupported =>
        remoteRuntime.hostCapability.detail ??
            'This remote host does not satisfy Pocket Relay continuity requirements.',
      ConnectionRemoteHostCapabilityStatus.unknown => switch (remoteRuntime
          .server
          .status) {
        ConnectionRemoteServerStatus.checking =>
          remoteRuntime.server.detail ??
              'Pocket Relay is still checking the remote server.',
        ConnectionRemoteServerStatus.notRunning =>
          remoteRuntime.server.detail ??
              'The remote Pocket Relay server is still stopped.',
        ConnectionRemoteServerStatus.unhealthy =>
          remoteRuntime.server.detail ??
              'The remote Pocket Relay server is still unhealthy.',
        ConnectionRemoteServerStatus.running =>
          remoteRuntime.server.detail ??
              'The remote Pocket Relay server is running but the lane could not attach.',
        ConnectionRemoteServerStatus.unknown => null,
      },
      ConnectionRemoteHostCapabilityStatus.supported => switch (remoteRuntime
          .server
          .status) {
        ConnectionRemoteServerStatus.checking =>
          remoteRuntime.server.detail ??
              'Pocket Relay is still checking the remote server.',
        ConnectionRemoteServerStatus.notRunning =>
          remoteRuntime.server.detail ??
              'The remote Pocket Relay server is still stopped.',
        ConnectionRemoteServerStatus.unhealthy =>
          remoteRuntime.server.detail ??
              'The remote Pocket Relay server is still unhealthy.',
        ConnectionRemoteServerStatus.running =>
          remoteRuntime.server.detail ??
              'The remote Pocket Relay server is running but the lane could not attach.',
        ConnectionRemoteServerStatus.unknown => null,
      },
    };
  }

  static String? _normalizedErrorDetail(Object? error) {
    if (error == null) {
      return null;
    }

    final detail = '$error'.trim();
    if (detail.isEmpty) {
      return null;
    }

    return switch (detail) {
      final value when value.startsWith('Exception: ') => value.substring(
        'Exception: '.length,
      ),
      final value when value.startsWith('Bad state: ') => value.substring(
        'Bad state: '.length,
      ),
      _ => detail,
    };
  }
}
