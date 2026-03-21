part of 'runtime_event_mapper.dart';

List<CodexRuntimeEvent> _mapRuntimeHistoricalConversation(
  CodexHistoricalConversation conversation,
) {
  final events = <CodexRuntimeEvent>[
    CodexRuntimeThreadStartedEvent(
      createdAt: conversation.createdAt,
      threadId: conversation.threadId,
      providerThreadId: conversation.threadId,
      rawMethod: 'thread/read(response)',
      threadName: conversation.threadName,
      sourceKind: conversation.sourceKind,
      agentNickname: conversation.agentNickname,
      agentRole: conversation.agentRole,
    ),
  ];

  for (final turn in conversation.turns) {
    events.add(
      CodexRuntimeTurnStartedEvent(
        createdAt: turn.createdAt,
        threadId: turn.threadId,
        turnId: turn.id,
        rawMethod: 'thread/read(turn)',
        rawPayload: turn.snapshot,
        model: turn.model,
        effort: turn.effort,
      ),
    );

    for (final entry in turn.entries) {
      final rawPayload = <String, Object?>{
        'threadId': entry.threadId,
        'turnId': entry.turnId,
        'itemId': entry.id,
        'item': entry.snapshot,
      };
      events.add(_buildHistoricalLifecycleEvent(entry, rawPayload: rawPayload));
    }

    events.add(
      CodexRuntimeTurnCompletedEvent(
        createdAt: turn.completedAt,
        threadId: turn.threadId,
        turnId: turn.id,
        rawMethod: 'thread/read(turn)',
        rawPayload: turn.snapshot,
        state: turn.state,
        stopReason: turn.stopReason,
        usage: turn.usage,
        modelUsage: turn.modelUsage,
        totalCostUsd: turn.totalCostUsd,
        errorMessage: turn.errorMessage,
      ),
    );
  }

  return events;
}

CodexRuntimeItemLifecycleEvent _buildHistoricalLifecycleEvent(
  CodexHistoricalEntry entry, {
  required Object? rawPayload,
}) {
  if (entry.status == CodexRuntimeItemStatus.inProgress) {
    return CodexRuntimeItemStartedEvent(
      createdAt: entry.createdAt,
      itemType: entry.itemType,
      threadId: entry.threadId,
      turnId: entry.turnId,
      itemId: entry.id,
      status: entry.status,
      rawMethod: 'thread/read(item)',
      rawPayload: rawPayload,
      title: entry.title,
      detail: entry.detail,
      snapshot: entry.snapshot,
      collaboration: entry.collaboration,
    );
  }

  return CodexRuntimeItemCompletedEvent(
    createdAt: entry.createdAt,
    itemType: entry.itemType,
    threadId: entry.threadId,
    turnId: entry.turnId,
    itemId: entry.id,
    status: entry.status,
    rawMethod: 'thread/read(item)',
    rawPayload: rawPayload,
    title: entry.title,
    detail: entry.detail,
    snapshot: entry.snapshot,
    collaboration: entry.collaboration,
  );
}
