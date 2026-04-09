import 'session_controller_test_support.dart';

void main() {
  test('sendPrompt runs session flow without ChatScreen', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
    );
    addTearDown(controller.dispose);

    final sent = await controller.sendPrompt('Hello controller');

    expect(sent, isTrue);
    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.startSessionRequests.single.model, isNull);
    expect(appServerClient.startSessionRequests.single.reasoningEffort, isNull);
    expect(appServerClient.sentMessages, <String>['Hello controller']);
    expect(controller.transcriptBlocks.length, 1);
    expect(
      controller.transcriptBlocks.first,
      isA<TranscriptUserMessageBlock>(),
    );
    expect(controller.sessionState.headerMetadata.cwd, '/workspace');
    expect(controller.sessionState.headerMetadata.model, 'gpt-5.3-codex');
    final messageBlock =
        controller.transcriptBlocks.first as TranscriptUserMessageBlock;
    expect(messageBlock.text, 'Hello controller');
    expect(messageBlock.deliveryState, TranscriptUserMessageDeliveryState.sent);
  });

  test(
    'sendPrompt steers the active turn when the adapter supports live turn steering',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('First prompt'), isTrue);

      final sentWhileRunning = await controller.sendPrompt('Steer the agent');

      expect(sentWhileRunning, isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>['First prompt']);
      expect(appServerClient.steeredMessages, <String>['Steer the agent']);
      expect(appServerClient.sentTurns, <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_123',
          input: const CodexAppServerTurnInput.text('First prompt'),
          text: 'First prompt',
          model: null,
          effort: null,
        ),
      ]);
      expect(appServerClient.steeredTurns, <
        ({
          String threadId,
          String turnId,
          CodexAppServerTurnInput input,
          String text,
        })
      >[
        (
          threadId: 'thread_123',
          turnId: 'turn_1',
          input: const CodexAppServerTurnInput.text('Steer the agent'),
          text: 'Steer the agent',
        ),
      ]);
    },
  );

  test(
    'sendPrompt starts a fresh conversation after controller restart until history is explicitly picked',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Continue after restart'), isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentTurns, <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_123',
          input: const CodexAppServerTurnInput.text('Continue after restart'),
          text: 'Continue after restart',
          model: null,
          effort: null,
        ),
      ]);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
    },
  );

  test(
    'stopActiveTurn clears streaming assistant state without waiting for abort notification',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Start streaming'), isTrue);
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_1',
              'type': 'agentMessage',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'delta': 'Partial answer',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final streamingAssistant = controller.transcriptBlocks
          .whereType<TranscriptTextBlock>()
          .singleWhere(
            (block) => block.kind == TranscriptUiBlockKind.assistantMessage,
          );
      expect(streamingAssistant.isRunning, isTrue);

      await controller.stopActiveTurn();

      expect(
        appServerClient.abortTurnCalls,
        <({String? threadId, String? turnId})>[
          (threadId: 'thread_123', turnId: 'turn_1'),
        ],
      );
      final settledAssistant = controller.transcriptBlocks
          .whereType<TranscriptTextBlock>()
          .singleWhere(
            (block) => block.kind == TranscriptUiBlockKind.assistantMessage,
          );
      expect(settledAssistant.body, 'Partial answer');
      expect(settledAssistant.isRunning, isFalse);
      expect(
        controller.transcriptBlocks.whereType<TranscriptStatusBlock>(),
        hasLength(1),
      );

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/aborted',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'reason': 'Turn aborted.',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.transcriptBlocks.whereType<TranscriptStatusBlock>(),
        hasLength(1),
      );
    },
  );
}
