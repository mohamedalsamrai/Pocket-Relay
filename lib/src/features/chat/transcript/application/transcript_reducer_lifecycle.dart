part of 'transcript_reducer.dart';

CodexAgentLifecycleState? _lifecycleOverrideForEventImpl(
  CodexTimelineState? timeline,
  CodexRuntimeEvent event,
) {
  return switch (event) {
    CodexRuntimeTurnStartedEvent() => CodexAgentLifecycleState.running,
    CodexRuntimeTurnCompletedEvent(:final state) => switch (state) {
      CodexRuntimeTurnState.completed => CodexAgentLifecycleState.completed,
      CodexRuntimeTurnState.failed => CodexAgentLifecycleState.failed,
      CodexRuntimeTurnState.interrupted ||
      CodexRuntimeTurnState.cancelled => CodexAgentLifecycleState.aborted,
    },
    CodexRuntimeTurnAbortedEvent() => CodexAgentLifecycleState.aborted,
    CodexRuntimeRequestOpenedEvent(:final requestType) =>
      requestType == CodexCanonicalRequestType.toolUserInput ||
              requestType == CodexCanonicalRequestType.mcpServerElicitation
          ? CodexAgentLifecycleState.blockedOnInput
          : CodexAgentLifecycleState.blockedOnApproval,
    CodexRuntimeUserInputRequestedEvent() =>
      CodexAgentLifecycleState.blockedOnInput,
    CodexRuntimeThreadStateChangedEvent(:final state) =>
      _lifecycleForThreadStateImpl(
        state,
        fallback: timeline?.lifecycleState ?? CodexAgentLifecycleState.unknown,
      ),
    CodexRuntimeItemLifecycleEvent(:final collaboration?) =>
      _lifecycleOverrideForCollaborationImpl(timeline, collaboration),
    _ => null,
  };
}

CodexAgentLifecycleState _inferLifecycleStateImpl(
  CodexTimelineState existingTimeline,
  CodexSessionState reducedProjectedState,
  CodexRuntimeEvent? event,
) {
  final override = event == null
      ? null
      : _lifecycleOverrideForEventImpl(existingTimeline, event);
  if (override != null) {
    return override;
  }

  if (reducedProjectedState.pendingUserInputRequests.isNotEmpty) {
    return CodexAgentLifecycleState.blockedOnInput;
  }
  if (reducedProjectedState.pendingApprovalRequests.isNotEmpty) {
    return CodexAgentLifecycleState.blockedOnApproval;
  }
  if (reducedProjectedState.activeTurn != null) {
    return switch (existingTimeline.lifecycleState) {
      CodexAgentLifecycleState.waitingOnChild =>
        CodexAgentLifecycleState.waitingOnChild,
      _ => CodexAgentLifecycleState.running,
    };
  }
  return switch (existingTimeline.lifecycleState) {
    CodexAgentLifecycleState.completed ||
    CodexAgentLifecycleState.failed ||
    CodexAgentLifecycleState.aborted ||
    CodexAgentLifecycleState.closed => existingTimeline.lifecycleState,
    _ => CodexAgentLifecycleState.idle,
  };
}

CodexAgentLifecycleState _lifecycleForThreadStateImpl(
  CodexRuntimeThreadState threadState, {
  required CodexAgentLifecycleState fallback,
}) {
  return switch (threadState) {
    CodexRuntimeThreadState.active => CodexAgentLifecycleState.running,
    CodexRuntimeThreadState.idle => CodexAgentLifecycleState.idle,
    CodexRuntimeThreadState.archived => fallback,
    CodexRuntimeThreadState.closed => CodexAgentLifecycleState.closed,
    CodexRuntimeThreadState.compacted => fallback,
    CodexRuntimeThreadState.error => CodexAgentLifecycleState.failed,
  };
}

