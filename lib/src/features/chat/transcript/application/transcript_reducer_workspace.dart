part of 'transcript_reducer.dart';

CodexSessionState _reduceWorkspaceRuntimeEventImpl(
  TranscriptReducer reducer,
  CodexSessionState state,
  CodexRuntimeEvent event,
) {
  switch (event) {
    case CodexRuntimeSessionStateChangedEvent():
      return _withUpdatedGlobalConnectionStatusImpl(state, event.state);
    case CodexRuntimeSessionExitedEvent():
      return _reduceSessionExitedImpl(reducer, state, event);
    case CodexRuntimeThreadStartedEvent():
      return _upsertThreadStartedImpl(state, event);
    case CodexRuntimeThreadStateChangedEvent():
      return _reduceThreadStateChangedImpl(reducer, state, event);
    case CodexRuntimeSshAuthenticatedEvent() ||
        CodexRuntimeSshRemoteProcessStartedEvent():
      return state;
    default:
      break;
  }

  final targetThreadId = _targetThreadIdForEventImpl(state, event);
  if (targetThreadId == null) {
    return state;
  }

  var nextState = _applyCollaborationMetadataImpl(
    state,
    event,
    targetThreadId: targetThreadId,
  );
  nextState = _reduceTimelineStateImpl(
    reducer,
    nextState,
    threadId: targetThreadId,
    event: event,
    reducerFn: (projectedState) => _reduceSessionTranscriptRuntimeEventImpl(
      reducer,
      projectedState,
      event,
    ),
    lifecycleOverride: _lifecycleOverrideForEventImpl(
      nextState.timelineForThread(targetThreadId),
      event,
    ),
  );
  return nextState;
}

CodexSessionState _withUpdatedGlobalConnectionStatusImpl(
  CodexSessionState state,
  CodexRuntimeSessionState nextStatus,
) {
  final nextTimelines = <String, CodexTimelineState>{};
  for (final entry in state.timelinesByThreadId.entries) {
    nextTimelines[entry.key] = entry.value.copyWith(
      connectionStatus: nextStatus,
    );
  }
  return state.copyWith(
    connectionStatus: nextStatus,
    timelinesByThreadId: nextTimelines,
  );
}

CodexSessionState _reduceSessionExitedImpl(
  TranscriptReducer reducer,
  CodexSessionState state,
  CodexRuntimeSessionExitedEvent event,
) {
  var nextState = state.copyWith(
    connectionStatus: event.exitKind == CodexRuntimeSessionExitKind.error
        ? CodexRuntimeSessionState.error
        : CodexRuntimeSessionState.stopped,
  );

  final orderedThreadIds = nextState.timelinesByThreadId.keys.toList(
    growable: false,
  );
  for (final threadId in orderedThreadIds) {
    nextState = _reduceTimelineStateImpl(
      reducer,
      nextState,
      threadId: threadId,
      event: event,
      reducerFn: (projectedState) => _reduceSessionTranscriptRuntimeEventImpl(
        reducer,
        projectedState,
        event,
      ),
      lifecycleOverride: CodexAgentLifecycleState.closed,
    );
  }

  final nextRegistry = <String, CodexThreadRegistryEntry>{};
  for (final entry in nextState.threadRegistry.entries) {
    nextRegistry[entry.key] = entry.value.copyWith(isClosed: true);
  }
  return nextState.copyWith(threadRegistry: nextRegistry);
}

