import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_presentation.dart';

class ConnectionLifecycleButtonAction {
  const ConnectionLifecycleButtonAction({
    required this.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isDestructive = false,
    this.isInProgress = false,
  });

  final Key key;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDestructive;
  final bool isInProgress;
}

class ConnectionLifecycleSection extends StatelessWidget {
  const ConnectionLifecycleSection({
    super.key,
    required this.sectionId,
    required this.title,
    required this.count,
    required this.children,
  });

  final ConnectionLifecycleSectionId sectionId;
  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: ValueKey<String>('connections_section_${sectionId.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PocketTintBadge(
                label: '$count',
                color: theme.colorScheme.primary,
                backgroundOpacity: 0.14,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class ConnectionLifecycleFacts extends StatelessWidget {
  const ConnectionLifecycleFacts({super.key, required this.facts});

  final List<ConnectionLifecycleFact> facts;

  @override
  Widget build(BuildContext context) {
    if (facts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 14,
      runSpacing: 10,
      children: [
        for (final fact in facts) _ConnectionLifecycleFactMarker(fact: fact),
      ],
    );
  }
}

class _ConnectionLifecycleFactMarker extends StatelessWidget {
  const _ConnectionLifecycleFactMarker({required this.fact});

  final ConnectionLifecycleFact fact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _colorForFactTone(theme, fact.tone);

    return Tooltip(
      message: fact.label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(fact.icon, size: 14, color: color),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fact.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _colorForFactTone(ThemeData theme, ConnectionLifecycleFactTone tone) {
  return switch (tone) {
    ConnectionLifecycleFactTone.accent => theme.colorScheme.primary,
    ConnectionLifecycleFactTone.positive => theme.colorScheme.secondary,
    ConnectionLifecycleFactTone.warning => theme.colorScheme.tertiary,
    ConnectionLifecycleFactTone.neutral => theme.colorScheme.onSurfaceVariant,
  };
}

class ConnectionLifecycleActionBar extends StatelessWidget {
  const ConnectionLifecycleActionBar({
    super.key,
    this.primaryAction,
    this.secondaryActions = const <ConnectionLifecycleButtonAction>[],
    this.overflowActions = const <ConnectionLifecycleButtonAction>[],
    this.overflowMenuKey,
  });

  final ConnectionLifecycleButtonAction? primaryAction;
  final List<ConnectionLifecycleButtonAction> secondaryActions;
  final List<ConnectionLifecycleButtonAction> overflowActions;
  final Key? overflowMenuKey;

  @override
  Widget build(BuildContext context) {
    final primaryAction = this.primaryAction;
    if (primaryAction == null &&
        secondaryActions.isEmpty &&
        overflowActions.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleActions = <ConnectionLifecycleButtonAction>[
      if (primaryAction != null) primaryAction,
      ...secondaryActions,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        for (final action in visibleActions)
          _ConnectionLifecycleActionButton(
            action: action,
            isPrimary: identical(action, primaryAction),
          ),
        if (overflowActions.isNotEmpty)
          _ConnectionLifecycleOverflowMenu(
            actions: overflowActions,
            menuKey: overflowMenuKey,
          ),
      ],
    );
  }
}

class _ConnectionLifecycleActionButton extends StatelessWidget {
  const _ConnectionLifecycleActionButton({
    required this.action,
    required this.isPrimary,
  });

  final ConnectionLifecycleButtonAction action;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = action.isInProgress
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                isPrimary
                    ? theme.colorScheme.onPrimary
                    : action.isDestructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
          )
        : Icon(action.icon);

    if (isPrimary) {
      return IconButton.filled(
        key: action.key,
        onPressed: action.onPressed,
        tooltip: action.label,
        icon: icon,
      );
    }

    return IconButton.outlined(
      key: action.key,
      onPressed: action.onPressed,
      tooltip: action.label,
      style: action.isDestructive
          ? IconButton.styleFrom(foregroundColor: theme.colorScheme.error)
          : null,
      icon: icon,
    );
  }
}

class _ConnectionLifecycleOverflowMenu extends StatelessWidget {
  const _ConnectionLifecycleOverflowMenu({required this.actions, this.menuKey});

  final List<ConnectionLifecycleButtonAction> actions;
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    final regularActions = actions
        .where((action) => !action.isDestructive)
        .toList(growable: false);
    final destructiveActions = actions
        .where((action) => action.isDestructive)
        .toList(growable: false);

    return PopupMenuButton<ConnectionLifecycleButtonAction>(
      key: menuKey,
      tooltip: ConnectionWorkspaceCopy.moreRowActionsAction,
      onSelected: (action) => action.onPressed?.call(),
      itemBuilder: (context) =>
          <PopupMenuEntry<ConnectionLifecycleButtonAction>>[
            ...regularActions.map((action) => _buildMenuItem(context, action)),
            if (regularActions.isNotEmpty && destructiveActions.isNotEmpty)
              const PopupMenuDivider(),
            ...destructiveActions.map(
              (action) => _buildMenuItem(context, action),
            ),
          ],
      icon: const Icon(Icons.more_horiz_rounded),
    );
  }

  PopupMenuItem<ConnectionLifecycleButtonAction> _buildMenuItem(
    BuildContext context,
    ConnectionLifecycleButtonAction action,
  ) {
    final theme = Theme.of(context);
    final color = action.isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return PopupMenuItem<ConnectionLifecycleButtonAction>(
      key: action.key,
      value: action,
      enabled: action.onPressed != null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          action.isInProgress
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              : Icon(action.icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            action.label,
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class ConnectionLifecycleRow extends StatelessWidget {
  const ConnectionLifecycleRow({
    super.key,
    required this.rowKey,
    required this.title,
    required this.subtitle,
    required this.facts,
    this.primaryAction,
    this.secondaryActions = const <ConnectionLifecycleButtonAction>[],
    this.overflowActions = const <ConnectionLifecycleButtonAction>[],
    this.overflowMenuKey,
  });

  final Key rowKey;
  final String title;
  final String subtitle;
  final List<ConnectionLifecycleFact> facts;
  final ConnectionLifecycleButtonAction? primaryAction;
  final List<ConnectionLifecycleButtonAction> secondaryActions;
  final List<ConnectionLifecycleButtonAction> overflowActions;
  final Key? overflowMenuKey;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return SizedBox(
      key: rowKey,
      width: double.infinity,
      child: PocketPanelSurface(
        backgroundColor: palette.surface.withValues(alpha: 0.9),
        borderColor: palette.surfaceBorder,
        padding: PocketSpacing.panelPadding,
        radius: 12,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
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
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 12),
              ConnectionLifecycleFacts(facts: facts),
            ],
            if (primaryAction != null ||
                secondaryActions.isNotEmpty ||
                overflowActions.isNotEmpty) ...[
              const SizedBox(height: 14),
              ConnectionLifecycleActionBar(
                primaryAction: primaryAction,
                secondaryActions: secondaryActions,
                overflowActions: overflowActions,
                overflowMenuKey: overflowMenuKey,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
