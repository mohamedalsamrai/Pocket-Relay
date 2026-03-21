part of 'codex_runtime_event.dart';

final class CodexRuntimeRequestOpenedEvent extends CodexRuntimeEvent {
  const CodexRuntimeRequestOpenedEvent({
    required super.createdAt,
    required this.requestType,
    required super.threadId,
    required super.requestId,
    super.turnId,
    super.itemId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
    this.args,
  });

  final CodexCanonicalRequestType requestType;
  final String? detail;
  final Object? args;
}

final class CodexRuntimeRequestResolvedEvent extends CodexRuntimeEvent {
  const CodexRuntimeRequestResolvedEvent({
    required super.createdAt,
    required this.requestType,
    required super.threadId,
    required super.requestId,
    super.turnId,
    super.itemId,
    super.rawMethod,
    super.rawPayload,
    this.resolution,
  });

  final CodexCanonicalRequestType requestType;
  final Object? resolution;
}

final class CodexRuntimeUserInputRequestedEvent extends CodexRuntimeEvent {
  const CodexRuntimeUserInputRequestedEvent({
    required super.createdAt,
    required this.questions,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final List<CodexRuntimeUserInputQuestion> questions;
}

final class CodexRuntimeUserInputResolvedEvent extends CodexRuntimeEvent {
  const CodexRuntimeUserInputResolvedEvent({
    required super.createdAt,
    required this.answers,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final Map<String, List<String>> answers;
}