CodexSessionState _upsertThreadStartedImpl(
  CodexSessionState state,
  CodexRuntimeThreadStartedEvent event,
) {
  final threadId = event.providerThreadId;
  final nextTimelines = <String, CodexTimelineState>{
    ...state.timelinesByThreadId,
  };
  final existingTimeline = nextTimelines[threadId];
  nextTimelines[threadId] =
      existingTimeline ??
      CodexTimelineState(
        threadId: threadId,
        connectionStatus: state.connectionStatus,
        lifecycleState: CodexAgentLifecycleState.idle,
      );

  final nextRegistry = <String, CodexThreadRegistryEntry>{
    ...state.threadRegistry,
  };
  nextRegistry[threadId] = _upsertRegistryEntryImpl(
    nextRegistry[threadId],
    threadId: threadId,
    isPrimary: state.rootThreadId == null
        ? true
        : nextRegistry[threadId]?.isPrimary == true,
    threadName: event.threadName,
    sourceKind: event.sourceKind,
    agentNickname: event.agentNickname,
    agentRole: event.agentRole,
    isClosed: false,
    parentThreadId: nextRegistry[threadId]?.parentThreadId,
    spawnItemId: nextRegistry[threadId]?.spawnItemId,
    displayOrder:
        nextRegistry[threadId]?.displayOrder ??
        (state.rootThreadId == null ? 0 : _nextDisplayOrderImpl(nextRegistry)),
    childThreadIds: nextRegistry[threadId]?.childThreadIds,
  );

  return state.copyWith(
    connectionStatus: state.connectionStatus,
    rootThreadId: state.rootThreadId ?? threadId,
    selectedThreadId: state.selectedThreadId ?? threadId,
    timelinesByThreadId: nextTimelines,
    threadRegistry: nextRegistry,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
  );
}

CodexSessionState _reduceThreadStateChangedImpl(
  TranscriptReducer reducer,
  CodexSessionState state,
  CodexRuntimeThreadStateChangedEvent event,
) {
  final threadId = event.threadId;
  if (threadId == null || threadId.isEmpty) {
    return state;
  }

  if (event.state == CodexRuntimeThreadState.closed) {
    final nextState = _reduceTimelineStateImpl(
      reducer,
      state,
      threadId: threadId,
      event: event,
      reducerFn: (projectedState) => _reduceSessionTranscriptRuntimeEventImpl(
        reducer,
        projectedState,
        event,
      ),
      lifecycleOverride: CodexAgentLifecycleState.closed,
    );
    final nextRegistry = <String, CodexThreadRegistryEntry>{
      ...nextState.threadRegistry,
    };
    final existingEntry = nextRegistry[threadId];
    if (existingEntry != null) {
      nextRegistry[threadId] = existingEntry.copyWith(isClosed: true);
    }
    return nextState.copyWith(threadRegistry: nextRegistry);
  }

  final nextTimelines = <String, CodexTimelineState>{
    ...state.timelinesByThreadId,
  };
  final timeline =
      nextTimelines[threadId] ??
      CodexTimelineState(
        threadId: threadId,
        connectionStatus: state.connectionStatus,
      );
  nextTimelines[threadId] = timeline.copyWith(
    lifecycleState: _lifecycleForThreadStateImpl(
      event.state,
      fallback: timeline.lifecycleState,
    ),
  );

  return state.copyWith(
    timelinesByThreadId: nextTimelines,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
  );
}

