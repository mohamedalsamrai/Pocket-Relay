import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';

import 'presenter_test_support.dart';

void main() {
  const presenter = ConnectionSettingsPresenter();

  test(
    'derives validation from form state instead of widget-local validators',
    () {
      final initialProfile = configuredConnectionProfile();
      final initialSecrets = const ConnectionSecrets(password: 'secret');
      final formState =
          ConnectionSettingsFormState.initial(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(
            draft: ConnectionSettingsDraft.fromConnection(
              profile: initialProfile,
              secrets: initialSecrets,
            ).copyWith(host: '', port: '70000', password: ''),
          );

      final hiddenErrors = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
      );
      final visibleErrors = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState.revealValidationErrors(),
      );

      expect(
        settingsField(
          visibleErrors.remoteConnectionSection!,
          ConnectionSettingsFieldId.host,
        ).errorText,
        'Host is required',
      );
      expect(
        settingsField(
          visibleErrors.remoteConnectionSection!,
          ConnectionSettingsFieldId.port,
        ).errorText,
        'Bad port',
      );
      expect(
        settingsField(
          visibleErrors.authenticationSection!,
          ConnectionSettingsFieldId.password,
        ).errorText,
        'Password is required',
      );
      expect(hiddenErrors.saveAction.canSubmit, isFalse);
      expect(visibleErrors.saveAction.canSubmit, isFalse);
      expect(visibleErrors.saveAction.submitPayload, isNull);
    },
  );

  test('derives auth visibility and validation from the selected mode', () {
    final initialProfile = configuredConnectionProfile();
    const initialSecrets = ConnectionSecrets(password: 'secret');
    final formState =
        ConnectionSettingsFormState.initial(
          profile: initialProfile,
          secrets: initialSecrets,
        ).copyWith(
          draft: ConnectionSettingsDraft.fromConnection(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(authMode: AuthMode.privateKey, privateKeyPem: ''),
          showValidationErrors: true,
        );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
    );

    final authSection = contract.authenticationSection!;
    expect(authSection.selectedMode, AuthMode.privateKey);
    expect(
      authSection.fields.map((field) => field.id),
      <ConnectionSettingsFieldId>[
        ConnectionSettingsFieldId.privateKeyPem,
        ConnectionSettingsFieldId.privateKeyPassphrase,
      ],
    );
    expect(
      settingsField(
        authSection,
        ConnectionSettingsFieldId.privateKeyPem,
      ).errorText,
      'Private key is required',
    );
  });

  test('derives dirty state and normalized save payload in the presenter', () {
    final initialProfile = configuredConnectionProfile();
    const initialSecrets = ConnectionSecrets(password: 'secret');
    final formState =
        ConnectionSettingsFormState.initial(
          profile: initialProfile,
          secrets: initialSecrets,
        ).copyWith(
          draft:
              ConnectionSettingsDraft.fromConnection(
                profile: initialProfile,
                secrets: initialSecrets,
              ).copyWith(
                label: '',
                codexPath: 'codex-mcp',
                dangerouslyBypassSandbox: true,
              ),
          showValidationErrors: true,
        );

    final contract = presenter.present(
      initialProfile: initialProfile,
      initialSecrets: initialSecrets,
      formState: formState,
      availableModelCatalog: codexReferenceModelCatalog(
        connectionId: 'presenter-save-test',
      ),
    );
    final payload = contract.saveAction.submitPayload;

    expect(contract.saveAction.hasChanges, isTrue);
    expect(contract.saveAction.requiresValidation, isTrue);
    expect(contract.saveAction.canSubmit, isTrue);
    expect(payload, isNotNull);
    expect(payload!.profile.label, 'Developer Box');
    expect(payload.profile.codexPath, 'codex-mcp');
    expect(payload.profile.dangerouslyBypassSandbox, isTrue);
    expect(payload.secrets.password, 'secret');
  });

  test(
    'describes the host fingerprint as shared across saved connections on the same host identity',
    () {
      final initialProfile = configuredConnectionProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState = ConnectionSettingsFormState.initial(
        profile: initialProfile,
        secrets: initialSecrets,
      );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
      );

      expect(
        settingsField(
          contract.remoteConnectionSection!,
          ConnectionSettingsFieldId.hostFingerprint,
        ).helperText,
        'Shared host identity: devbox.local:22. This pinned fingerprint is reused by every saved connection that points there.',
      );
    },
  );

  test(
    'includes model and reasoning effort in the normalized save payload',
    () {
      final initialProfile = configuredConnectionProfile();
      const initialSecrets = ConnectionSecrets(password: 'secret');
      final formState =
          ConnectionSettingsFormState.initial(
            profile: initialProfile,
            secrets: initialSecrets,
          ).copyWith(
            draft:
                ConnectionSettingsDraft.fromConnection(
                  profile: initialProfile,
                  secrets: initialSecrets,
                ).copyWith(
                  model: '  gpt-5.4  ',
                  reasoningEffort: CodexReasoningEffort.high,
                ),
            showValidationErrors: true,
          );

      final contract = presenter.present(
        initialProfile: initialProfile,
        initialSecrets: initialSecrets,
        formState: formState,
        availableModelCatalog: codexReferenceModelCatalog(
          connectionId: 'presenter-payload-test',
        ),
      );
      final payload = contract.saveAction.submitPayload;

      expect(
        contract.modelSection.selectedReasoningEffort,
        CodexReasoningEffort.high,
      );
      expect(payload, isNotNull);
      expect(payload!.profile.model, 'gpt-5.4');
      expect(payload.profile.reasoningEffort, CodexReasoningEffort.high);
    },
  );
}
