import '../controller_test_support.dart';

void main() {
  test(
    'reconnectConnection marks liveness unknown when reconnect succeeds but the adapter cannot prove whether the turn is still live',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          _conversationThreadWithStatus(
            threadId: 'thread_saved',
            turnId: 'turn_unknown',
          );
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
      await clientsById['conn_primary']!.disconnect();
      await Future<void>.delayed(Duration.zero);

      await controller.reconnectConnection('conn_primary');

      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.unknown,
          evidence: ConnectionWorkspaceTurnLivenessEvidence.adapterUnverifiable,
          threadId: 'thread_saved',
          turnId: 'turn_unknown',
        ),
      );
    },
  );

  test(
    'reconnectConnection marks continuity lost when live reattach fails and history cannot prove a finished turn',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          const CodexAppServerThreadHistory(
            id: 'thread_saved',
            sourceKind: 'app-server',
          );
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
      clientsById['conn_primary']!.startSessionError =
          const CodexAppServerException('resume failed');
      await clientsById['conn_primary']!.disconnect();
      await Future<void>.delayed(Duration.zero);

      await controller.reconnectConnection('conn_primary');

      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
          evidence: ConnectionWorkspaceTurnLivenessEvidence.liveReattachFailed,
          threadId: 'thread_saved',
        ),
      );
    },
  );

  test(
    'reconnectConnection ignores unrelated history turns when assessing reconnect liveness',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          _conversationThreadWithStatus(
            threadId: 'thread_saved',
            turnId: 'turn_other',
            status: 'completed',
            turnThreadId: 'thread_other',
          );
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
      clientsById['conn_primary']!.startSessionError =
          const CodexAppServerException('resume failed');
      await clientsById['conn_primary']!.disconnect();
      await Future<void>.delayed(Duration.zero);

      await controller.reconnectConnection('conn_primary');

      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
          evidence: ConnectionWorkspaceTurnLivenessEvidence.liveReattachFailed,
          threadId: 'thread_saved',
        ),
      );
    },
  );

  test(
    'reconnectConnection treats interrupted history turns as finished while away',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          _conversationThreadWithStatus(
            threadId: 'thread_saved',
            turnId: 'turn_interrupted',
            status: 'interrupted',
          );
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
      clientsById['conn_primary']!.startSessionError =
          const CodexAppServerException('resume failed');
      await clientsById['conn_primary']!.disconnect();
      await Future<void>.delayed(Duration.zero);

      await controller.reconnectConnection('conn_primary');

      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.threadHistoryTerminalTurn,
          threadId: 'thread_saved',
          turnId: 'turn_interrupted',
        ),
      );
    },
  );
}

CodexAppServerThreadHistory _conversationThreadWithStatus({
  required String threadId,
  required String turnId,
  String? status,
  String? turnThreadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    sourceKind: 'app-server',
    turns: <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: turnId,
        threadId: turnThreadId,
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
          if (turnThreadId != null) 'threadId': turnThreadId,
          if (status != null) 'status': status,
        },
      ),
    ],
  );
}