CodexSessionState _reduceTimelineStateImpl(
  TranscriptReducer reducer,
  CodexSessionState state, {
  required String threadId,
  required CodexRuntimeEvent? event,
  required CodexSessionState Function(CodexSessionState projectedState)
  reducerFn,
  CodexAgentLifecycleState? lifecycleOverride,
}) {
  final existingTimeline =
      state.timelineForThread(threadId) ??
      CodexTimelineState(
        threadId: threadId,
        connectionStatus: state.connectionStatus,
        lifecycleState: CodexAgentLifecycleState.starting,
      );
  final projectedState = CodexSessionState.transcript(
    connectionStatus: existingTimeline.connectionStatus,
    threadId: existingTimeline.threadId,
    activeTurn: existingTimeline.activeTurn,
    blocks: existingTimeline.blocks,
    pendingLocalUserMessageBlockIds:
        existingTimeline.pendingLocalUserMessageBlockIds,
    localUserMessageProviderBindings:
        existingTimeline.localUserMessageProviderBindings,
    headerMetadata: state.headerMetadata,
  );
  final reducedProjectedState = reducerFn(projectedState);
  final nextTimelines = <String, CodexTimelineState>{
    ...state.timelinesByThreadId,
    threadId: existingTimeline.copyWith(
      connectionStatus: reducedProjectedState.connectionStatus,
      lifecycleState:
          lifecycleOverride ??
          _inferLifecycleStateImpl(
            existingTimeline,
            reducedProjectedState,
            event,
          ),
      activeTurn: reducedProjectedState.activeTurn,
      clearActiveTurn: reducedProjectedState.activeTurn == null,
      blocks: reducedProjectedState.blocks,
      pendingLocalUserMessageBlockIds:
          reducedProjectedState.pendingLocalUserMessageBlockIds,
      localUserMessageProviderBindings:
          reducedProjectedState.localUserMessageProviderBindings,
      hasUnreadActivity: threadId == state.currentThreadId ? false : true,
    ),
  };

  return state.copyWith(
    connectionStatus: reducedProjectedState.connectionStatus,
    timelinesByThreadId: nextTimelines,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
    headerMetadata: reducedProjectedState.headerMetadata,
  );
}

CodexSessionState _promoteSessionTranscriptToWorkspaceImpl(
  CodexSessionState state,
  CodexRuntimeThreadStartedEvent event,
) {
  final rootThreadId = event.providerThreadId;
  final rootTimeline = CodexTimelineState(
    threadId: rootThreadId,
    connectionStatus: state.connectionStatus,
    lifecycleState: state.activeTurn == null
        ? CodexAgentLifecycleState.idle
        : CodexAgentLifecycleState.running,
    activeTurn: state.activeTurn?.copyWith(threadId: rootThreadId),
    blocks: state.blocks,
    pendingLocalUserMessageBlockIds: state.pendingLocalUserMessageBlockIds,
    localUserMessageProviderBindings: state.localUserMessageProviderBindings,
  );
  final threadRegistry = <String, CodexThreadRegistryEntry>{
    rootThreadId: CodexThreadRegistryEntry(
      threadId: rootThreadId,
      displayOrder: 0,
      threadName: event.threadName,
      agentNickname: event.agentNickname,
      agentRole: event.agentRole,
      sourceKind: event.sourceKind,
      isPrimary: true,
    ),
  };
  final timelinesByThreadId = <String, CodexTimelineState>{
    rootThreadId: rootTimeline,
  };

  return CodexSessionState(
    connectionStatus: state.connectionStatus,
    rootThreadId: rootThreadId,
    selectedThreadId: rootThreadId,
    timelinesByThreadId: timelinesByThreadId,
    threadRegistry: threadRegistry,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(timelinesByThreadId),
    headerMetadata: state.headerMetadata,
  );
}

