part of 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

extension _ConnectionSettingsSheetScaffold on ConnectionSettingsSheetSurface {
  bool _usesCompactMobileSystemEditor(BuildContext context) {
    return !isDesktopPresentation &&
        surfaceMode == ConnectionSettingsSurfaceMode.system &&
        MediaQuery.viewInsetsOf(context).bottom > 0;
  }

  Widget _buildMaterialSurface(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final usesCompactMobileSystemEditor = this._usesCompactMobileSystemEditor(
      context,
    );
    return ModalSheetScaffold(
      headerPadding: EdgeInsets.fromLTRB(
        _mobileHorizontalPadding,
        usesCompactMobileSystemEditor ? 0 : _mobileHeaderTopPadding,
        _mobileHorizontalPadding,
        usesCompactMobileSystemEditor ? 0 : _mobileHeaderBottomPadding,
      ),
      showDivider: !usesCompactMobileSystemEditor,
      bodyPadding: EdgeInsets.zero,
      bodyIsScrollable: false,
      header: usesCompactMobileSystemEditor
          ? const SizedBox.shrink()
          : this._buildMobileHeader(
              context,
              contract,
              usesCompactMobileSystemEditor: false,
            ),
      body: this._buildSurfaceBody(
        context,
        contract,
        isDesktop: false,
        usesCompactMobileSystemEditor: usesCompactMobileSystemEditor,
      ),
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
    ConnectionSettingsContract contract, {
    required bool usesCompactMobileSystemEditor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModalSheetDragHandle(),
        SizedBox(height: usesCompactMobileSystemEditor ? 10 : 18),
        this._buildHeaderContent(
          context,
          contract,
          isDesktop: false,
          usesCompactMobileSystemEditor: usesCompactMobileSystemEditor,
        ),
      ],
    );
  }

  Widget _buildSurfaceBody(
    BuildContext context,
    ConnectionSettingsContract contract, {
    required bool isDesktop,
    required bool usesCompactMobileSystemEditor,
  }) {
    if (usesCompactMobileSystemEditor) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          _mobileHorizontalPadding,
          12,
          _mobileHorizontalPadding,
          _mobileFooterBottomPadding + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            this._buildScrollableContent(context, contract),
            const SizedBox(height: 20),
            this._buildFooterActionBar(
              context,
              contract,
              isDesktop: false,
              isInline: true,
            ),
          ],
        ),
      );
    }

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
    bool isInline = false,
  }) {
    final double bottomPadding = isDesktop
        ? _desktopSurfacePadding
        : isInline
        ? 0
        : _mobileFooterBottomPadding + MediaQuery.viewInsetsOf(context).bottom;
    final double horizontalPadding = isDesktop
        ? _desktopSurfacePadding
        : isInline
        ? 0
        : _mobileHorizontalPadding;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        isInline ? 0 : 14,
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
