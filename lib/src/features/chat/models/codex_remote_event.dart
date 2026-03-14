import 'package:pocket_relay/src/features/chat/models/conversation_entry.dart';

sealed class CodexRemoteEvent {
  const CodexRemoteEvent();
}

class ThreadStartedEvent extends CodexRemoteEvent {
  const ThreadStartedEvent(this.threadId);

  final String threadId;
}

class EntryUpsertedEvent extends CodexRemoteEvent {
  const EntryUpsertedEvent(this.entry);

  final ConversationEntry entry;
}

class InformationalEvent extends CodexRemoteEvent {
  const InformationalEvent({required this.message, required this.isError});

  final String message;
  final bool isError;
}

class TurnUsage {
  const TurnUsage({
    this.inputTokens,
    this.cachedInputTokens,
    this.outputTokens,
  });

  final int? inputTokens;
  final int? cachedInputTokens;
  final int? outputTokens;
}

class TurnFinishedEvent extends CodexRemoteEvent {
  const TurnFinishedEvent({this.exitCode, this.usage});

  final int? exitCode;
  final TurnUsage? usage;
}
