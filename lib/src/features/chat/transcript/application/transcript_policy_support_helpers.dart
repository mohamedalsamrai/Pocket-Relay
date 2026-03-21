part of 'transcript_policy.dart';

CodexSessionState _commitActiveTurnImpl(
  TranscriptPolicy policy,
  CodexSessionState state, {
  required CodexActiveTurnState? activeTurn,
  bool includePendingUsage = false,
}) {
  if (activeTurn == null) {
    return state;
  }

  var nextState = state;
  for (final block in projectCodexTurnArtifacts(activeTurn.artifacts)) {
    nextState = policy._support.appendBlock(nextState, block);
  }
  if (includePendingUsage && activeTurn.pendingThreadTokenUsageBlock != null) {
    nextState = policy._support.appendBlock(
      nextState,
      activeTurn.pendingThreadTokenUsageBlock!,
    );
  }
  return nextState;
}

bool _hasMismatchedActiveTurnImpl(CodexSessionState state, String? turnId) {
  final activeTurn = state.activeTurn;
  return activeTurn != null && turnId != null && activeTurn.turnId != turnId;
}

(CodexActiveTurnState?, Duration?) _finalizeCommittedTurnImpl(
  TranscriptPolicy policy,
  CodexActiveTurnState? activeTurn,
  DateTime createdAt,
) {
  if (activeTurn == null) {
    return (null, null);
  }

  final completedTimer = policy._support.completeTurnTimer(
    activeTurn.timer,
    createdAt,
  );
  return (
    activeTurn.copyWith(
      timer: completedTimer,
      status: CodexActiveTurnStatus.completing,
    ),
    completedTimer.elapsedAt(createdAt),
  );
}

CodexTurnBoundaryBlock _turnBoundaryBlockImpl(
  TranscriptPolicy policy, {
  required DateTime createdAt,
  required Duration? elapsed,
  CodexUsageBlock? usage,
}) {
  return CodexTurnBoundaryBlock(
    id: policy._support.eventEntryId('turn-end', createdAt),
    createdAt: createdAt,
    elapsed: elapsed,
    usage: usage,
  );
}

CodexSessionState _stateWithTranscriptBlockImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexUiBlock block, {
  required String? turnId,
  required String? threadId,
}) {
  final activeTurn = policy._support.ensureActiveTurn(
    state.activeTurn,
    turnId: turnId,
    threadId: threadId,
    createdAt: block.createdAt,
  );
  if (activeTurn == null) {
    return _upsertTopLevelTranscriptBlockImpl(policy, state, block);
  }

  return state.copyWithProjectedTranscript(
    activeTurn: _upsertTurnBlockImpl(activeTurn, block),
  );
}

CodexSessionState _stateWithAppendedTranscriptBlockImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexUiBlock block, {
  required String? turnId,
  required String? threadId,
}) {
  final activeTurn = policy._support.ensureActiveTurn(
    state.activeTurn,
    turnId: turnId,
    threadId: threadId,
    createdAt: block.createdAt,
  );
  if (activeTurn == null) {
    return policy._support.appendBlock(state, block);
  }

  return state.copyWithProjectedTranscript(
    activeTurn: _appendTurnBlockImpl(activeTurn, block),
  );
}

CodexActiveTurnState _upsertTurnBlockImpl(
  CodexActiveTurnState activeTurn,
  CodexUiBlock block,
) {
  final artifact = CodexTurnBlockArtifact(block: block);
  var nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
  final index = nextArtifacts.indexWhere((existing) => existing.id == block.id);
  if (index == -1) {
    nextArtifacts = appendCodexTurnArtifact(nextArtifacts, artifact);
  } else {
    nextArtifacts[index] = artifact;
  }

  return activeTurn.copyWith(artifacts: nextArtifacts);
}

CodexActiveTurnState _appendTurnBlockImpl(
  CodexActiveTurnState activeTurn,
  CodexUiBlock block,
) {
  return activeTurn.copyWith(
    artifacts: appendCodexTurnArtifact(
      activeTurn.artifacts,
      CodexTurnBlockArtifact(block: block),
    ),
  );
}

CodexSessionState _upsertTopLevelTranscriptBlockImpl(
  TranscriptPolicy policy,
  CodexSessionState state,
  CodexUiBlock block,
) {
  final existingIndex = state.blocks.indexWhere(
    (existing) => existing.id == block.id,
  );
  if (existingIndex == -1) {
    return policy._support.appendBlock(state, block);
  }

  final nextBlocks = List<CodexUiBlock>.from(state.blocks);
  nextBlocks[existingIndex] = block;
  return state.copyWithProjectedTranscript(blocks: nextBlocks);
}

String _nextTranscriptEventBlockIdImpl(
  TranscriptPolicy policy,
  CodexSessionState state, {
  required String prefix,
  required DateTime createdAt,
}) {
  final usedIds = <String>{
    ...codexUiBlockIds(state.blocks),
    if (state.activeTurn != null)
      ...codexTurnArtifactIds(state.activeTurn!.artifacts),
  };
  final baseId = policy._support.eventEntryId(prefix, createdAt);
  if (!usedIds.contains(baseId)) {
    return baseId;
  }

  var ordinal = 2;
  var candidate = '$baseId-$ordinal';
  while (usedIds.contains(candidate)) {
    ordinal += 1;
    candidate = '$baseId-$ordinal';
  }
  return candidate;
}

CodexSessionState _clearLocalUserMessageCorrelationStateImpl(
  CodexSessionState state,
) {
  return state.copyWithProjectedTranscript(
    clearPendingLocalUserMessageBlockIds: true,
    clearLocalUserMessageProviderBindings: true,
  );
}
