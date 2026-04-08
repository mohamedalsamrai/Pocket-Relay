part of 'workspace_desktop_shell.dart';

class _MaterialDesktopSidebar extends StatelessWidget {
  const _MaterialDesktopSidebar({
    required this.workspaceController,
    required this.state,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.openingConnectionIds,
    required this.onOpenConnection,
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionWorkspaceState state;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;
  final Set<String> openingConnectionIds;
  final Future<void> Function(String connectionId) onOpenConnection;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final listPadding = isCollapsed
        ? const EdgeInsets.fromLTRB(
            PocketSpacing.xs,
            PocketSpacing.lg,
            PocketSpacing.xs,
            PocketSpacing.md,
          )
        : const EdgeInsets.fromLTRB(
            PocketSpacing.lg,
            PocketSpacing.lg,
            PocketSpacing.lg,
            PocketSpacing.md,
          );
    final footerPadding = isCollapsed
        ? const EdgeInsets.fromLTRB(
            PocketSpacing.xs,
            0,
            PocketSpacing.xs,
            PocketSpacing.lg,
          )
        : const EdgeInsets.fromLTRB(
            PocketSpacing.lg,
            0,
            PocketSpacing.lg,
            PocketSpacing.xl,
          );

    return AnimatedContainer(
      key: const ValueKey('desktop_sidebar'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isCollapsed ? 76 : 304,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.82),
        border: Border(right: BorderSide(color: palette.surfaceBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: listPadding,
                children: isCollapsed
                    ? _buildCollapsedChildren(context)
                    : _buildExpandedChildren(context),
              ),
            ),
            Padding(
              padding: footerPadding,
              child: Column(
                children: [
                  _MaterialSavedConnectionsSidebarRow(
                    isSelected: state.isShowingSavedConnections,
                    isCollapsed: isCollapsed,
                    onTap: workspaceController.showSavedConnections,
                  ),
                  const SizedBox(height: 10),
                  _MaterialSavedSystemsSidebarRow(
                    isSelected: state.isShowingSavedSystems,
                    isCollapsed: isCollapsed,
                    onTap: workspaceController.showSavedSystems,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