CodexAgentLifecycleState _lifecycleFromCollaborationImpl(
  CodexRuntimeCollabAgentToolCall collaboration,
  String receiverThreadId,
) {
  final agentState = collaboration.agentsStates[receiverThreadId];
  if (agentState != null) {
    return switch (agentState.status) {
      CodexRuntimeCollabAgentStatus.pendingInit =>
        CodexAgentLifecycleState.starting,
      CodexRuntimeCollabAgentStatus.running => CodexAgentLifecycleState.running,
      CodexRuntimeCollabAgentStatus.completed =>
        CodexAgentLifecycleState.completed,
      CodexRuntimeCollabAgentStatus.errored ||
      CodexRuntimeCollabAgentStatus.notFound => CodexAgentLifecycleState.failed,
      CodexRuntimeCollabAgentStatus.shutdown => CodexAgentLifecycleState.closed,
      CodexRuntimeCollabAgentStatus.unknown => CodexAgentLifecycleState.unknown,
    };
  }

  return switch (collaboration.tool) {
    CodexRuntimeCollabAgentTool.spawnAgent =>
      collaboration.status == CodexRuntimeCollabAgentToolCallStatus.failed
          ? CodexAgentLifecycleState.failed
          : CodexAgentLifecycleState.starting,
    CodexRuntimeCollabAgentTool.closeAgent =>
      collaboration.status == CodexRuntimeCollabAgentToolCallStatus.completed
          ? CodexAgentLifecycleState.closed
          : CodexAgentLifecycleState.running,
    CodexRuntimeCollabAgentTool.resumeAgent ||
    CodexRuntimeCollabAgentTool.sendInput => CodexAgentLifecycleState.running,
    CodexRuntimeCollabAgentTool.wait => CodexAgentLifecycleState.running,
    CodexRuntimeCollabAgentTool.unknown => CodexAgentLifecycleState.unknown,
  };
}

CodexAgentLifecycleState? _lifecycleOverrideForCollaborationImpl(
  CodexTimelineState? timeline,
  CodexRuntimeCollabAgentToolCall? collaboration,
) {
  if (collaboration == null) {
    return null;
  }

  return switch (collaboration.tool) {
    CodexRuntimeCollabAgentTool.wait => switch (collaboration.status) {
      CodexRuntimeCollabAgentToolCallStatus.inProgress =>
        CodexAgentLifecycleState.waitingOnChild,
      CodexRuntimeCollabAgentToolCallStatus.completed ||
      CodexRuntimeCollabAgentToolCallStatus.failed ||
      CodexRuntimeCollabAgentToolCallStatus.unknown =>
        _activeOrIdleLifecycleImpl(timeline),
    },
    CodexRuntimeCollabAgentTool.spawnAgent ||
    CodexRuntimeCollabAgentTool.resumeAgent ||
    CodexRuntimeCollabAgentTool.sendInput ||
    CodexRuntimeCollabAgentTool.closeAgent => _activeOrIdleLifecycleImpl(
      timeline,
    ),
    CodexRuntimeCollabAgentTool.unknown => null,
  };
}

CodexAgentLifecycleState _activeOrIdleLifecycleImpl(
  CodexTimelineState? timeline,
) {
  return timeline?.activeTurn != null
      ? CodexAgentLifecycleState.running
      : CodexAgentLifecycleState.idle;
}

CodexThreadRegistryEntry _upsertRegistryEntryImpl(
  CodexThreadRegistryEntry? existing, {
  required String threadId,
  required int displayOrder,
  required bool isPrimary,
  required String? threadName,
  required String? sourceKind,
  required String? agentNickname,
  required String? agentRole,
  required bool isClosed,
  required String? parentThreadId,
  required String? spawnItemId,
  required List<String>? childThreadIds,
}) {
  return (existing ??
          CodexThreadRegistryEntry(
            threadId: threadId,
            displayOrder: displayOrder,
          ))
      .copyWith(
        displayOrder: displayOrder,
        isPrimary: isPrimary,
        threadName: threadName,
        sourceKind: sourceKind,
        agentNickname: agentNickname,
        agentRole: agentRole,
        isClosed: isClosed,
        parentThreadId: parentThreadId,
        spawnItemId: spawnItemId,
        childThreadIds: childThreadIds,
      );
}

int _nextDisplayOrderImpl(Map<String, CodexThreadRegistryEntry> registry) {
  var maxOrder = -1;
  for (final entry in registry.values) {
    if (entry.displayOrder > maxOrder) {
      maxOrder = entry.displayOrder;
    }
  }
  return maxOrder + 1;
}

List<String> _mergedChildThreadIdsImpl(
  List<String>? existingChildThreadIds,
  List<String> nextChildThreadIds,
) {
  final merged = <String>{...?existingChildThreadIds, ...nextChildThreadIds};
  return merged.toList(growable: false);
}
