import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_dormant_roster_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart';

import 'connection_workspace_settings_renderer.dart';

class ConnectionWorkspaceDesktopShell extends StatelessWidget {
  const ConnectionWorkspaceDesktopShell({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: workspaceController,
      builder: (context, _) {
        final state = workspaceController.state;
        final selectedLaneBinding = workspaceController.selectedLaneBinding;
        final theme = Theme.of(context);
        final palette = context.pocketPalette;

        return Scaffold(
          backgroundColor: palette.backgroundTop,
          body: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.82),
                  border: Border(
                    right: BorderSide(color: palette.surfaceBorder),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: SizedBox(
                    width: 304,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
                      children: [
                        Text(
                          ConnectionWorkspaceCopy.workspaceTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ConnectionWorkspaceCopy.desktopSidebarDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 22),
                        _SidebarSectionTitle(
                          title: ConnectionWorkspaceCopy.openLanesSectionTitle,
                          trailingCount: state.liveConnectionIds.length,
                        ),
                        const SizedBox(height: 10),
                        ...state.liveConnectionIds.indexed.map((entry) {
                          final index = entry.$1;
                          final connectionId = entry.$2;
                          final laneBinding = workspaceController
                              .bindingForConnectionId(connectionId);
                          final liveProfile =
                              laneBinding?.sessionController.profile;
                          if (liveProfile == null) {
                            return const SizedBox.shrink();
                          }
                          final summary = state.catalog.connectionForId(
                            connectionId,
                          );
                          if (summary == null) {
                            return const SizedBox.shrink();
                          }

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom:
                                  index == state.liveConnectionIds.length - 1
                                  ? 0
                                  : 10,
                            ),
                            child: _SidebarConnectionRow(
                              connectionId: connectionId,
                              title: liveProfile.label,
                              subtitle: _connectionSubtitle(liveProfile),
                              requiresReconnect: state.requiresReconnect(
                                connectionId,
                              ),
                              isSelected:
                                  state.isShowingLiveLane &&
                                  state.selectedConnectionId == connectionId,
                              onTap: () => workspaceController.selectConnection(
                                connectionId,
                              ),
                              onClose: () => workspaceController
                                  .terminateConnection(connectionId),
                            ),
                          );
                        }),
                        const SizedBox(height: 22),
                        _SidebarSectionTitle(
                          title: ConnectionWorkspaceCopy.savedSectionTitle,
                          trailingCount: state.dormantConnectionIds.length,
                        ),
                        const SizedBox(height: 10),
                        _DormantRosterSidebarRow(
                          isSelected: state.isShowingDormantRoster,
                          onTap: workspaceController.showDormantRoster,
                        ),
                        if (state.dormantConnectionIds.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ...state.dormantConnectionIds.indexed.map((entry) {
                            final index = entry.$1;
                            final connectionId = entry.$2;
                            final summary = state.catalog.connectionForId(
                              connectionId,
                            );
                            if (summary == null) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: EdgeInsets.only(
                                left: 12,
                                top: index == 0 ? 0 : 8,
                              ),
                              child: Text(
                                '${summary.profile.label} · ${summary.profile.workspaceDir}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: switch ((
                  state.isShowingDormantRoster,
                  selectedLaneBinding,
                )) {
                  (true, _) => ConnectionWorkspaceDormantRosterContent(
                    workspaceController: workspaceController,
                    description: ConnectionWorkspaceCopy
                        .desktopSavedConnectionsDescription,
                    platformBehavior: platformPolicy.behavior,
                    settingsRenderer: connectionSettingsRendererFor(
                      platformPolicy,
                    ),
                    settingsOverlayDelegate: settingsOverlayDelegate,
                    useSafeArea: true,
                    visualStyle: ConnectionWorkspaceRosterStyle.material,
                  ),
                  (false, final laneBinding?) =>
                    ConnectionWorkspaceLiveLaneSurface(
                      workspaceController: workspaceController,
                      laneBinding: laneBinding,
                      platformPolicy: platformPolicy,
                      settingsOverlayDelegate: settingsOverlayDelegate,
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _connectionSubtitle(ConnectionProfile profile) {
    return switch (profile.connectionMode) {
      ConnectionMode.remote => '${profile.host} · ${profile.workspaceDir}',
      ConnectionMode.local => 'local Codex · ${profile.workspaceDir}',
    };
  }
}

class _SidebarSectionTitle extends StatelessWidget {
  const _SidebarSectionTitle({
    required this.title,
    required this.trailingCount,
  });

  final String title;
  final int trailingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.subtleSurface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.surfaceBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '$trailingCount',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarConnectionRow extends StatelessWidget {
  const _SidebarConnectionRow({
    required this.connectionId,
    required this.title,
    required this.subtitle,
    required this.requiresReconnect,
    required this.isSelected,
    required this.onTap,
    required this.onClose,
  });

  final String connectionId;
  final String title;
  final String subtitle;
  final bool requiresReconnect;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : palette.surface.withValues(alpha: 0.72);
    final borderColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.36)
        : palette.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey<String>('desktop_live_$connectionId'),
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (requiresReconnect) ...[
                        const SizedBox(height: 8),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text(
                              ConnectionWorkspaceCopy.reconnectBadge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Tooltip(
              message: ConnectionWorkspaceCopy.closeLaneAction,
              child: IconButton(
                key: ValueKey<String>('desktop_close_lane_$connectionId'),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                color: theme.colorScheme.onSurfaceVariant,
                icon: const Icon(Icons.close),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _DormantRosterSidebarRow extends StatelessWidget {
  const _DormantRosterSidebarRow({
    required this.isSelected,
    required this.onTap,
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : palette.subtleSurface.withValues(alpha: 0.8);
    final borderColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.36)
        : palette.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('desktop_dormant_roster'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ConnectionWorkspaceCopy.savedConnectionsTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
