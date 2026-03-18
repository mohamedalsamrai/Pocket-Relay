import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';

class ConnectionWorkspaceDormantRosterContent extends StatefulWidget {
  const ConnectionWorkspaceDormantRosterContent({
    super.key,
    required this.workspaceController,
    required this.description,
    this.useSafeArea = true,
  });

  final ConnectionWorkspaceController workspaceController;
  final String description;
  final bool useSafeArea;

  @override
  State<ConnectionWorkspaceDormantRosterContent> createState() =>
      _ConnectionWorkspaceDormantRosterContentState();
}

class _ConnectionWorkspaceDormantRosterContentState
    extends State<ConnectionWorkspaceDormantRosterContent> {
  final Set<String> _instantiatingConnectionIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final dormantConnections = widget.workspaceController.state.catalog
        .orderedConnections
        .where(
          (connection) => widget.workspaceController.state.dormantConnectionIds
              .contains(connection.id),
        )
        .toList(growable: false);
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          'Dormant connections',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        if (dormantConnections.isEmpty)
          _DormantConnectionsEmptyState(onReturnToLane: _handleReturnToLiveLane)
        else
          ...dormantConnections.indexed.map((entry) {
            final index = entry.$1;
            final connection = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == dormantConnections.length - 1 ? 0 : 12,
              ),
              child: _DormantConnectionCard(
                connectionId: connection.id,
                title: connection.profile.label,
                subtitle: _connectionSubtitle(connection.profile),
                isOpening: _instantiatingConnectionIds.contains(connection.id),
                onOpen: () => _instantiateConnection(connection.id),
              ),
            );
          }),
      ],
    );

    return Material(
      type: MaterialType.transparency,
      child: ChatScreenGradientBackground(
        child: widget.useSafeArea
            ? SafeArea(bottom: false, child: content)
            : content,
      ),
    );
  }

  String _connectionSubtitle(ConnectionProfile profile) {
    return switch (profile.connectionMode) {
      ConnectionMode.remote => '${profile.host} · ${profile.workspaceDir}',
      ConnectionMode.local => 'local Codex · ${profile.workspaceDir}',
    };
  }

  Future<void> _instantiateConnection(String connectionId) async {
    if (_instantiatingConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() {
      _instantiatingConnectionIds.add(connectionId);
    });

    try {
      await widget.workspaceController.instantiateConnection(connectionId);
    } finally {
      if (mounted) {
        setState(() {
          _instantiatingConnectionIds.remove(connectionId);
        });
      }
    }
  }

  void _handleReturnToLiveLane() {
    final selectedConnectionId =
        widget.workspaceController.state.selectedConnectionId;
    if (selectedConnectionId == null) {
      return;
    }

    widget.workspaceController.selectConnection(selectedConnectionId);
  }
}

class _DormantConnectionsEmptyState extends StatelessWidget {
  const _DormantConnectionsEmptyState({required this.onReturnToLane});

  final VoidCallback onReturnToLane;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No dormant connections yet.',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All saved connections are already live. Return to a lane to keep working.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onReturnToLane,
              child: const Text('Return to lane'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DormantConnectionCard extends StatelessWidget {
  const _DormantConnectionCard({
    required this.connectionId,
    required this.title,
    required this.subtitle,
    required this.isOpening,
    required this.onOpen,
  });

  final String connectionId;
  final String title;
  final String subtitle;
  final bool isOpening;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return DecoratedBox(
      key: ValueKey<String>('dormant_connection_$connectionId'),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                key: ValueKey<String>('instantiate_$connectionId'),
                onPressed: isOpening ? null : onOpen,
                child: Text(isOpening ? 'Opening…' : 'Open lane'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
