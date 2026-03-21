part of 'transcript_policy.dart';

CodexSessionState _resetTranscriptStateImpl(
  CodexSessionState state, {
  List<CodexUiBlock>? blocks,
}) {
  return state.copyWithProjectedTranscript(
    clearThreadId: true,
    clearActiveTurn: true,
    blocks: blocks,
    clearPendingLocalUserMessageBlockIds: true,
    clearLocalUserMessageProviderBindings: true,
  );
}

CodexSessionState _rolloverTurnIfNeededImpl(
  TranscriptPolicy policy,
  CodexSessionState state, {
  required String? turnId,
  required String? threadId,
  required DateTime createdAt,
}) {
  if (turnId == null) {
    return state;
  }

  final currentTurn = state.activeTurn;
  if (currentTurn == null || currentTurn.turnId == turnId) {
    return state;
  }

  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    currentTurn,
    createdAt,
  );
  final finalizedState = policy._support.appendBlock(
    _commitActiveTurnImpl(
      policy,
      _clearLocalUserMessageCorrelationStateImpl(
        state.copyWithProjectedTranscript(clearActiveTurn: true),
      ),
      activeTurn: finalizedTurn.$1,
    ),
    _turnBoundaryBlockImpl(
      policy,
      createdAt: createdAt,
      elapsed: finalizedTurn.$2,
      usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
    ),
  );
  return finalizedState.copyWithProjectedTranscript(
    activeTurn: policy._support.startActiveTurn(
      turnId: turnId,
      threadId: threadId ?? state.threadId,
      createdAt: createdAt,
    ),
  );
}

CodexSessionState _applyThreadClosedImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexRuntimeThreadStateChangedEvent event,
) {
  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    state.activeTurn,
    event.createdAt,
  );
  final nextState = _commitActiveTurnImpl(
    policy,
    _clearLocalUserMessageCorrelationStateImpl(
      state.copyWithProjectedTranscript(
        clearThreadId: true,
        clearActiveTurn: true,
      ),
    ),
    activeTurn: finalizedTurn.$1,
  );
  if (finalizedTurn.$1 == null) {
    return nextState;
  }
  return policy._support.appendBlock(
    nextState,
    _turnBoundaryBlockImpl(
      policy,
      createdAt: event.createdAt,
      elapsed: finalizedTurn.$2,
      usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
    ),
  );
}

CodexSessionState _applySessionExitedImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexRuntimeSessionExitedEvent event,
) {
  final completedTimer = policy._support.completeTurnTimer(
    state.activeTurn?.timer,
    event.createdAt,
  );
  final elapsed = state.activeTurn == null
      ? null
      : completedTimer.elapsedAt(event.createdAt);
  final nextState = _commitActiveTurnImpl(
    policy,
    _clearLocalUserMessageCorrelationStateImpl(
      state.copyWithProjectedTranscript(
        connectionStatus: event.exitKind == CodexRuntimeSessionExitKind.error
            ? CodexRuntimeSessionState.error
            : CodexRuntimeSessionState.stopped,
        clearThreadId: true,
        clearActiveTurn: true,
      ),
    ),
    activeTurn: state.activeTurn,
    includePendingUsage: true,
  );
  if (event.exitKind != CodexRuntimeSessionExitKind.error) {
    return nextState;
  }
  return policy._support.appendBlock(
    nextState,
    CodexErrorBlock(
      id: policy._support.eventEntryId('session-exit', event.createdAt),
      createdAt: event.createdAt,
      title: 'Session exited',
      body: elapsed == null
          ? (event.reason ?? 'The Codex session ended.')
          : '${event.reason ?? 'The Codex session ended.'}\n\nElapsed ${formatElapsedDuration(elapsed)}.',
    ),
  );
}

CodexSessionState _applyTurnCompletedImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexRuntimeTurnCompletedEvent event,
) {
  if (_hasMismatchedActiveTurnImpl(state, event.turnId)) {
    return state;
  }

  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    state.activeTurn,
    event.createdAt,
  );
  final nextState = _commitActiveTurnImpl(
    policy,
    _clearLocalUserMessageCorrelationStateImpl(
      state.copyWithProjectedTranscript(
        connectionStatus: CodexRuntimeSessionState.ready,
        clearActiveTurn: true,
      ),
    ),
    activeTurn: finalizedTurn.$1,
  );
  return policy._support.appendBlock(
    nextState,
    _turnBoundaryBlockImpl(
      policy,
      createdAt: event.createdAt,
      elapsed: finalizedTurn.$2,
      usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
    ),
  );
}

CodexSessionState _applyTurnAbortedImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexRuntimeTurnAbortedEvent event,
) {
  if (_hasMismatchedActiveTurnImpl(state, event.turnId)) {
    return state;
  }

  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    state.activeTurn,
    event.createdAt,
  );
  return policy._support.appendBlock(
    _commitActiveTurnImpl(
      policy,
      _clearLocalUserMessageCorrelationStateImpl(
        state.copyWithProjectedTranscript(
          connectionStatus: CodexRuntimeSessionState.ready,
          clearActiveTurn: true,
        ),
      ),
      activeTurn: finalizedTurn.$1,
      includePendingUsage: true,
    ),
    CodexStatusBlock(
      id: policy._support.eventEntryId('status', event.createdAt),
      createdAt: event.createdAt,
      title: 'Turn aborted',
      body: finalizedTurn.$2 == null
          ? (event.reason ?? 'The active turn was aborted.')
          : '${event.reason ?? 'The active turn was aborted.'}\n\nElapsed ${formatElapsedDuration(finalizedTurn.$2!)}.',
      statusKind: CodexStatusBlockKind.info,
      isTranscriptSignal: true,
    ),
  );
}
