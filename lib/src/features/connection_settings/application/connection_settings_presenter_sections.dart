part of 'connection_settings_presenter.dart';

ConnectionSettingsSectionContract _buildProfileSection(
  ConnectionSettingsDraft draft,
) {
  return ConnectionSettingsSectionContract(
    title: 'Profile',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.label,
        label: 'Profile label',
        value: draft.label,
      ),
    ],
  );
}

ConnectionSettingsConnectionModeSectionContract? _buildConnectionModeSection(
  ConnectionSettingsDraft draft, {
  required bool supportsLocalConnectionMode,
}) {
  if (!supportsLocalConnectionMode) {
    return null;
  }

  return ConnectionSettingsConnectionModeSectionContract(
    title: 'Route',
    selectedMode: draft.connectionMode,
    options: const <ConnectionSettingsConnectionModeOptionContract>[
      ConnectionSettingsConnectionModeOptionContract(
        mode: ConnectionMode.remote,
        label: 'Remote',
        description:
            'Connect to a developer box over SSH and run Codex there.',
      ),
      ConnectionSettingsConnectionModeOptionContract(
        mode: ConnectionMode.local,
        label: 'Local',
        description:
            'Run Codex app-server on this desktop and keep the workspace here.',
      ),
    ],
  );
}

ConnectionSettingsSectionContract? _buildRemoteConnectionSection(
  _ConnectionSettingsPresentationState state,
) {
  if (!state.isRemote) {
    return null;
  }

  final draft = state.draft;
  return ConnectionSettingsSectionContract(
    title: 'Remote target',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.host,
        label: 'Host',
        value: draft.host,
        hintText: 'devbox.local',
        errorText: state.hostError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.port,
        label: 'Port',
        value: draft.port,
        keyboardType: ConnectionSettingsKeyboardType.number,
        errorText: state.portError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.username,
        label: 'Username',
        value: draft.username,
        errorText: state.usernameError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.hostFingerprint,
        label: 'Host fingerprint (optional)',
        value: draft.hostFingerprint,
        hintText: 'aa:bb:cc:dd:...',
      ),
    ],
  );
}

ConnectionSettingsAuthenticationSectionContract? _buildAuthenticationSection(
  _ConnectionSettingsPresentationState state,
) {
  if (!state.isRemote) {
    return null;
  }

  final draft = state.draft;
  return ConnectionSettingsAuthenticationSectionContract(
    title: 'Authentication',
    selectedMode: draft.authMode,
    options: const <ConnectionSettingsAuthOptionContract>[
      ConnectionSettingsAuthOptionContract(
        mode: AuthMode.password,
        label: 'Password',
        icon: ConnectionSettingsAuthOptionIcon.password,
      ),
      ConnectionSettingsAuthOptionContract(
        mode: AuthMode.privateKey,
        label: 'Private key',
        icon: ConnectionSettingsAuthOptionIcon.privateKey,
      ),
    ],
    fields: switch (draft.authMode) {
      AuthMode.password => <ConnectionSettingsTextFieldContract>[
        ConnectionSettingsTextFieldContract(
          id: ConnectionSettingsFieldId.password,
          label: 'SSH password',
          value: draft.password,
          obscureText: true,
          errorText: state.passwordError,
        ),
      ],
      AuthMode.privateKey => <ConnectionSettingsTextFieldContract>[
        ConnectionSettingsTextFieldContract(
          id: ConnectionSettingsFieldId.privateKeyPem,
          label: 'Private key PEM',
          value: draft.privateKeyPem,
          errorText: state.privateKeyError,
          minLines: 6,
          maxLines: 10,
          alignLabelWithHint: true,
        ),
        ConnectionSettingsTextFieldContract(
          id: ConnectionSettingsFieldId.privateKeyPassphrase,
          label: 'Key passphrase (optional)',
          value: draft.privateKeyPassphrase,
          obscureText: true,
        ),
      ],
    },
  );
}

