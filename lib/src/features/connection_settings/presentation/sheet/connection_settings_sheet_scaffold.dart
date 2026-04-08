part of 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

extension _ConnectionSettingsSheetScaffold on ConnectionSettingsSheetSurface {
  Widget _buildMaterialSurface(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return ModalSheetScaffold(
      headerPadding: const EdgeInsets.fromLTRB(
        _mobileHorizontalPadding,
        _mobileHeaderTopPadding,
        _mobileHorizontalPadding,
        _mobileHeaderBottomPadding,
      ),
      bodyPadding: EdgeInsets.zero,
      bodyIsScrollable: false,
      header: this._buildMobileHeader(context, contract),
      body: this._buildSurfaceBody(context, contract, isDesktop: false),
    );
  }

  Widget _buildDesktopSurface(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final palette = context.pocketPalette;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _desktopSurfacePadding,
          _desktopSurfacePadding,
          _desktopSurfacePadding,
          _desktopSurfacePadding + viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: _desktopSurfaceMaxWidth,
            maxHeight:
                screenHeight -
                _desktopSurfaceVerticalMargin -
                viewInsets.bottom,
          ),
          child: Material(
            key: const ValueKey<String>('desktop_connection_settings_surface'),
            color: palette.sheetBackground,
            elevation: _desktopSurfaceElevation,
            shadowColor: palette.shadowColor.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(_desktopSurfaceRadius),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _desktopSurfacePadding,
                    _desktopSurfacePadding,
                    _desktopSurfacePadding,
                    _desktopSurfaceHeaderBottomPadding,
                  ),
                  child: this._buildHeaderContent(
                    context,
                    contract,
                    isDesktop: true,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      _desktopSurfacePadding,
                      _desktopSurfaceContentTopPadding,
                      _desktopSurfacePadding,
                      _desktopSurfacePadding,
                    ),
                    child: this._buildScrollableContent(context, contract),
                  ),
                ),
                const Divider(height: 1),
                this._buildFooterActionBar(context, contract, isDesktop: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModalSheetDragHandle(),
        const SizedBox(height: 18),
        this._buildHeaderContent(context, contract, isDesktop: false),
      ],
    );
  }

  Widget _buildSurfaceBody(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool isDesktop,
  }) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              _mobileHorizontalPadding,
              _mobileContentTopPadding,
              _mobileHorizontalPadding,
              _mobileHorizontalPadding,
            ),
            child: this._buildScrollableContent(context, contract),
          ),
        ),
        const Divider(height: 1),
        this._buildFooterActionBar(context, contract, isDesktop: isDesktop),
      ],
    );
  }

  Widget _buildFooterActionBar(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool isDesktop,
  }) {
    final bottomPadding = isDesktop
        ? _desktopSurfacePadding
        : _mobileFooterBottomPadding + MediaQuery.viewInsetsOf(context).bottom;
    final horizontalPadding = isDesktop
        ? _desktopSurfacePadding
        : _mobileHorizontalPadding;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        14,
        horizontalPadding,
        bottomPadding,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              key: const ValueKey<String>('connection_settings_cancel_top'),
              onPressed: actions.onCancel,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              key: const ValueKey<String>('connection_settings_save_top'),
              onPressed: actions.onSave,
              child: Text(contract.saveAction.label),
            ),
          ),
        ],
      ),
    );
  }
}
