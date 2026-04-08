import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_sheet_surface.dart';

import '../host_test_support.dart';

void main() {
  testWidgets(
    'material settings renderer shows validation from the shared host without a Form widget',
    (tester) async {
      ConnectionSettingsSubmitPayload? payload;
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (nextPayload) {
            payload = nextPayload;
          },
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      expect(find.byType(Form), findsNothing);
      expect(find.text('Bad port'), findsNothing);

      await tester.enterText(materialTextField('Port'), '70000');
      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bad port'), findsOneWidget);
      expect(payload, isNull);
    },
  );

  testWidgets(
    'material settings renderer disables smart typing for system and auth fields',
    (tester) async {
      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          surfaceMode: ConnectionSettingsSurfaceMode.system,
        ),
      );

      final hostField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.host)),
      );
      final usernameField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.username)),
      );
      final passwordField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.password)),
      );

      expect(hostField.textCapitalization, TextCapitalization.none);
      expect(hostField.autocorrect, isFalse);
      expect(hostField.enableSuggestions, isFalse);
      expect(hostField.smartDashesType, SmartDashesType.disabled);
      expect(hostField.smartQuotesType, SmartQuotesType.disabled);

      expect(usernameField.textCapitalization, TextCapitalization.none);
      expect(usernameField.autocorrect, isFalse);
      expect(usernameField.enableSuggestions, isFalse);

      expect(passwordField.textCapitalization, TextCapitalization.none);
      expect(passwordField.autocorrect, isFalse);
      expect(passwordField.enableSuggestions, isFalse);

      await tester.ensureVisible(find.text('Private key'));
      await tester.tap(find.text('Private key'));
      await tester.pumpAndSettle();

      final privateKeyField = tester.widget<TextField>(
        find.byKey(settingsFieldKey(ConnectionSettingsFieldId.privateKeyPem)),
      );
      expect(privateKeyField.textCapitalization, TextCapitalization.none);
      expect(privateKeyField.autocorrect, isFalse);
      expect(privateKeyField.enableSuggestions, isFalse);
      expect(privateKeyField.smartDashesType, SmartDashesType.disabled);
      expect(privateKeyField.smartQuotesType, SmartQuotesType.disabled);
    },
  );
}
