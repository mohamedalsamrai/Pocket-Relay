import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';

import '../../support/workspace_surface_test_support.dart';

export '../../support/workspace_surface_test_support.dart';

void expectInformationalNotice(WidgetTester tester, String title) {
  final theme = Theme.of(tester.element(find.text(title)));
  final decoration = noticeDecorationFor(tester, title);

  expect(
    decoration.color,
    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.94),
  );
  expect(
    (decoration.border! as Border).top.color,
    theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
  );
}

void expectWarningNotice(WidgetTester tester, String title) {
  final theme = Theme.of(tester.element(find.text(title)));
  final decoration = noticeDecorationFor(tester, title);

  expect(
    decoration.color,
    theme.colorScheme.secondaryContainer.withValues(alpha: 0.94),
  );
  expect(
    (decoration.border! as Border).top.color,
    theme.colorScheme.secondary.withValues(alpha: 0.22),
  );
}

BoxDecoration noticeDecorationFor(WidgetTester tester, String title) {
  final noticeDecoratedBox = find
      .ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) {
            return false;
          }
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.borderRadius == BorderRadius.circular(20);
        }),
      )
      .evaluate()
      .map((element) => element.widget)
      .whereType<DecoratedBox>()
      .first;

  return noticeDecoratedBox.decoration as BoxDecoration;
}

Future<void> pumpRemoteRuntimeNoticesSurface(
  WidgetTester tester,
  ConnectionWorkspaceController controller,
) async {
  await tester.pumpWidget(
    buildWorkspaceDrivenLiveLaneApp(
      controller,
      settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> pumpScopedRemoteRuntimeNoticesSurface(
  WidgetTester tester,
  ConnectionWorkspaceController controller,
  ValueListenable<AppLifecycleVisibility> visibilityListenable,
) async {
  await tester.pumpWidget(
    AppLifecycleVisibilityScope(
      visibilityListenable: visibilityListenable,
      child: buildWorkspaceDrivenLiveLaneApp(
        controller,
        settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> connectAndLoseTransport(FakeCodexAppServerClient client) async {
  await client.connect(
    profile: ConnectionProfile.defaults(),
    secrets: const ConnectionSecrets(),
  );
  await client.disconnect();
}

Future<void> selectConversationAndLoseTransport(
  ConnectionWorkspaceController controller,
  FakeCodexAppServerClient client,
  String threadId,
) async {
  await controller.selectedLaneBinding!.sessionController
      .selectConversationForResume(threadId);
  await connectAndLoseTransport(client);
}

CodexAppServerThreadHistory inconclusiveConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_unknown',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_unknown',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory conversationThreadWithStatus({
  required String threadId,
  required String turnId,
  required String status,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: turnId,
        status: status,
        items: const <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': turnId,
          'status': status,
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}
