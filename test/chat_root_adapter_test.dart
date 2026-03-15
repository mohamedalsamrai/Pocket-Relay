import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  testWidgets('routes connection settings through the overlay delegate', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    final overlayDelegate = _FakeChatRootOverlayDelegate(
      connectionSettingsResult: ConnectionSettingsSubmitPayload(
        profile: _configuredProfile().copyWith(
          label: 'Renamed Box',
          host: 'changed.example.com',
        ),
        secrets: const ConnectionSecrets(password: 'changed-secret'),
      ),
    );
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pumpAndSettle();

    expect(overlayDelegate.connectionSettingsPayloads, hasLength(1));
    expect(find.text('Renamed Box · changed.example.com'), findsOneWidget);
  });

  testWidgets('routes snackbar effects through the overlay delegate', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..sendUserMessageError = StateError('transport broke');
    final overlayDelegate = _FakeChatRootOverlayDelegate();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Hello Codex');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(overlayDelegate.snackBarMessages, hasLength(1));
    expect(
      overlayDelegate.snackBarMessages.single,
      contains('Could not send the prompt'),
    );
  });

  testWidgets(
    'routes changed-file diff openings through the overlay delegate',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\nsecond line\n',
                },
              ],
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/diff/updated',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'diff':
                'diff --git a/README.md b/README.md\n'
                'new file mode 100644\n'
                '--- /dev/null\n'
                '+++ b/README.md\n'
                '@@ -0,0 +1,2 @@\n'
                '+first line\n'
                '+second line\n',
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('README.md'));
      await tester.pump();

      expect(overlayDelegate.changedFileDiffs, hasLength(1));
      expect(
        overlayDelegate.changedFileDiffs.single.displayPathLabel,
        'README.md',
      );
    },
  );
}

Widget _buildAdapterApp({
  required FakeCodexAppServerClient appServerClient,
  required _FakeChatRootOverlayDelegate overlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: ChatRootAdapter(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: _configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
      overlayDelegate: overlayDelegate,
    ),
  );
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
  );
}

class _FakeChatRootOverlayDelegate implements ChatRootOverlayDelegate {
  _FakeChatRootOverlayDelegate({this.connectionSettingsResult});

  final ConnectionSettingsSubmitPayload? connectionSettingsResult;
  final List<ChatConnectionSettingsLaunchContract> connectionSettingsPayloads =
      <ChatConnectionSettingsLaunchContract>[];
  final List<ChatChangedFileDiffContract> changedFileDiffs =
      <ChatChangedFileDiffContract>[];
  final List<String> snackBarMessages = <String>[];

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
  }) async {
    connectionSettingsPayloads.add(connectionSettings);
    return connectionSettingsResult;
  }

  @override
  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  }) async {
    changedFileDiffs.add(diff);
  }

  @override
  void showSnackBar({required BuildContext context, required String message}) {
    snackBarMessages.add(message);
  }
}
