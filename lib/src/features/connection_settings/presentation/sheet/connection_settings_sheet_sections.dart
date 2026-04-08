part of 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

extension _ConnectionSettingsSheetSections on ConnectionSettingsSheetSurface {
  Widget _buildScrollableContent(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return surfaceMode == ConnectionSettingsSurfaceMode.system
        ? this._buildSystemScrollableContent(context, contract)
        : this._buildWorkspaceScrollableContent(context, contract);
  }

  Widget _buildWorkspaceScrollableContent(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final hasAdvancedToggles = contract.runModeSection.toggles.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        this._buildSection(
          context,
          key: const ValueKey<String>('connection_settings_section_workspace'),
          title: 'Workspace',
          child: this._buildWorkspaceSection(context, contract),
        ),
        this._buildSectionDivider(),
        this._buildSection(
          context,
          key: const ValueKey<String>(
            'connection_settings_section_agent_adapter',
          ),
          title: contract.agentAdapterSection.title,
          child: this._buildHostSection(context, contract),
        ),
        if (hasAdvancedToggles) ...[
          this._buildSectionDivider(),
          this._buildSection(
            context,
            key: const ValueKey<String>('connection_settings_section_advanced'),
            title: 'Advanced',
            child: this._buildAdvancedSection(context, contract),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemScrollableContent(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contract.profileSection.fields.isNotEmpty) ...[
          this._buildSection(
            context,
            key: const ValueKey<String>('connection_settings_section_name'),
            title: contract.profileSection.title,
            child: this._buildFieldColumn(
              context,
              contract.profileSection.fields,
            ),
          ),
          if (contract.remoteConnectionSection != null)
            this._buildSectionDivider(),
        ],
        if (contract.remoteConnectionSection case final remoteSection?)
          this._buildSection(
            context,
            key: const ValueKey<String>('connection_settings_section_system'),
            title: 'System',
            child: this._buildRemoteAccessSection(
              context,
              contract,
              remoteSection,
              showSystemPicker: false,
            ),
          ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required Key key,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildSectionDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: _sectionDividerSpacing),
      child: Divider(height: 1),
    );
  }

  Widget _buildWorkspaceSection(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final routeSection = contract.connectionModeSection;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        this._buildFieldColumn(context, contract.profileSection.fields),
        if (routeSection != null) ...[
          const SizedBox(height: _sectionSpacing),
          this._buildSubsectionLabel(context, routeSection.title),
          const SizedBox(height: 12),
          this._buildConnectionModePicker(context, routeSection),
        ],
        if (contract.systemPicker case final picker?) ...[
          const SizedBox(height: _sectionSpacing),
          this._buildSubsectionLabel(context, 'System'),
          const SizedBox(height: 12),
          this._buildSystemPicker(context, picker),
          const SizedBox(height: 10),
          Text(
            picker.helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemoteAccessSection(
    BuildContext context,
    ConnectionSettingsContract contract,
    ConnectionSettingsSectionContract remoteSection, {
    required bool showSystemPicker,
  }) {
    final systemPicker = showSystemPicker ? contract.systemPicker : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (systemPicker != null) ...[
          this._buildSubsectionLabel(context, systemPicker.title),
          const SizedBox(height: 12),
          this._buildSystemPicker(context, systemPicker),
          const SizedBox(height: 10),
          Text(
            systemPicker.helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: _sectionSpacing),
        ],
        if (remoteSection.status case final status?) ...[
          this._buildRemoteStatusStrip(context, contract, status),
          const SizedBox(height: _sectionSpacing),
        ],
        this._buildSubsectionLabel(context, 'System details'),
        const SizedBox(height: 12),
        this._buildRemoteConnectionFields(context, remoteSection.fields),
        if (contract.authenticationSection case final authSection?) ...[
          const SizedBox(height: _sectionSpacing),
          this._buildSubsectionLabel(context, authSection.title),
          const SizedBox(height: 12),
          this._buildAuthModePicker(context, authSection),
          const SizedBox(height: 14),
          this._buildFieldColumn(context, authSection.fields),
        ],
        if (contract.systemTrust case final trustSection?) ...[
          const SizedBox(height: _sectionSpacing),
          this._buildSubsectionLabel(context, trustSection.title),
          const SizedBox(height: 12),
          this._buildSystemTrustPanel(context, trustSection),
        ],
      ],
    );
  }

  Widget _buildHostSection(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final agentAdapterSection = contract.agentAdapterSection;
    final hostFields = agentAdapterSection.fields;
    final helperText = agentAdapterSection.helperText.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (agentAdapterSection.options.length > 1) ...[
          this._buildSubsectionLabel(context, 'Adapter'),
          const SizedBox(height: 12),
          this._buildAgentAdapterPicker(context, agentAdapterSection),
          if (helperText.isNotEmpty) const SizedBox(height: 10),
        ],
        if (helperText.isNotEmpty)
          Text(
            helperText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        if (agentAdapterSection.status case final status?) ...[
          const SizedBox(height: _sectionSpacing),
          this._buildInlineStatusStrip(
            context,
            status,
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ],
        if (hostFields.isNotEmpty) this._buildFieldColumn(context, hostFields),
        if (hostFields.isNotEmpty) const SizedBox(height: _sectionSpacing),
        this._buildSubsectionLabel(context, contract.modelSection.title),
        const SizedBox(height: 12),
        this._buildModelDefaultsSection(context, contract.modelSection),
      ],
    );
  }

  Widget _buildAdvancedSection(
    BuildContext context,
    ConnectionSettingsContract contract,
  ) {
    final toggles = contract.runModeSection.toggles;
    return Column(
      children: toggles.indexed
          .expand((entry) {
            final index = entry.$1;
            final toggle = entry.$2;
            return <Widget>[
              this._buildToggle(context, toggle),
              if (index != toggles.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: _fieldSpacing),
                  child: Divider(height: 1),
                ),
            ];
          })
          .toList(growable: false),
    );
  }

  Widget _buildSubsectionLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}
