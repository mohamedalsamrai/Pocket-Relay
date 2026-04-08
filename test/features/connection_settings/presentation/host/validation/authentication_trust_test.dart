import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

import '../host_test_support.dart';

void main() {
  testWidgets(
    'material settings renderer switches authentication fields through the shared host',
    (tester) async {
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
        findsOneWidget,
      );
      expect(find.text('Private key'), findsOneWidget);
      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.privateKeyPem)),
        findsNothing,
      );

      await tester.ensureVisible(find.text('Private key'));
      await tester.tap(find.text('Private key'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
        findsNothing,
      );
      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.privateKeyPem)),
        findsOneWidget,
      );
      expect(find.text('Key passphrase (optional)'), findsOneWidget);
    },
  );

  testWidgets(
    'material settings renderer uses a system trust action instead of an editable fingerprint field',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          initialProfile: configuredConnectionProfile().copyWith(
            hostFingerprint: '',
          ),
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      expect(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.hostFingerprint)),
        findsNothing,
      );
      expect(find.text('SSH fingerprint needed'), findsOneWidget);
      expect(
        find.text(
          'Test this system to fetch its SSH fingerprint before saving this system.',
        ),
        findsOneWidget,
      );

      await tester.enterText(materialTextField('Port'), '2222');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();
      expect(payload, isNull);

      await tester.ensureVisible(
        find.byKey(const ValueKey<String>('connection_settings_test_system')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_test_system')),
      );
      await tester.pumpAndSettle();

      expect(find.text('aa:bb:cc:dd'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>('connection_settings_system_fingerprint'),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNotNull);
      expect(payload!.profile.hostFingerprint, 'aa:bb:cc:dd');
    },
  );

  testWidgets('port formatting changes do not clear a trusted fingerprint', (
    tester,
  ) async {
    ConnectionSettingsSubmitPayload? payload;

    await tester.pumpWidget(
      buildMaterialSettingsApp(
        onSubmit: (nextPayload) {
          payload = nextPayload;
        },
        initialProfile: configuredConnectionProfile().copyWith(port: 22),
        surfaceMode: ConnectionSettingsSurfaceMode.system,
      ),
    );

    await tester.enterText(materialTextField('Port'), '022');
    await tester.tap(
      find.byKey(const ValueKey<String>('connection_settings_save_top')),
    );
    await tester.pumpAndSettle();

    expect(payload, isNotNull);
    expect(payload!.profile.port, 22);
    expect(payload!.profile.hostFingerprint, 'aa:bb:cc:dd');
  });
}
