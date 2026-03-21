part of 'codex_runtime_event.dart';

final class CodexRuntimeSessionStateChangedEvent extends CodexRuntimeEvent {
  const CodexRuntimeSessionStateChangedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
  });

  final CodexRuntimeSessionState state;
  final String? reason;
}

final class CodexRuntimeSessionExitedEvent extends CodexRuntimeEvent {
  const CodexRuntimeSessionExitedEvent({
    required super.createdAt,
    required this.exitKind,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
    this.exitCode,
  });

  final CodexRuntimeSessionExitKind exitKind;
  final String? reason;
  final int? exitCode;
}

final class CodexRuntimeThreadStartedEvent extends CodexRuntimeEvent {
  const CodexRuntimeThreadStartedEvent({
    required super.createdAt,
    required this.providerThreadId,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.threadName,
    this.sourceKind,
    this.agentNickname,
    this.agentRole,
  });

  final String providerThreadId;
  final String? threadName;
  final String? sourceKind;
  final String? agentNickname;
  final String? agentRole;
}

final class CodexRuntimeThreadStateChangedEvent extends CodexRuntimeEvent {
  const CodexRuntimeThreadStateChangedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
  });

  final CodexRuntimeThreadState state;
  final Object? detail;
}

final class CodexRuntimeTurnStartedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnStartedEvent({
    required super.createdAt,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.model,
    this.effort,
  });

  final String? model;
  final String? effort;
}

final class CodexRuntimeTurnCompletedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnCompletedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.stopReason,
    this.usage,
    this.modelUsage,
    this.totalCostUsd,
    this.errorMessage,
  });

  final CodexRuntimeTurnState state;
  final String? stopReason;
  final CodexRuntimeTurnUsage? usage;
  final Map<String, dynamic>? modelUsage;
  final double? totalCostUsd;
  final String? errorMessage;
}

final class CodexRuntimeTurnAbortedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnAbortedEvent({
    required super.createdAt,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
  });

  final String? reason;
}

final class CodexRuntimeTurnPlanUpdatedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnPlanUpdatedEvent({
    required super.createdAt,
    required this.steps,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.explanation,
  });

  final String? explanation;
  final List<CodexRuntimePlanStep> steps;
}

sealed class CodexRuntimeItemLifecycleEvent extends CodexRuntimeEvent {
  const CodexRuntimeItemLifecycleEvent({
    required super.createdAt,
    required this.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required this.status,
    super.rawMethod,
    super.rawPayload,
    this.title,
    this.detail,
    this.snapshot,
    this.collaboration,
  });

  final CodexCanonicalItemType itemType;
  final CodexRuntimeItemStatus status;
  final String? title;
  final String? detail;
  final Map<String, dynamic>? snapshot;
  final CodexRuntimeCollabAgentToolCall? collaboration;
}

final class CodexRuntimeItemStartedEvent
    extends CodexRuntimeItemLifecycleEvent {
  const CodexRuntimeItemStartedEvent({
    required super.createdAt,
    required super.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.status,
    super.rawMethod,
    super.rawPayload,
    super.title,
    super.detail,
    super.snapshot,
    super.collaboration,
  });
}

final class CodexRuntimeItemUpdatedEvent
    extends CodexRuntimeItemLifecycleEvent {
  const CodexRuntimeItemUpdatedEvent({
    required super.createdAt,
    required super.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.status,
    super.rawMethod,
    super.rawPayload,
    super.title,
    super.detail,
    super.snapshot,
    super.collaboration,
  });
}

final class CodexRuntimeItemCompletedEvent
    extends CodexRuntimeItemLifecycleEvent {
  const CodexRuntimeItemCompletedEvent({
    required super.createdAt,
    required super.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.status,
    super.rawMethod,
    super.rawPayload,
    super.title,
    super.detail,
    super.snapshot,
    super.collaboration,
  });
}

final class CodexRuntimeContentDeltaEvent extends CodexRuntimeEvent {
  const CodexRuntimeContentDeltaEvent({
    required super.createdAt,
    required this.streamKind,
    required this.delta,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    super.rawMethod,
    super.rawPayload,
    this.contentIndex,
    this.summaryIndex,
  });

  final CodexRuntimeContentStreamKind streamKind;
  final String delta;
  final int? contentIndex;
  final int? summaryIndex;
}
