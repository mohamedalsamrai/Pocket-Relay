part of 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

extension _ConnectionSettingsSheetStatus on ConnectionSettingsSheetSurface {
  Widget _buildRemoteStatusStrip(
    BuildContext context,
    ConnectionSettingsContract contract,
    ConnectionSettingsSectionStatusContract status,
  ) {
    final visuals = this._statusVisuals(context, contract.remoteRuntime);

    return this._buildInlineStatusStrip(
      context,
      status,
      icon: visuals.icon,
      color: visuals.color,
    );
  }

  Widget _buildInlineStatusStrip(
    BuildContext context,
    ConnectionSettingsSectionStatusContract status, {
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status.detail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({IconData icon, Color color}) _statusVisuals(
    BuildContext context,
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    final theme = Theme.of(context);
    if (remoteRuntime == null) {
      return (
        icon: Icons.info_outline,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    switch (remoteRuntime.hostCapability.status) {
      case ConnectionRemoteHostCapabilityStatus.checking:
        return (icon: Icons.sync, color: theme.colorScheme.primary);
      case ConnectionRemoteHostCapabilityStatus.probeFailed:
      case ConnectionRemoteHostCapabilityStatus.unsupported:
        return (icon: Icons.error_outline, color: theme.colorScheme.tertiary);
      case ConnectionRemoteHostCapabilityStatus.supported:
        break;
      case ConnectionRemoteHostCapabilityStatus.unknown:
        return (
          icon: Icons.help_outline,
          color: theme.colorScheme.onSurfaceVariant,
        );
    }

    return switch (remoteRuntime.server.status) {
      ConnectionRemoteServerStatus.running => (
        icon: Icons.check_circle_outline,
        color: theme.colorScheme.secondary,
      ),
      ConnectionRemoteServerStatus.checking => (
        icon: Icons.sync,
        color: theme.colorScheme.primary,
      ),
      ConnectionRemoteServerStatus.notRunning ||
      ConnectionRemoteServerStatus.unhealthy => (
        icon: Icons.warning_amber_rounded,
        color: theme.colorScheme.tertiary,
      ),
      ConnectionRemoteServerStatus.unknown => (
        icon: Icons.info_outline,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    };
  }

  Widget _buildSystemTrustPanel(
    BuildContext context,
    ConnectionSettingsSystemTrustContract trust,
  ) {
    final theme = Theme.of(context);
    final color = switch (trust.state) {
      ConnectionSettingsSystemTrustStateKind.ready =>
        theme.colorScheme.secondary,
      ConnectionSettingsSystemTrustStateKind.failed =>
        theme.colorScheme.tertiary,
      ConnectionSettingsSystemTrustStateKind.checking =>
        theme.colorScheme.primary,
      ConnectionSettingsSystemTrustStateKind.needsTest =>
        theme.colorScheme.onSurfaceVariant,
    };
    final icon = switch (trust.state) {
      ConnectionSettingsSystemTrustStateKind.ready => Icons.verified_outlined,
      ConnectionSettingsSystemTrustStateKind.failed => Icons.error_outline,
      ConnectionSettingsSystemTrustStateKind.checking => Icons.sync,
      ConnectionSettingsSystemTrustStateKind.needsTest => Icons.shield_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trust.statusLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    trust.detail,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (trust.fingerprint case final fingerprint?) ...[
          const SizedBox(height: 12),
          SelectableText(
            fingerprint,
            key: const ValueKey<String>(
              'connection_settings_system_fingerprint',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          key: const ValueKey<String>('connection_settings_test_system'),
          onPressed: trust.isActionEnabled ? actions.onTestSystem : null,
          icon: trust.isActionInProgress
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.router_outlined),
          label: Text(trust.actionLabel),
        ),
      ],
    );
  }
}
