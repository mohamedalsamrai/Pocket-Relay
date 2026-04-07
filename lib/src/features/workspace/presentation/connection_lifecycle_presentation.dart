import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

enum ConnectionLifecycleSectionId {
  openLanes,
  needsAttention,
  savedConnections,
}

enum ConnectionLifecycleFactTone { accent, neutral, positive, warning }

enum ConnectionLifecyclePrimaryActionId { openLane, goToLane, reconnect }

enum ConnectionLifecycleSecondaryActionId {
  disconnect,
  edit,
  closeLane,
  delete,
  checkHost,
  restartServer,
  stopServer,
}

@immutable
class ConnectionLifecycleFact {
  const ConnectionLifecycleFact({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final ConnectionLifecycleFactTone tone;
  final IconData icon;
}

@immutable
class ConnectionLifecyclePresentation {
  const ConnectionLifecyclePresentation({
    required this.sectionId,
    required this.connection,
    required this.subtitle,
    required this.facts,
    required this.primaryActionId,
    required this.secondaryActionIds,
    required this.overflowActionIds,
    required this.isLive,
    required this.isCurrent,
    required this.isAttention,
    required this.isTransportConnected,
    required this.reconnectRequirement,
    required this.transportRecoveryPhase,
    required this.liveReattachPhase,
    required this.remoteRuntime,
  });

  final ConnectionLifecycleSectionId sectionId;
  final SavedConnectionSummary connection;
  final String subtitle;
  final List<ConnectionLifecycleFact> facts;
  final ConnectionLifecyclePrimaryActionId? primaryActionId;
  final List<ConnectionLifecycleSecondaryActionId> secondaryActionIds;
  final List<ConnectionLifecycleSecondaryActionId> overflowActionIds;
  final bool isLive;
  final bool isCurrent;
  final bool isAttention;
  final bool isTransportConnected;
  final ConnectionWorkspaceReconnectRequirement? reconnectRequirement;
  final ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase;
  final ConnectionWorkspaceLiveReattachPhase? liveReattachPhase;
  final ConnectionRemoteRuntimeState? remoteRuntime;
}

@immutable
class ConnectionLifecycleSectionPresentation {
  const ConnectionLifecycleSectionPresentation({
    required this.id,
    required this.title,
    required this.rows,
  });

  final ConnectionLifecycleSectionId id;
  final String title;
  final List<ConnectionLifecyclePresentation> rows;
}

List<ConnectionLifecycleSectionPresentation>
connectionLifecycleSectionsFromState(
  ConnectionWorkspaceState state, {
  required bool Function(String connectionId) isTransportConnected,
}) {
  final currentLaneRows = <ConnectionLifecyclePresentation>[];
  final openLaneRows = <ConnectionLifecyclePresentation>[];
  final attentionRows = <ConnectionLifecyclePresentation>[];
  final savedRows = <ConnectionLifecyclePresentation>[];

  for (final connectionId in state.catalog.orderedConnectionIds) {
    final connection = state.catalog.connectionForId(connectionId);
    if (connection == null) {
      continue;
    }

    final row = _buildConnectionLifecyclePresentation(
      state,
      connection,
      isTransportConnected: isTransportConnected(connectionId),
    );
    switch (row.sectionId) {
      case ConnectionLifecycleSectionId.openLanes:
        if (row.isCurrent) {
          currentLaneRows.add(row);
        } else {
          openLaneRows.add(row);
        }
      case ConnectionLifecycleSectionId.needsAttention:
        attentionRows.add(row);
      case ConnectionLifecycleSectionId.savedConnections:
        savedRows.add(row);
    }
  }

  return <ConnectionLifecycleSectionPresentation>[
    if (currentLaneRows.isNotEmpty || openLaneRows.isNotEmpty)
      ConnectionLifecycleSectionPresentation(
        id: ConnectionLifecycleSectionId.openLanes,
        title: ConnectionWorkspaceCopy.openLanesSectionTitle,
        rows: <ConnectionLifecyclePresentation>[
          ...currentLaneRows,
          ...openLaneRows,
        ],
      ),
    if (attentionRows.isNotEmpty)
      ConnectionLifecycleSectionPresentation(
        id: ConnectionLifecycleSectionId.needsAttention,
        title: ConnectionWorkspaceCopy.needsAttentionSectionTitle,
        rows: attentionRows,
      ),
    if (savedRows.isNotEmpty)
      ConnectionLifecycleSectionPresentation(
        id: ConnectionLifecycleSectionId.savedConnections,
        title: ConnectionWorkspaceCopy.savedConnectionsTitle,
        rows: savedRows,
      ),
  ];
}

ConnectionLifecyclePresentation _buildConnectionLifecyclePresentation(
  ConnectionWorkspaceState state,
  SavedConnectionSummary connection, {
  required bool isTransportConnected,
}) {
  final connectionId = connection.id;
  final profile = connection.profile;
  final isLive = state.isConnectionLive(connectionId);
  final isCurrent = isLive && state.selectedConnectionId == connectionId;
  final reconnectRequirement = state.reconnectRequirementFor(connectionId);
  final transportRecoveryPhase = state.transportRecoveryPhaseFor(connectionId);
  final liveReattachPhase = state.liveReattachPhaseFor(connectionId);
  final remoteRuntime = state.remoteRuntimeFor(connectionId);
  final isAttention = _rowNeedsAttention(
    profile: profile,
    reconnectRequirement: reconnectRequirement,
    transportRecoveryPhase: transportRecoveryPhase,
    liveReattachPhase: liveReattachPhase,
  );

  final facts = <ConnectionLifecycleFact>[
    ConnectionLifecycleFact(
      label: ConnectionWorkspaceCopy.laneFactFor(isLive: isLive),
      tone: isLive
          ? ConnectionLifecycleFactTone.positive
          : ConnectionLifecycleFactTone.neutral,
      icon: isLive
          ? Icons.play_circle_fill_rounded
          : Icons.pause_circle_outline_rounded,
    ),
    if (!profile.isReady)
      const ConnectionLifecycleFact(
        label: ConnectionWorkspaceCopy.laneConfigurationIncompleteStatus,
        tone: ConnectionLifecycleFactTone.warning,
        icon: Icons.error_outline_rounded,
      ),
    if (profile.isRemote && isLive)
      ConnectionLifecycleFact(
        label: ConnectionWorkspaceCopy.transportFactFor(
          isConnected: isTransportConnected,
          transportRecoveryPhase: transportRecoveryPhase,
          liveReattachPhase: liveReattachPhase,
        ),
        tone:
            liveReattachPhase ==
                    ConnectionWorkspaceLiveReattachPhase.reconnecting ||
                transportRecoveryPhase ==
                    ConnectionWorkspaceTransportRecoveryPhase.reconnecting
            ? ConnectionLifecycleFactTone.warning
            : isTransportConnected
            ? ConnectionLifecycleFactTone.positive
            : ConnectionLifecycleFactTone.warning,
        icon:
            liveReattachPhase ==
                    ConnectionWorkspaceLiveReattachPhase.reconnecting ||
                transportRecoveryPhase ==
                    ConnectionWorkspaceTransportRecoveryPhase.reconnecting
            ? Icons.sync_rounded
            : isTransportConnected
            ? Icons.link_rounded
            : Icons.link_off_rounded,
      ),
    if (profile.isRemote &&
        remoteRuntime != null &&
        remoteRuntime.hostCapability.status ==
            ConnectionRemoteHostCapabilityStatus.supported)
      ConnectionLifecycleFact(
        label: ConnectionWorkspaceCopy.serverFactFor(
          remoteRuntime.server.status,
        ),
        tone: switch (remoteRuntime.server.status) {
          ConnectionRemoteServerStatus.running =>
            ConnectionLifecycleFactTone.positive,
          ConnectionRemoteServerStatus.checking =>
            ConnectionLifecycleFactTone.accent,
          ConnectionRemoteServerStatus.unknown =>
            ConnectionLifecycleFactTone.neutral,
          ConnectionRemoteServerStatus.notRunning ||
          ConnectionRemoteServerStatus.unhealthy =>
            ConnectionLifecycleFactTone.warning,
        },
        icon: switch (remoteRuntime.server.status) {
          ConnectionRemoteServerStatus.running => Icons.terminal_rounded,
          ConnectionRemoteServerStatus.checking => Icons.hourglass_top_rounded,
          ConnectionRemoteServerStatus.notRunning => Icons.stop_circle_outlined,
          ConnectionRemoteServerStatus.unhealthy => Icons.warning_amber_rounded,
          ConnectionRemoteServerStatus.unknown => Icons.help_outline_rounded,
        },
      ),
    if (reconnectRequirement ==
            ConnectionWorkspaceReconnectRequirement.savedSettings ||
        reconnectRequirement ==
            ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings)
      ConnectionLifecycleFact(
        label: ConnectionWorkspaceCopy.settingsFactFor(reconnectRequirement!),
        tone: ConnectionLifecycleFactTone.warning,
        icon: Icons.tune_rounded,
      ),
  ];

  final primaryActionId = reconnectRequirement != null
      ? ConnectionLifecyclePrimaryActionId.reconnect
      : isLive
      ? ConnectionLifecyclePrimaryActionId.goToLane
      : ConnectionLifecyclePrimaryActionId.openLane;
  final secondaryActionIds = <ConnectionLifecycleSecondaryActionId>[
    if (isLive && profile.isRemote && isTransportConnected)
      ConnectionLifecycleSecondaryActionId.disconnect,
    ConnectionLifecycleSecondaryActionId.edit,
  ];
  final overflowActionIds = <ConnectionLifecycleSecondaryActionId>[
    if (isLive)
      ConnectionLifecycleSecondaryActionId.closeLane
    else
      ConnectionLifecycleSecondaryActionId.delete,
    if (profile.isRemote && profile.isReady)
      ConnectionLifecycleSecondaryActionId.checkHost,
    if (profile.isRemote &&
        remoteRuntime?.hostCapability.status ==
            ConnectionRemoteHostCapabilityStatus.supported &&
        (remoteRuntime?.server.status == ConnectionRemoteServerStatus.running ||
            remoteRuntime?.server.status ==
                ConnectionRemoteServerStatus.unhealthy))
      ConnectionLifecycleSecondaryActionId.restartServer,
    if (profile.isRemote &&
        remoteRuntime?.hostCapability.status ==
            ConnectionRemoteHostCapabilityStatus.supported &&
        remoteRuntime?.server.status == ConnectionRemoteServerStatus.running)
      ConnectionLifecycleSecondaryActionId.stopServer,
  ];

  return ConnectionLifecyclePresentation(
    sectionId: _sectionIdForRow(isLive: isLive, isAttention: isAttention),
    connection: connection,
    subtitle: ConnectionWorkspaceCopy.connectionSubtitle(profile),
    facts: facts,
    primaryActionId: primaryActionId,
    secondaryActionIds: secondaryActionIds,
    overflowActionIds: overflowActionIds,
    isLive: isLive,
    isCurrent: isCurrent,
    isAttention: isAttention,
    isTransportConnected: isTransportConnected,
    reconnectRequirement: reconnectRequirement,
    transportRecoveryPhase: transportRecoveryPhase,
    liveReattachPhase: liveReattachPhase,
    remoteRuntime: remoteRuntime,
  );
}

ConnectionLifecycleSectionId _sectionIdForRow({
  required bool isLive,
  required bool isAttention,
}) {
  if (isAttention) {
    return ConnectionLifecycleSectionId.needsAttention;
  }
  if (isLive) {
    return ConnectionLifecycleSectionId.openLanes;
  }
  return ConnectionLifecycleSectionId.savedConnections;
}

bool _rowNeedsAttention({
  required ConnectionProfile profile,
  required ConnectionWorkspaceReconnectRequirement? reconnectRequirement,
  required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
  required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
}) {
  if (!profile.isReady) {
    return true;
  }
  if (reconnectRequirement != null ||
      transportRecoveryPhase != null ||
      _liveReattachPhaseNeedsAttention(liveReattachPhase)) {
    return true;
  }
  return false;
}

bool _liveReattachPhaseNeedsAttention(
  ConnectionWorkspaceLiveReattachPhase? phase,
) {
  return switch (phase) {
    null ||
    ConnectionWorkspaceLiveReattachPhase.liveReattached ||
    ConnectionWorkspaceLiveReattachPhase.fallbackRestore => false,
    _ => true,
  };
}
