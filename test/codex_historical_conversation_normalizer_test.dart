import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/application/codex_historical_conversation_normalizer.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_thread_read_decoder.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

void main() {
  const decoder = CodexAppServerThreadReadDecoder();
  const normalizer = CodexHistoricalConversationNormalizer();

  test(
    'normalizes thread/read history into canonical conversation snapshot',
    () {
      final thread = decoder.decodeHistoryResponse(
        _loadFixture(
          'test/fixtures/app_server/thread_read/reference_nested_history.json',
        ),
        fallbackThreadId: 'thread_nested',
      );

      final conversation = normalizer.normalize(thread);

      expect(conversation.threadId, 'thread_nested');
      expect(conversation.threadName, 'Saved thread');
      expect(conversation.sourceKind, 'app-server');
      expect(conversation.agentNickname, 'builder');
      expect(conversation.agentRole, 'worker');
      expect(conversation.turns, hasLength(1));

      final turn = conversation.turns.single;
      expect(turn.id, 'turn_saved');
      expect(turn.threadId, 'thread_nested');
      expect(turn.state, CodexRuntimeTurnState.completed);
      expect(turn.entries, hasLength(2));

      final userEntry = turn.entries.first;
      expect(userEntry.itemType, CodexCanonicalItemType.userMessage);
      expect(userEntry.title, 'You');
      expect(userEntry.detail, 'Restore this');

      final assistantEntry = turn.entries.last;
      expect(assistantEntry.itemType, CodexCanonicalItemType.assistantMessage);
      expect(assistantEntry.title, 'Codex');
      expect(assistantEntry.detail, 'Restored answer');
    },
  );
}

Map<String, dynamic> _loadFixture(String path) {
  final text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}
