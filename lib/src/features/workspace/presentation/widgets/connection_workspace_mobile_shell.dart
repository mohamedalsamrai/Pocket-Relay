import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/workspace/models/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';

class ConnectionWorkspaceMobileShell extends StatefulWidget {
  const ConnectionWorkspaceMobileShell({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;

  @override
  State<ConnectionWorkspaceMobileShell> createState() =>
      _ConnectionWorkspaceMobileShellState();
}

class _ConnectionWorkspaceMobileShellState
    extends State<ConnectionWorkspaceMobileShell> {
  late PageController _pageController;
  late int _currentPageIndex;
  int? _scheduledTargetPage;

  @override
  void initState() {
    super.initState();
    _currentPageIndex = _targetPageIndex(widget.workspaceController.state);
    _pageController = PageController(initialPage: _currentPageIndex);
  }

  @override
  void didUpdateWidget(covariant ConnectionWorkspaceMobileShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceController == widget.workspaceController) {
      return;
    }

    _pageController.dispose();
    _currentPageIndex = _targetPageIndex(widget.workspaceController.state);
    _pageController = PageController(initialPage: _currentPageIndex);
    _scheduledTargetPage = null;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.workspaceController,
      builder: (context, _) {
        final state = widget.workspaceController.state;
        final liveConnectionIds = state.liveConnectionIds;
        final targetPageIndex = _targetPageIndex(state);
        _syncPageController(targetPageIndex);

        return PageView(
          key: const ValueKey('workspace_page_view'),
          controller: _pageController,
          onPageChanged: (index) =>
              _handlePageChanged(index, liveConnectionIds: liveConnectionIds),
          children: <Widget>[
            for (final connectionId in liveConnectionIds)
              _ConnectionWorkspaceLanePageHost(
                key: ValueKey<String>('lane_page_$connectionId'),
                child: _buildLanePage(connectionId),
              ),
            _ConnectionWorkspaceDormantRosterPage(
              key: const ValueKey('dormant_roster_page'),
              workspaceController: widget.workspaceController,
              platformPolicy: widget.platformPolicy,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanePage(String connectionId) {
    final laneBinding = widget.workspaceController.bindingForConnectionId(
      connectionId,
    );
    if (laneBinding == null) {
      return const SizedBox.shrink();
    }

    return ChatRootAdapter(
      laneBinding: laneBinding,
      platformPolicy: widget.platformPolicy,
      supplementalMenuActions: <ChatChromeMenuAction>[
        ChatChromeMenuAction(
          label: 'Dormant connections',
          onSelected: widget.workspaceController.showDormantRoster,
        ),
      ],
    );
  }

  void _handlePageChanged(
    int index, {
    required List<String> liveConnectionIds,
  }) {
    _currentPageIndex = index;
    _scheduledTargetPage = index;
    if (index >= liveConnectionIds.length) {
      widget.workspaceController.showDormantRoster();
      return;
    }

    widget.workspaceController.selectConnection(liveConnectionIds[index]);
  }

  int _targetPageIndex(ConnectionWorkspaceState state) {
    if (state.isShowingDormantRoster || state.selectedConnectionId == null) {
      return state.liveConnectionIds.length;
    }

    final selectedIndex = state.liveConnectionIds.indexOf(
      state.selectedConnectionId!,
    );
    return selectedIndex == -1 ? state.liveConnectionIds.length : selectedIndex;
  }

  void _syncPageController(int targetPageIndex) {
    if (_scheduledTargetPage == targetPageIndex) {
      return;
    }
    _scheduledTargetPage = targetPageIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      final currentPage = (_pageController.page ?? _currentPageIndex.toDouble())
          .round();
      if (currentPage == targetPageIndex) {
        _currentPageIndex = targetPageIndex;
        return;
      }

      _currentPageIndex = targetPageIndex;
      unawaited(
        _pageController.animateToPage(
          targetPageIndex,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }
}

class _ConnectionWorkspaceLanePageHost extends StatefulWidget {
  const _ConnectionWorkspaceLanePageHost({super.key, required this.child});

  final Widget child;

  @override
  State<_ConnectionWorkspaceLanePageHost> createState() =>
      _ConnectionWorkspaceLanePageHostState();
}

class _ConnectionWorkspaceLanePageHostState
    extends State<_ConnectionWorkspaceLanePageHost>
    with AutomaticKeepAliveClientMixin<_ConnectionWorkspaceLanePageHost> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _ConnectionWorkspaceDormantRosterPage extends StatefulWidget {
  const _ConnectionWorkspaceDormantRosterPage({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;

  @override
  State<_ConnectionWorkspaceDormantRosterPage> createState() =>
      _ConnectionWorkspaceDormantRosterPageState();
}

class _ConnectionWorkspaceDormantRosterPageState
    extends State<_ConnectionWorkspaceDormantRosterPage> {
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

    final body = Material(
      type: MaterialType.transparency,
      child: ChatScreenGradientBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
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
                'Swipe back to a live lane or open another saved connection.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              if (dormantConnections.isEmpty)
                _DormantConnectionsEmptyState(
                  onReturnToLane: _handleReturnToLiveLane,
                )
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
                      isOpening: _instantiatingConnectionIds.contains(
                        connection.id,
                      ),
                      onOpen: () => _instantiateConnection(connection.id),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );

    return switch (widget.platformPolicy.regionPolicy.screenShell) {
      ChatRootScreenShellRenderer.flutter => Scaffold(body: body),
      ChatRootScreenShellRenderer.cupertino => CupertinoTheme(
        data: buildPocketCupertinoTheme(Theme.of(context)),
        child: CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            transitionBetweenRoutes: false,
            automaticallyImplyLeading: false,
            automaticBackgroundVisibility: false,
            middle: Text('Dormant connections'),
          ),
          child: body,
        ),
      ),
    };
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
              'All saved connections are already live. Swipe back to a lane to keep working.',
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
