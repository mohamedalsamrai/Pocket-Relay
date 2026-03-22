part of 'transcript_reducer.dart';

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
