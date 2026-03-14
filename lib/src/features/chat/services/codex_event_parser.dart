import 'dart:convert';

import 'package:codex_pocket/src/features/chat/models/codex_remote_event.dart';
import 'package:codex_pocket/src/features/chat/models/conversation_entry.dart';

class ParsedCodexLine {
  const ParsedCodexLine({this.events = const [], this.usage});

  final List<CodexRemoteEvent> events;
  final TurnUsage? usage;
}

class CodexEventParser {
  const CodexEventParser();

  ParsedCodexLine parseLine(String line) {
    final event = jsonDecode(line) as Map<String, dynamic>;
    final type = event['type'] as String? ?? 'unknown';
    final events = <CodexRemoteEvent>[];
    TurnUsage? usage;

    switch (type) {
      case 'thread.started':
        final threadId = event['thread_id'] as String?;
        if (threadId != null && threadId.isNotEmpty) {
          events.add(ThreadStartedEvent(threadId));
        }
        break;
      case 'turn.started':
        events.add(
          const InformationalEvent(
            message: 'Codex turn started.',
            isError: false,
          ),
        );
        break;
      case 'item.started':
      case 'item.completed':
        final item = event['item'];
        if (item is Map<String, dynamic>) {
          final entry = _entryFromItem(item, phase: type);
          if (entry != null) {
            events.add(EntryUpsertedEvent(entry));
          }
        }
        break;
      case 'turn.completed':
        final rawUsage = event['usage'] as Map<String, dynamic>?;
        usage = TurnUsage(
          inputTokens: (rawUsage?['input_tokens'] as num?)?.toInt(),
          cachedInputTokens: (rawUsage?['cached_input_tokens'] as num?)
              ?.toInt(),
          outputTokens: (rawUsage?['output_tokens'] as num?)?.toInt(),
        );
        break;
      case 'error':
        events.add(
          InformationalEvent(
            message: event['message'] as String? ?? 'Remote Codex error.',
            isError: true,
          ),
        );
        break;
      default:
        events.add(
          InformationalEvent(
            message: 'Unhandled Codex event: $type',
            isError: false,
          ),
        );
        break;
    }

    return ParsedCodexLine(events: events, usage: usage);
  }

  ConversationEntry? _entryFromItem(
    Map<String, dynamic> item, {
    required String phase,
  }) {
    final id =
        item['id'] as String? ??
        'item_${DateTime.now().microsecondsSinceEpoch}';
    final itemType = item['type'] as String? ?? 'unknown';
    final now = DateTime.now();

    switch (itemType) {
      case 'agent_message':
        final text = item['text'] as String? ?? '';
        if (text.trim().isEmpty) {
          return null;
        }

        return ConversationEntry(
          id: id,
          kind: ConversationEntryKind.assistant,
          title: 'Codex',
          body: text.trim(),
          createdAt: now,
        );
      case 'command_execution':
        final status = item['status'] as String?;
        final isRunning = phase == 'item.started' || status == 'in_progress';

        return ConversationEntry(
          id: id,
          kind: ConversationEntryKind.command,
          title: item['command'] as String? ?? 'Command',
          body: (item['aggregated_output'] as String? ?? '').trim(),
          createdAt: now,
          isRunning: isRunning,
          exitCode: (item['exit_code'] as num?)?.toInt(),
        );
      default:
        final payload = const JsonEncoder.withIndent('  ').convert(item);
        return ConversationEntry(
          id: id,
          kind: ConversationEntryKind.status,
          title: itemType.replaceAll('_', ' '),
          body: payload,
          createdAt: now,
        );
    }
  }
}
