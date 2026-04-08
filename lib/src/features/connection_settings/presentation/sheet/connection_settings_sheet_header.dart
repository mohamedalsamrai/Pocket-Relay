part of 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

extension _ConnectionSettingsSheetHeader on ConnectionSettingsSheetSurface {
  Widget _buildHeaderContent(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool isDesktop,
  }) {
    final theme = Theme.of(context);
    final summary = this._summaryTextFor(contract);
    final badges = this._buildHeaderBadges(context, contract);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          surfaceMode == ConnectionSettingsSurfaceMode.system
              ? 'System'
              : contract.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: isDesktop ? 30 : 24,
          ),
        ),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            summary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: badges),
        ],
      ],
    );
  }

  List<Widget> _buildHeaderBadges(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final theme = Theme.of(context);

    return <Widget>[
      if (contract.saveAction.hasChanges)
        this._buildHeaderBadge(
          context,
          label: 'Unsaved changes',
          icon: Icons.edit_outlined,
          foregroundColor: theme.colorScheme.tertiary,
          backgroundColor: theme.colorScheme.tertiary.withValues(alpha: 0.14),
        ),
    ];
  }

  Widget _buildHeaderBadge(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color foregroundColor,
    required Color backgroundColor,
  }) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
