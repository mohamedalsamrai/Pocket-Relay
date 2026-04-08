part of 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

extension _ConnectionSettingsSheetFields on ConnectionSettingsSheetSurface {
  Widget _buildFieldColumn(
    BuildContext context,
    List<ConnectionSettingsTextFieldContract> fields,
  ) {
    return Column(
      children: fields.indexed
          .map((entry) {
            final index = entry.$1;
            final field = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == fields.length - 1 ? 0 : _fieldSpacing,
              ),
              child: this._buildTextField(context, field),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildRemoteConnectionFields(
    BuildContext context,
    List<ConnectionSettingsTextFieldContract> fields,
  ) {
    final fieldMap = viewModel.fieldMap(fields);
    final hostField = fieldMap[ConnectionSettingsFieldId.host];
    final portField = fieldMap[ConnectionSettingsFieldId.port];
    final usernameField = fieldMap[ConnectionSettingsFieldId.username];
    if (hostField == null || portField == null || usernameField == null) {
      return this._buildFieldColumn(context, fields);
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: this._buildTextField(context, hostField)),
            const SizedBox(width: _fieldSpacing),
            Expanded(child: this._buildTextField(context, portField)),
          ],
        ),
        const SizedBox(height: _fieldSpacing),
        this._buildTextField(context, usernameField),
      ],
    );
  }

  Widget _buildSystemPicker(
    BuildContext context,
    ConnectionSettingsSystemPickerContract picker,
  ) {
    return DropdownButtonFormField<String?>(
      key: const ValueKey<String>('connection_settings_system_picker'),
      initialValue: picker.selectedSystemId,
      decoration: const InputDecoration(labelText: 'System'),
      isExpanded: true,
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('No system selected'),
        ),
        ...picker.options.map(
          (option) => DropdownMenuItem<String?>(
            value: option.id,
            child: Text(
              '${option.label} · ${option.description}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      selectedItemBuilder: (context) {
        return <Widget>[
          const Text('No system selected'),
          ...picker.options.map(
            (option) => Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];
      },
      onChanged: actions.onSystemTemplateChanged,
    );
  }

  Widget _buildModelDefaultsSection(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout =
            constraints.maxWidth >= _modelDefaultsSplitLayoutBreakpoint;
        final pickerContent = useSplitLayout
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: this._buildModelPicker(context, section)),
                  const SizedBox(width: _fieldSpacing),
                  Expanded(
                    child: this._buildReasoningEffortPicker(context, section),
                  ),
                ],
              )
            : Column(
                children: [
                  this._buildModelPicker(context, section),
                  const SizedBox(height: _subsectionSpacing),
                  this._buildReasoningEffortPicker(context, section),
                ],
              );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            pickerContent,
            const SizedBox(height: _modelRefreshSpacing),
            this._buildRefreshModelsAction(context, section),
          ],
        );
      },
    );
  }

  Widget _buildTextField(
    BuildContext context,
    ConnectionSettingsTextFieldContract field,
  ) {
    return TextField(
      key: ValueKey<String>('connection_settings_${field.id.name}'),
      controller: viewModel.controllerForField(field.id),
      obscureText: field.obscureText,
      keyboardType: this._textInputType(field.keyboardType),
      textCapitalization: this._textCapitalizationForField(field.id),
      autocorrect: this._autocorrectForField(field.id),
      enableSuggestions: this._enableSuggestionsForField(field.id),
      smartDashesType: this._smartTypingEnabledForField(field.id)
          ? SmartDashesType.enabled
          : SmartDashesType.disabled,
      smartQuotesType: this._smartTypingEnabledForField(field.id)
          ? SmartQuotesType.enabled
          : SmartQuotesType.disabled,
      minLines: field.minLines,
      maxLines: field.maxLines,
      onChanged: (value) {
        actions.onFieldChanged(field.id, value);
      },
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hintText,
        helperText: field.helperText,
        errorText: field.errorText,
        alignLabelWithHint: field.alignLabelWithHint,
      ),
    );
  }

  TextCapitalization _textCapitalizationForField(
    ConnectionSettingsFieldId fieldId,
  ) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => TextCapitalization.words,
      _ => TextCapitalization.none,
    };
  }

  bool _autocorrectForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => true,
      _ => false,
    };
  }

  bool _enableSuggestionsForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => true,
      _ => false,
    };
  }

  bool _smartTypingEnabledForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.label => true,
      _ => false,
    };
  }

  Widget _buildAuthModePicker(
    BuildContext context,
    ConnectionSettingsAuthenticationSectionContract section,
  ) {
    return SegmentedButton<AuthMode>(
      segments: section.options
          .map(
            (option) => ButtonSegment<AuthMode>(
              value: option.mode,
              label: Text(option.label),
              icon: Icon(this._materialAuthIcon(option)),
            ),
          )
          .toList(growable: false),
      selected: <AuthMode>{section.selectedMode},
      onSelectionChanged: (selection) {
        actions.onAuthModeChanged(selection.first);
      },
    );
  }

  Widget _buildConnectionModePicker(
    BuildContext context,
    ConnectionSettingsConnectionModeSectionContract section,
  ) {
    return SegmentedButton<ConnectionMode>(
      segments: section.options
          .map(
            (option) => ButtonSegment<ConnectionMode>(
              value: option.mode,
              label: Text(option.label),
              icon: Icon(this._materialConnectionModeIcon(option.mode)),
            ),
          )
          .toList(growable: false),
      selected: <ConnectionMode>{section.selectedMode},
      onSelectionChanged: (selection) {
        actions.onConnectionModeChanged(selection.first);
      },
    );
  }

  Widget _buildAgentAdapterPicker(
    BuildContext context,
    ConnectionSettingsAgentAdapterSectionContract section,
  ) {
    return DropdownButtonFormField<AgentAdapterKind>(
      key: const ValueKey<String>('connection_settings_agent_adapter'),
      initialValue: section.selectedAdapter,
      decoration: const InputDecoration(labelText: 'Agent adapter'),
      isExpanded: true,
      items: section.options
          .map(
            (option) => DropdownMenuItem<AgentAdapterKind>(
              value: option.kind,
              child: Text(
                '${option.label} · ${option.description}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      selectedItemBuilder: (context) {
        return section.options
            .map(
              (option) => Text(
                option.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            )
            .toList(growable: false);
      },
      onChanged: (nextAdapter) {
        if (nextAdapter == null) {
          return;
        }
        actions.onAgentAdapterChanged(nextAdapter);
      },
    );
  }

  Widget _buildReasoningEffortPicker(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return DropdownButtonFormField<AgentAdapterReasoningEffort?>(
      key: const ValueKey<String>('connection_settings_reasoning_effort'),
      initialValue: section.selectedReasoningEffort,
      decoration: InputDecoration(
        labelText: 'Reasoning effort',
        helperText: section.reasoningEffortHelperText,
      ),
      items: section.reasoningEffortOptions
          .map(
            (option) => DropdownMenuItem<AgentAdapterReasoningEffort?>(
              value: option.effort,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
      onChanged: section.isReasoningEffortEnabled
          ? actions.onReasoningEffortChanged
          : null,
    );
  }

  Widget _buildModelPicker(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return DropdownButtonFormField<String?>(
      key: const ValueKey<String>('connection_settings_model'),
      initialValue: section.selectedModelId,
      decoration: InputDecoration(
        labelText: 'Model override (optional)',
        helperText: section.modelHelperText,
      ),
      items: section.modelOptions
          .map(
            (option) => DropdownMenuItem<String?>(
              value: option.modelId,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
      onChanged: section.isModelEnabled ? actions.onModelChanged : null,
    );
  }

  Widget _buildRefreshModelsAction(
    BuildContext context,
    ConnectionSettingsModelSectionContract section,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          key: const ValueKey<String>('connection_settings_refresh_models'),
          onPressed: section.isRefreshActionEnabled
              ? actions.onRefreshModelCatalog
              : null,
          icon: section.isRefreshActionInProgress
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(section.refreshActionLabel),
        ),
        const SizedBox(height: 8),
        Text(
          section.refreshActionHelperText,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildToggle(
    BuildContext context,
    ConnectionSettingsToggleContract toggle,
  ) {
    final theme = Theme.of(context);

    return SwitchListTile.adaptive(
      value: toggle.value,
      onChanged: (value) {
        actions.onToggleChanged(toggle.id, value);
      },
      contentPadding: EdgeInsets.zero,
      title: Text(
        toggle.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        toggle.subtitle,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.45,
        ),
      ),
    );
  }

  String _summaryTextFor(ConnectionSettingsContract contract) {
    final label = this._fieldValueFor(
      contract.profileSection.fields,
      ConnectionSettingsFieldId.label,
    );
    final workspaceDir = this._fieldValueFor(
      contract.profileSection.fields,
      ConnectionSettingsFieldId.workspaceDir,
    );
    final host = this._fieldValueFor(
      contract.remoteConnectionSection?.fields ?? const [],
      ConnectionSettingsFieldId.host,
    );

    if (host.isNotEmpty && workspaceDir.isNotEmpty) {
      return '$host · $workspaceDir';
    }
    if (workspaceDir.isNotEmpty) {
      return workspaceDir;
    }
    if (host.isNotEmpty) {
      return host;
    }
    if (label.isNotEmpty && label != contract.title) {
      return label;
    }
    return '';
  }

  String _fieldValueFor(
    List<ConnectionSettingsTextFieldContract> fields,
    ConnectionSettingsFieldId fieldId,
  ) {
    for (final field in fields) {
      if (field.id == fieldId) {
        return field.value.trim();
      }
    }
    return '';
  }

  TextInputType _textInputType(ConnectionSettingsKeyboardType keyboardType) {
    return switch (keyboardType) {
      ConnectionSettingsKeyboardType.text => TextInputType.text,
      ConnectionSettingsKeyboardType.number => TextInputType.number,
    };
  }

  IconData _materialAuthIcon(ConnectionSettingsAuthOptionContract option) {
    return switch (option.icon) {
      ConnectionSettingsAuthOptionIcon.password => Icons.password,
      ConnectionSettingsAuthOptionIcon.privateKey => Icons.key,
    };
  }

  IconData _materialConnectionModeIcon(ConnectionMode mode) {
    return switch (mode) {
      ConnectionMode.remote => Icons.cloud_outlined,
      ConnectionMode.local => Icons.laptop_mac_outlined,
    };
  }
}
