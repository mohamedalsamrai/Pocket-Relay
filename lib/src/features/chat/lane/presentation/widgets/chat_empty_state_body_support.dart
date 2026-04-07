part of 'chat_empty_state_body.dart';

extension on ChatEmptyStateBody {
  Widget _buildShell(BuildContext context, Widget content) {
    return _buildPanelShell(context, content);
  }

  Widget _buildPanelShell(BuildContext context, Widget content) {
    final palette = context.pocketPalette;

    return PocketPanelSurface(
      backgroundColor: palette.surface,
      borderColor: palette.surfaceBorder,
      radius: PocketRadii.hero,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          palette.surface,
          palette.subtleSurface.withValues(alpha: 0.55),
        ],
      ),
      child: content,
    );
  }

  Widget _buildDetailsPanel(
    BuildContext context, {
    required List<_EmptyStateDetail> items,
    required double maxWidth,
    bool panelized = true,
  }) {
    if (!panelized) {
      final divider = context.pocketPalette.surfaceBorder.withValues(
        alpha: 0.4,
      );
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: <Widget>[
            for (final (index, item) in items.indexed) ...[
              Padding(
                padding: PocketSpacing.panelPadding,
                child: _EmptyStateDetailRow(item: item),
              ),
              if (index != items.length - 1)
                Divider(height: 1, thickness: 1, color: divider),
            ],
          ],
        ),
      );
    }

    final (background, border, divider) = (
      context.pocketPalette.subtleSurface.withValues(alpha: 0.72),
      context.pocketPalette.surfaceBorder.withValues(alpha: 0.9),
      context.pocketPalette.surfaceBorder.withValues(alpha: 0.65),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: PocketPanelSurface(
        backgroundColor: background,
        borderColor: border,
        radius: PocketRadii.xl,
        child: Column(
          children: <Widget>[
            for (final (index, item) in items.indexed) ...[
              Padding(
                padding: PocketSpacing.panelPadding,
                child: _EmptyStateDetailRow(item: item),
              ),
              if (index != items.length - 1)
                Divider(height: 1, thickness: 1, color: divider),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroIcon(BuildContext context, {required bool desktop}) {
    return _buildMaterialHeroIcon(context, desktop: desktop);
  }

  Widget _buildMaterialHeroIcon(BuildContext context, {required bool desktop}) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Container(
      width: desktop ? 76 : 64,
      height: desktop ? 76 : 64,
      decoration: BoxDecoration(
        color: palette.subtleSurface,
        borderRadius: PocketRadii.circular(22),
      ),
      child: Icon(
        desktop ? Icons.laptop_mac_rounded : Icons.phone_android,
        size: desktop ? 34 : 30,
        color: theme.colorScheme.primary,
      ),
    );
  }

  TextStyle _titleStyle(BuildContext context, {required bool desktop}) {
    return TextStyle(
      fontSize: desktop ? 30 : 24,
      fontWeight: FontWeight.w800,
      height: 1.14,
    );
  }

  TextStyle _bodyStyle(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.55,
    );
  }

  Widget _buildConfigureButton({
    required bool desktop,
    bool supportsLocalConnectionMode = true,
    bool fullWidth = false,
  }) {
    final label = desktop && supportsLocalConnectionMode
        ? 'Configure connection'
        : 'Configure remote';
    final button = FilledButton.icon(
      onPressed: onConfigure,
      icon: const Icon(Icons.settings),
      label: Text(label),
    );

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }

  bool _shouldFlattenSupplementalDetailsPanel() {
    return flattenSupplementalDetailsPanel &&
        isConfigured &&
        supplementalContent != null;
  }
}

class _EmptyStateDetail {
  const _EmptyStateDetail({
    required this.title,
    required this.body,
    required this.materialIcon,
  });

  final String title;
  final String body;
  final IconData materialIcon;
}

class _EmptyStateDetailRow extends StatelessWidget {
  const _EmptyStateDetailRow({required this.item});

  final _EmptyStateDetail item;

  @override
  Widget build(BuildContext context) {
    return _buildMaterialRow(context);
  }

  Widget _buildMaterialRow(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.materialIcon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.body,
                style: TextStyle(
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
