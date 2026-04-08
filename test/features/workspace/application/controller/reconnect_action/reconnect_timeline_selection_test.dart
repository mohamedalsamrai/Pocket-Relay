import '../controller_test_support.dart';

void main() {
  test(
    'reconnectConnection live-reattaches the selected thread on the existing binding before using history fallback',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });
      clientsById['conn_primary']!
              .resumeThreadReplayEventsByThreadId['thread_saved'] =
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

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      clientsById['conn_primary']!.readThreadCalls.clear();
      clientsById['conn_primary']!.startSessionCalls = 0;
      clientsById['conn_primary']!.startSessionRequests.clear();

      await clientsById['conn_primary']!.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );

      await controller.reconnectConnection('conn_primary');

      expect(controller.bindingForConnectionId('conn_primary'), same(binding));
      expect(clientsById['conn_primary']!.startSessionCalls, 1);
      expect(
        clientsById['conn_primary']!.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
      expect(clientsById['conn_primary']!.readThreadCalls, isEmpty);
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.liveReattached,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.liveReattached,
      );
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
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
    },
  );

  test(
    'reconnectConnection falls back to history restore only after live reattach fails on the existing binding',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      clientsById['conn_primary']!.readThreadCalls.clear();
      clientsById['conn_primary']!.startSessionCalls = 0;
      clientsById['conn_primary']!.startSessionRequests.clear();
      clientsById['conn_primary']!.startSessionError =
          const CodexAppServerException('resume failed');

      await clientsById['conn_primary']!.disconnect();
      await Future<void>.delayed(Duration.zero);

      await controller.reconnectConnection('conn_primary');

      expect(controller.bindingForConnectionId('conn_primary'), same(binding));
      expect(clientsById['conn_primary']!.startSessionCalls, 0);
      expect(clientsById['conn_primary']!.readThreadCalls, <String>[
        'thread_saved',
        'thread_saved',
      ]);
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.conversationRestored,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastLiveReattachFailureDetail,
        contains('resume failed'),
      );
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.threadHistoryTerminalTurn,
          threadId: 'thread_saved',
          turnId: 'turn_saved',
        ),
      );
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
    },
  );
}
