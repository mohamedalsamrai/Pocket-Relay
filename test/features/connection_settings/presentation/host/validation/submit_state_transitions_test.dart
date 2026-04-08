import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';

import '../host_test_support.dart';

void main() {
  testWidgets(
    'workspace settings can clear a selected system back to no system selected',
    (tester) async {
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
          availableSystemTemplates: <ConnectionSettingsSystemTemplate>[
            template,
          ],
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

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_system_picker')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('No system selected').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('connection_settings_save_top')),
      );
      await tester.pumpAndSettle();

      expect(payload, isNull);
    },
  );

  testWidgets(
    'opening settings preserves an unsupported persisted connection mode',
    (tester) async {
      var refreshCalls = 0;

      await tester.pumpWidget(
        buildMaterialSettingsApp(
          onSubmit: (_) {},
          platformBehavior: mobileSettingsBehavior,
          initialProfile: configuredConnectionProfile().copyWith(
            connectionMode: ConnectionMode.local,
          ),
          onRefreshRemoteRuntime: (payload) async {
            refreshCalls += 1;
            return const ConnectionRemoteRuntimeState.unknown();
          },
        ),
      );

      await tester.pump();

      expect(refreshCalls, 0);
    },
  );
}
