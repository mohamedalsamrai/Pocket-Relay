import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';

void main() {
  test('maps transport connect and disconnect into session runtime events', () {
    final mapper = CodexRuntimeEventMapper();

    final connectedEvents = mapper.mapEvent(
      const CodexAppServerConnectedEvent(userAgent: 'codex-cli/0.114.0'),
    );
    final disconnectedEvents = mapper.mapEvent(
      const CodexAppServerDisconnectedEvent(exitCode: 0),
    );

    expect(connectedEvents, hasLength(1));
    expect(connectedEvents[0], isA<CodexRuntimeSessionStateChangedEvent>());
    expect(
      (connectedEvents[0] as CodexRuntimeSessionStateChangedEvent).state,
      CodexRuntimeSessionState.ready,
    );

    expect(disconnectedEvents.single, isA<CodexRuntimeSessionExitedEvent>());
    expect(
      (disconnectedEvents.single as CodexRuntimeSessionExitedEvent).exitKind,
      CodexRuntimeSessionExitKind.graceful,
    );
  });

  test('maps thread, turn, item, and content notifications', () {
    final mapper = CodexRuntimeEventMapper();

    final threadStarted = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_123'},
        },
      ),
    );
    final turnStarted = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_123',
            'model': 'gpt-5.3-codex',
            'effort': 'high',
          },
        },
      ),
    );
    final itemStarted = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_123',
            'type': 'agentMessage',
            'status': 'inProgress',
            'text': 'Draft response',
          },
        },
      ),
    );
    final delta = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'delta': 'Hello',
        },
      ),
    );

    final threadEvent = threadStarted.single as CodexRuntimeThreadStartedEvent;
    final turnEvent = turnStarted.single as CodexRuntimeTurnStartedEvent;
    final itemEvent = itemStarted.single as CodexRuntimeItemStartedEvent;
    final deltaEvent = delta.single as CodexRuntimeContentDeltaEvent;

    expect(threadEvent.providerThreadId, 'thread_123');
    expect(turnEvent.turnId, 'turn_123');
    expect(turnEvent.model, 'gpt-5.3-codex');
    expect(itemEvent.itemType, CodexCanonicalItemType.assistantMessage);
    expect(itemEvent.status, CodexRuntimeItemStatus.inProgress);
    expect(itemEvent.detail, 'Draft response');
    expect(deltaEvent.streamKind, CodexRuntimeContentStreamKind.assistantText);
    expect(deltaEvent.delta, 'Hello');
  });

  test('maps turn started effort from reasoning effort field variants', () {
    final mapper = CodexRuntimeEventMapper();

    final camelCaseEvent = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_camel',
            'model': 'gpt-5.4',
            'reasoningEffort': 'xhigh',
          },
        },
      ),
    );
    final snakeCaseEvent = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_snake',
            'model': 'gpt-5.4',
            'reasoning_effort': 'high',
          },
        },
      ),
    );

    expect(
      (camelCaseEvent.single as CodexRuntimeTurnStartedEvent).effort,
      'xhigh',
    );
    expect(
      (snakeCaseEvent.single as CodexRuntimeTurnStartedEvent).effort,
      'high',
    );
  });

  test('preserves whitespace in streaming content deltas', () {
    final mapper = CodexRuntimeEventMapper();

    final leadingSpace = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'delta': ' shell',
        },
      ),
    );
    final spaceOnly = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'delta': ' ',
        },
      ),
    );

    expect(
      (leadingSpace.single as CodexRuntimeContentDeltaEvent).delta,
      ' shell',
    );
    expect((spaceOnly.single as CodexRuntimeContentDeltaEvent).delta, ' ');
  });
}
