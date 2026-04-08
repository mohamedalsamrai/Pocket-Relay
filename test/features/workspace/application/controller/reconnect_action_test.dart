import 'controller_test_support.dart';

void main() {
  test(
    'reconnectConnection on a transport-loss lane reconnects through the existing binding before clearing transport recovery state',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');
      await clientsByConnectionId['conn_primary']!.first.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);
      await clientsByConnectionId['conn_primary']!.first.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );

      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, same(firstBinding));
      expect(clientsByConnectionId['conn_primary'], hasLength(1));
      expect(clientsByConnectionId['conn_primary']!.first.connectCalls, 2);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        isNull,
      );
    },
  );

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

  test(
    'reconnectConnection marks liveness unknown when reconnect succeeds but the adapter cannot prove whether the turn is still live',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          CodexAppServerThreadHistory(
            id: 'thread_saved',
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

  test(
    'reconnectConnection does not leave a manual recovery attempt in flight for saved-settings-only reconnects',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );

      await controller.reconnectConnection('conn_primary');

      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(diagnostics?.lastRecoveryOrigin, isNull);
      expect(diagnostics?.lastRecoveryStartedAt, isNull);
      expect(diagnostics?.lastRecoveryCompletedAt, isNull);
    },
  );

  test(
    'reconnectConnection preserves reconnect-required state if transport drops during history assessment',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final client = clientsById['conn_primary']!
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
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
      client.readThreadCalls.clear();
      await client.disconnect();
      await Future<void>.delayed(Duration.zero);

      client.readThreadWithTurnsGate = Completer<void>();
      final reconnectFuture = controller.reconnectConnection('conn_primary');
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(client.readThreadCalls, contains('thread_saved'));

      await client.disconnect();
      await Future<void>.delayed(Duration.zero);
      client.readThreadWithTurnsGate!.complete();
      await reconnectFuture;

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.transportLost,
      );
    },
  );

  test(
    'reconnectConnection replaces the targeted live binding and clears reconnect-required state',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(nextBinding?.sessionController.profile.host, 'primary.changed');
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 1);
      expect(clientsByConnectionId['conn_primary']!.last.disconnectCalls, 0);
    },
  );

  test(
    'reconnectConnection preserves an explicitly resumed transcript selection on the recreated lane',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..threadHistoriesById['thread_saved'] = savedConversationThread(
              threadId: 'thread_saved',
            );
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      await controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_saved',
      );
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(clientsByConnectionId['conn_primary'], hasLength(3));
      expect(
        clientsByConnectionId['conn_primary']!.last.readThreadCalls,
        <String>['thread_saved'],
      );
      expect(
        nextBinding!.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        nextBinding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
    },
  );
}

CodexAppServerThreadHistory _conversationThreadWithStatus({
  required String threadId,
  required String turnId,
  required String status,
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
          'threadId': turnThreadId,
          'status': status,
        },
      ),
    ],
  );
}
