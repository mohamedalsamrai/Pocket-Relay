import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

ConnectionSettingsTextFieldContract settingsField(
  Object section,
  ConnectionSettingsFieldId fieldId,
) {
  final fields = switch (section) {
    ConnectionSettingsSectionContract(:final fields) => fields,
    ConnectionSettingsAuthenticationSectionContract(:final fields) => fields,
    ConnectionSettingsAgentAdapterSectionContract(:final fields) => fields,
    _ => throw ArgumentError.value(section, 'section'),
  };

  return fields.singleWhere((field) => field.id == fieldId);
}

ConnectionProfile configuredConnectionProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
    hostFingerprint: 'aa:bb:cc:dd',
  );
}
