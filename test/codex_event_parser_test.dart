import 'package:pocket_relay/src/features/chat/models/codex_remote_event.dart';
import 'package:pocket_relay/src/features/chat/models/conversation_entry.dart';
import 'package:pocket_relay/src/features/chat/services/codex_event_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = CodexEventParser();

  test('parses command start and completion events into upserts', () {
    final started = parser.parseLine(
      '{"type":"item.started","item":{"id":"cmd_1","type":"command_execution","command":"pwd"}}',
    );
    final completed = parser.parseLine(
      '{"type":"item.completed","item":{"id":"cmd_1","type":"command_execution","command":"pwd","aggregated_output":"/tmp","exit_code":0,"status":"completed"}}',
    );

    expect(started.events.single, isA<EntryUpsertedEvent>());
    expect(completed.events.single, isA<EntryUpsertedEvent>());

    final startedEntry = (started.events.single as EntryUpsertedEvent).entry;
    final completedEntry =
        (completed.events.single as EntryUpsertedEvent).entry;

    expect(startedEntry.kind, ConversationEntryKind.command);
    expect(startedEntry.isRunning, isTrue);
    expect(completedEntry.isRunning, isFalse);
    expect(completedEntry.exitCode, 0);
    expect(completedEntry.body, '/tmp');
  });

  test('captures turn usage from completion events', () {
    final parsed = parser.parseLine(
      '{"type":"turn.completed","usage":{"input_tokens":123,"cached_input_tokens":45,"output_tokens":67}}',
    );

    expect(parsed.events, isEmpty);
    expect(parsed.usage?.inputTokens, 123);
    expect(parsed.usage?.cachedInputTokens, 45);
    expect(parsed.usage?.outputTokens, 67);
  });

  test('ignores legacy protocol events that are not transcript signals', () {
    final unknownEvent = parser.parseLine('{"type":"turn.started"}');
    final unknownItem = parser.parseLine(
      '{"type":"item.completed","item":{"id":"plan_1","type":"plan","text":"Do the work"}}',
    );

    expect(unknownEvent.events, isEmpty);
    expect(unknownItem.events, isEmpty);
  });
}
