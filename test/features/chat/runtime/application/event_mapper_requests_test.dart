import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';

void main() {
  test('maps official user, review, and image item types correctly', () {
    final mapper = CodexRuntimeEventMapper();

    final userItem = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_user',
            'type': 'userMessage',
            'status': 'completed',
            'content': <Object>[
              <String, Object?>{'type': 'text', 'text': 'Ship the fix'},
            ],
          },
        },
      ),
    );
    final reviewItem = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_review',
            'type': 'enteredReviewMode',
            'status': 'completed',
            'review': 'Checking the patch set',
          },
        },
      ),
    );
    final imageItem = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_image',
            'type': 'imageGeneration',
            'status': 'completed',
            'revisedPrompt': 'Diagram of the new architecture',
          },
        },
      ),
    );

    final userEvent = userItem.single as CodexRuntimeItemCompletedEvent;
    final reviewEvent = reviewItem.single as CodexRuntimeItemCompletedEvent;
    final imageEvent = imageItem.single as CodexRuntimeItemCompletedEvent;

    expect(userEvent.itemType, CodexCanonicalItemType.userMessage);
    expect(userEvent.detail, 'Ship the fix');
    expect(reviewEvent.itemType, CodexCanonicalItemType.reviewEntered);
    expect(reviewEvent.detail, 'Checking the patch set');
    expect(imageEvent.itemType, CodexCanonicalItemType.imageGeneration);
    expect(imageEvent.detail, 'Diagram of the new architecture');
  });

  test(
    'maps request approval and serverRequest/resolved into canonical request events',
    () {
      final mapper = CodexRuntimeEventMapper();

      final requestOpened = mapper.mapEvent(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_123',
            'itemId': 'item_123',
            'reason': 'Write files',
          },
        ),
      );
      final requestResolved = mapper.mapEvent(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
        ),
      );

      final openedEvent =
          requestOpened.single as CodexRuntimeRequestOpenedEvent;
      final resolvedEvent =
          requestResolved.single as CodexRuntimeRequestResolvedEvent;

      expect(
        openedEvent.requestType,
        CodexCanonicalRequestType.fileChangeApproval,
      );
      expect(openedEvent.detail, 'Write files');
      expect(resolvedEvent.requestId, 'i:99');
      expect(
        resolvedEvent.requestType,
        CodexCanonicalRequestType.fileChangeApproval,
      );
    },
  );

  test('maps mcp elicitation requests into canonical request events', () {
    final mapper = CodexRuntimeEventMapper();

    final requestOpened = mapper.mapEvent(
      const CodexAppServerRequestEvent(
        requestId: 's:elicitation-1',
        method: 'mcpServer/elicitation/request',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'serverName': 'filesystem',
          'message': 'Choose a directory',
          'mode': 'form',
        },
      ),
    );

    final openedEvent = requestOpened.single as CodexRuntimeRequestOpenedEvent;
    expect(
      openedEvent.requestType,
      CodexCanonicalRequestType.mcpServerElicitation,
    );
    expect(openedEvent.detail, 'Choose a directory');
  });

  test('maps user input requests and answered notifications', () {
    final mapper = CodexRuntimeEventMapper();

    final requested = mapper.mapEvent(
      const CodexAppServerRequestEvent(
        requestId: 's:user-input-1',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'questions': <Object>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Name',
              'question': 'What is your name?',
              'options': <Object>[
                <String, Object?>{
                  'label': 'Vince',
                  'description': 'Use the saved profile name.',
                },
              ],
            },
          ],
        },
      ),
    );
    final answered = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/tool/requestUserInput/answered',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'requestId': 'user-input-1',
          'answers': <String, Object?>{
            'q1': <String, Object?>{
              'answers': <String>['Vince'],
            },
          },
        },
      ),
    );

    final requestedEvent =
        requested.single as CodexRuntimeUserInputRequestedEvent;
    final answeredEvent = answered.single as CodexRuntimeUserInputResolvedEvent;

    expect(requestedEvent.requestId, 's:user-input-1');
    expect(requestedEvent.questions, hasLength(1));
    expect(requestedEvent.questions.single.id, 'q1');
    expect(answeredEvent.requestId, 's:user-input-1');
    expect(answeredEvent.answers['q1'], <String>['Vince']);
  });
}
