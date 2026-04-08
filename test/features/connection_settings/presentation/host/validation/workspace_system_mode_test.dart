import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

import '../host_test_support.dart';

void main() {
  testWidgets(
    'system settings edit and submit a real system name while workspace fields stay empty',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          initialProfile: connectionProfileFromSystem(
            SavedSystem(
              id: 'system_primary',
              profile: const SystemProfile(
                label: 'Build Box',
                host: 'devbox.local',
                port: 22,
                username: 'vince',
                authMode: AuthMode.password,
                hostFingerprint: 'aa:bb:cc:dd',
              ),
              secrets: const ConnectionSecrets(password: 'secret'),
            ),
          ),
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      expect(find.text('System name'), findsOneWidget);
      expect(
        find.text('The hostname or IP address of this system.'),
        findsOneWidget,
      );

      await tester.enterText(materialTextField('System name'), 'Build Box 2');
      await tester.enterText(materialTextField('Username'), 'vincent');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNotNull);
      expect(payload!.profile.label, 'Build Box 2');
      expect(payload!.profile.username, 'vincent');
      expect(payload!.profile.workspaceDir, isEmpty);
      expect(payload!.profile.codexPath, isEmpty);
    },
  );

  testWidgets('workspace settings can reuse a saved system template', (
    tester,
  ) async {
    ConnectionSettingsSubmitPayload? payload;
    final template = ConnectionSettingsSystemTemplate(
      id: 'system_primary',
      profile: ConnectionProfile.defaults().copyWith(
        label: 'Primary System',
        host: 'buildbox.local',
        port: 2200,
        username: 'alice',
        workspaceDir: '/workspace/primary',
        codexPath: 'codex',
        authMode: AuthMode.password,
        hostFingerprint: '11:22:33:44',
      ),
      secrets: const ConnectionSecrets(password: 'other-secret'),
    );

    await tester.pumpWidget(
      buildMaterialSettingsApp(
        onSubmit: (nextPayload) {
          payload = nextPayload;
        },
        initialProfile: ConnectionProfile.defaults().copyWith(
          workspaceDir: '/workspace/current',
          codexPath: 'codex',
        ),
        availableSystemTemplates: <ConnectionSettingsSystemTemplate>[template],
      ),
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('connection_settings_system_picker')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('connection_settings_system_picker')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Primary System').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.host)),
      findsNothing,
    );
    expect(
      find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
      findsNothing,
    );
    expect(find.text('Primary System'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('connection_settings_save_top')),
    );
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload!.profile.host, 'buildbox.local');
    expect(payload!.profile.port, 2200);
    expect(payload!.profile.username, 'alice');
    expect(payload!.profile.workspaceDir, '/workspace/current');
    expect(payload!.profile.codexPath, 'codex');
    expect(payload!.profile.hostFingerprint, '11:22:33:44');
    expect(payload!.secrets.password, 'other-secret');
  });

  testWidgets(
    'desktop workspace settings expose a local and remote route chooser and hide system selection for local mode',
    (tester) async {
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          platformBehavior: desktopSettingsBehavior,
        ),
      );

      final connectionModePicker = find.byType(SegmentedButton<ConnectionMode>);
      expect(
        find.descendant(
          of: connectionModePicker,
          matching: find.text('Remote'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: connectionModePicker, matching: find.text('Local')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
        findsOneWidget,
      );
      expect(find.text('Agent adapter'), findsOneWidget);

      await tester.ensureVisible(connectionModePicker);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: connectionModePicker,
          matching: find.byIcon(Icons.laptop_mac_outlined),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
        findsNothing,
      );
      expect(find.text('Agent adapter'), findsOneWidget);
      expect(find.text('Workspace directory'), findsOneWidget);
    },
  );
}