CodexSessionState _applyCollaborationMetadataImpl(
  CodexSessionState state,
  CodexRuntimeEvent event, {
  required String targetThreadId,
}) {
  final collaboration = switch (event) {
    CodexRuntimeItemLifecycleEvent(:final collaboration) => collaboration,
    _ => null,
  };
  if (collaboration == null) {
    return state;
  }

  final nextRegistry = <String, CodexThreadRegistryEntry>{
    ...state.threadRegistry,
  };
  final nextTimelines = <String, CodexTimelineState>{
    ...state.timelinesByThreadId,
  };

  final senderThreadId = collaboration.senderThreadId;
  final senderEntry = _upsertRegistryEntryImpl(
    nextRegistry[senderThreadId],
    threadId: senderThreadId,
    isPrimary: state.rootThreadId == senderThreadId,
    threadName: nextRegistry[senderThreadId]?.threadName,
    sourceKind: nextRegistry[senderThreadId]?.sourceKind,
    agentNickname: nextRegistry[senderThreadId]?.agentNickname,
    agentRole: nextRegistry[senderThreadId]?.agentRole,
    isClosed: nextRegistry[senderThreadId]?.isClosed ?? false,
    parentThreadId: nextRegistry[senderThreadId]?.parentThreadId,
    spawnItemId: nextRegistry[senderThreadId]?.spawnItemId,
    displayOrder:
        nextRegistry[senderThreadId]?.displayOrder ??
        (state.rootThreadId == senderThreadId
            ? 0
            : _nextDisplayOrderImpl(nextRegistry)),
    childThreadIds: _mergedChildThreadIdsImpl(
      nextRegistry[senderThreadId]?.childThreadIds,
      collaboration.receiverThreadIds,
    ),
  );
  nextRegistry[senderThreadId] = senderEntry;

  for (final receiverThreadId in collaboration.receiverThreadIds) {
    final existingEntry = nextRegistry[receiverThreadId];
    nextRegistry[receiverThreadId] = _upsertRegistryEntryImpl(
      existingEntry,
      threadId: receiverThreadId,
      isPrimary: false,
      threadName: existingEntry?.threadName,
      sourceKind: existingEntry?.sourceKind,
      agentNickname: existingEntry?.agentNickname,
      agentRole: existingEntry?.agentRole,
      isClosed: existingEntry?.isClosed ?? false,
      parentThreadId: senderThreadId,
      spawnItemId: event.itemId,
      displayOrder:
          existingEntry?.displayOrder ?? _nextDisplayOrderImpl(nextRegistry),
      childThreadIds: existingEntry?.childThreadIds,
    );

    final existingTimeline = nextTimelines[receiverThreadId];
    nextTimelines[receiverThreadId] =
        existingTimeline ??
        CodexTimelineState(
          threadId: receiverThreadId,
          connectionStatus: state.connectionStatus,
          lifecycleState: _lifecycleFromCollaborationImpl(
            collaboration,
            receiverThreadId,
          ),
        );
    if (existingTimeline != null) {
      nextTimelines[receiverThreadId] = existingTimeline.copyWith(
        lifecycleState: _lifecycleFromCollaborationImpl(
          collaboration,
          receiverThreadId,
        ),
      );
    }
  }

  final targetTimeline = nextTimelines[targetThreadId];
  if (collaboration.tool == CodexRuntimeCollabAgentTool.wait &&
      collaboration.status ==
          CodexRuntimeCollabAgentToolCallStatus.inProgress &&
      targetTimeline != null) {
    nextTimelines[targetThreadId] = targetTimeline.copyWith(
      lifecycleState: CodexAgentLifecycleState.waitingOnChild,
    );
  }

  return state.copyWith(
    timelinesByThreadId: nextTimelines,
    threadRegistry: nextRegistry,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
  );
}

String? _targetThreadIdForEventImpl(
  CodexSessionState state,
  CodexRuntimeEvent event,
) {
  final eventThreadId = event.threadId;
  if (eventThreadId != null && eventThreadId.isNotEmpty) {
    return eventThreadId;
  }

  if (event.requestId case final requestId? when requestId.isNotEmpty) {
    final ownerThreadId = state.requestOwnerById[requestId];
    if (ownerThreadId != null && ownerThreadId.isNotEmpty) {
      return ownerThreadId;
    }
  }

  return state.rootThreadId ?? state.currentThreadId;
}

Map<String, String> _rebuildRequestOwnerByIdImpl(
  Map<String, CodexTimelineState> timelinesByThreadId,
) {
  final owners = <String, String>{};
  for (final entry in timelinesByThreadId.entries) {
    for (final requestId in entry.value.pendingApprovalRequests.keys) {
      owners[requestId] = entry.key;
    }
    for (final requestId in entry.value.pendingUserInputRequests.keys) {
      owners[requestId] = entry.key;
    }
  }
  return owners;
}