ConnectionSettingsSectionContract _buildCodexSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  return ConnectionSettingsSectionContract(
    title: state.isRemote ? 'Remote Codex' : 'Local Codex',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.workspaceDir,
        label: 'Workspace directory',
        value: draft.workspaceDir,
        hintText: '/path/to/workspace',
        errorText: state.workspaceDirError,
      ),
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.codexPath,
        label: 'Codex launch command',
        value: draft.codexPath,
        hintText: 'codex or just codex-mcp',
        helperText: state.isRemote
            ? 'Command run on the remote machine inside the workspace before app-server args are appended.'
            : 'Command run on this desktop inside the workspace before app-server args are appended.',
        errorText: state.codexPathError,
      ),
    ],
  );
}

ConnectionSettingsModelSectionContract _buildModelSection(
  _ConnectionSettingsPresentationState state,
) {
  final draft = state.draft;
  return ConnectionSettingsModelSectionContract(
    title: 'Model defaults',
    fields: <ConnectionSettingsTextFieldContract>[
      ConnectionSettingsTextFieldContract(
        id: ConnectionSettingsFieldId.model,
        label: 'Model override (optional)',
        value: draft.model,
        hintText: 'gpt-5.4 or gpt-5.4-mini',
        helperText: state.modelHelperText,
      ),
    ],
    selectedReasoningEffort: draft.reasoningEffort,
    reasoningEffortOptions:
        const <ConnectionSettingsReasoningEffortOptionContract>[
          ConnectionSettingsReasoningEffortOptionContract(
            effort: null,
            label: 'Default',
            description: 'Use the model or workspace default effort.',
          ),
          ConnectionSettingsReasoningEffortOptionContract(
            effort: CodexReasoningEffort.none,
            label: 'None',
            description: 'Disable extra reasoning where supported.',
          ),
          ConnectionSettingsReasoningEffortOptionContract(
            effort: CodexReasoningEffort.minimal,
            label: 'Minimal',
            description: 'Use the lightest reasoning pass.',
          ),
          ConnectionSettingsReasoningEffortOptionContract(
            effort: CodexReasoningEffort.low,
            label: 'Low',
            description: 'Favor speed over deeper planning.',
          ),
          ConnectionSettingsReasoningEffortOptionContract(
            effort: CodexReasoningEffort.medium,
            label: 'Medium',
            description: 'Balanced default for general work.',
          ),
          ConnectionSettingsReasoningEffortOptionContract(
            effort: CodexReasoningEffort.high,
            label: 'High',
            description: 'Spend more reasoning on harder tasks.',
          ),
          ConnectionSettingsReasoningEffortOptionContract(
            effort: CodexReasoningEffort.xhigh,
            label: 'XHigh',
            description: 'Maximum reasoning depth when supported.',
          ),
        ],
  );
}

ConnectionSettingsSubmitPayload _buildSubmitPayload({
  required ConnectionProfile initialProfile,
  required ConnectionSecrets initialSecrets,
  required _ConnectionSettingsPresentationState state,
}) {
  final draft = state.draft;
  final presenter = const ConnectionSettingsPresenter();
  return ConnectionSettingsSubmitPayload(
    profile: initialProfile.copyWith(
      label: presenter._normalizedLabel(draft.label),
      connectionMode: draft.connectionMode,
      host: draft.host.trim(),
      port: state.port ?? initialProfile.port,
      username: draft.username.trim(),
      workspaceDir: draft.workspaceDir.trim(),
      codexPath: draft.codexPath.trim(),
      model: draft.model.trim(),
      reasoningEffort: draft.reasoningEffort,
      authMode: draft.authMode,
      hostFingerprint: draft.hostFingerprint.trim(),
      dangerouslyBypassSandbox: draft.dangerouslyBypassSandbox,
      ephemeralSession: draft.ephemeralSession,
    ),
    secrets: initialSecrets.copyWith(
      password: draft.password,
      privateKeyPem: draft.privateKeyPem,
      privateKeyPassphrase: draft.privateKeyPassphrase,
    ),
  );
}
