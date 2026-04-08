import 'remote_runtime_notices_test_support.dart';

void main() {
  testWidgets(
    'live lane shows same-live-turn notice when reconnect proves the turn is still active',
    (tester) async {
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = savedConversationThread(
        threadId: 'thread_saved',
      );
      client.resumeThreadReplayEventsByThreadId['thread_saved'] =
          const <CodexAppServerEvent>[
            CodexAppServerNotificationEvent(
              method: 'turn/started',
              params: <String, Object?>{
                'threadId': 'thread_saved',
                'turn': <String, Object?>{
                  'id': 'turn_live',
                  'status': 'running',
                  'model': 'gpt-5.4',
                  'effort': 'high',
                },
              },
            ),
          ];
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await selectConversationAndLoseTransport(
        controller,
        client,
        'thread_saved',
      );
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Same live turn is still running'), findsOneWidget);
      expectInformationalNotice(tester, 'Same live turn is still running');
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.activeTurnReattached,
          threadId: 'thread_saved',
          turnId: 'turn_live',
        ),
      );
    },
  );

  testWidgets(
    'live lane treats inProgress history status as the same live turn after reconnect',
    (tester) async {
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = conversationThreadWithStatus(
        threadId: 'thread_saved',
        turnId: 'turn_live',
        status: 'inProgress',
      );
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await selectConversationAndLoseTransport(
        controller,
        client,
        'thread_saved',
      );
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Same live turn is still running'), findsOneWidget);
      expectInformationalNotice(tester, 'Same live turn is still running');
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.threadHistoryRunningTurn,
          threadId: 'thread_saved',
          turnId: 'turn_live',
        ),
      );
    },
  );
}
