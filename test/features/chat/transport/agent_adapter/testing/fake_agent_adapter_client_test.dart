import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

void main() {
  test('stays adapter-neutral and avoids Codex defaults', () async {
    final client = FakeAgentAdapterClient();

    expect(client, isNot(isA<FakeCodexAppServerClient>()));

    final summary = await client.readThread(threadId: 'thread_adapter');
    final history = await client.readThreadWithTurns(
      threadId: 'thread_adapter',
    );

    expect(summary.id, 'thread_adapter');
    expect(summary.sourceKind, isNull);
    expect(history.id, 'thread_adapter');
    expect(history.sourceKind, isNull);
    expect(history.turns, isEmpty);
  });

  test('preserves configured adapter history turns', () async {
    final client = FakeAgentAdapterClient();
    client.threadsById['thread_saved'] = const AgentAdapterThreadHistory(
      id: 'thread_saved',
      turns: <AgentAdapterHistoryTurn>[
        AgentAdapterHistoryTurn(
          id: 'turn_saved',
          items: <AgentAdapterHistoryItem>[
            AgentAdapterHistoryItem(
              id: 'item_saved',
              type: 'agent_message',
              status: 'completed',
              raw: <String, dynamic>{'text': 'Adapter restore'},
            ),
          ],
          raw: <String, dynamic>{'id': 'turn_saved'},
        ),
      ],
    );

    final history = await client.readThreadWithTurns(threadId: 'thread_saved');

    expect(history.id, 'thread_saved');
    expect(history.turns, hasLength(1));
    expect(history.turns.single.id, 'turn_saved');
    expect(history.turns.single.items, hasLength(1));
    expect(history.turns.single.items.single.id, 'item_saved');
  });

  test(
    'tracks pending requests without Codex method-name validation',
    () async {
      final client = FakeAgentAdapterClient();
      client.emit(
        const AgentAdapterRequestEvent(
          requestId: 'req_adapter',
          method: 'adapter/requestApproval',
          params: <String, Object?>{'scope': 'workspace-write'},
        ),
      );

      await client.resolveApproval(requestId: 'req_adapter', approved: true);

      expect(client.approvalDecisions.single, (
        requestId: 'req_adapter',
        approved: true,
      ));
      expect(client.pendingServerRequestMethodsById, isEmpty);
    },
  );
}
