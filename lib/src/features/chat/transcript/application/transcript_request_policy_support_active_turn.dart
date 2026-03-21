part of 'transcript_request_policy.dart';

CodexActiveTurnState? _activeTurnForPendingApproval(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionPendingRequest pendingRequest,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
    return activeTurn;
  }

  return activeTurn.copyWith(
    timer: turnTimer,
    status: CodexActiveTurnStatus.blocked,
    pendingApprovalRequests: <String, CodexSessionPendingRequest>{
      ...activeTurn.pendingApprovalRequests,
      requestId: pendingRequest,
    },
  );
}

CodexActiveTurnState? _activeTurnForPendingInput(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionPendingUserInputRequest pendingRequest,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
    return activeTurn;
  }

  return activeTurn.copyWith(
    timer: turnTimer,
    status: CodexActiveTurnStatus.blocked,
    pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
      ...activeTurn.pendingUserInputRequests,
      requestId: pendingRequest,
    },
  );
}

CodexActiveTurnState? _activeTurnAfterRequestResolved(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null) {
    return null;
  }

  final nextApprovals = <String, CodexSessionPendingRequest>{
    ...activeTurn.pendingApprovalRequests,
  }..remove(requestId);
  final nextInputs = <String, CodexSessionPendingUserInputRequest>{
    ...activeTurn.pendingUserInputRequests,
  }..remove(requestId);

  return activeTurn.copyWith(
    timer: turnTimer,
    status: nextApprovals.isNotEmpty || nextInputs.isNotEmpty
        ? CodexActiveTurnStatus.blocked
        : CodexActiveTurnStatus.running,
    pendingApprovalRequests: nextApprovals,
    pendingUserInputRequests: nextInputs,
  );
}

CodexActiveTurnState? _activeTurnAfterUserInputResolved(
  CodexActiveTurnState? activeTurn, {
  required String requestId,
  required CodexSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null) {
    return null;
  }

  final nextInputs = <String, CodexSessionPendingUserInputRequest>{
    ...activeTurn.pendingUserInputRequests,
  }..remove(requestId);

  return activeTurn.copyWith(
    timer: turnTimer,
    status:
        activeTurn.pendingApprovalRequests.isNotEmpty || nextInputs.isNotEmpty
        ? CodexActiveTurnStatus.blocked
        : CodexActiveTurnStatus.running,
    pendingUserInputRequests: nextInputs,
  );
}

CodexActiveTurnState? _ensureActiveTurn(
  CodexActiveTurnState? activeTurn, {
  required String? turnId,
  required String? threadId,
  required DateTime createdAt,
}) {
  if (activeTurn != null || turnId == null) {
    return activeTurn;
  }

  return CodexActiveTurnState(
    turnId: turnId,
    threadId: threadId,
    timer: CodexSessionTurnTimer(
      turnId: turnId,
      startedAt: createdAt,
      activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
    ),
  );
}

CodexActiveTurnState _appendTurnBlock(
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

CodexActiveTurnState? _freezeTailArtifact(CodexActiveTurnState? activeTurn) {
  if (activeTurn == null || activeTurn.artifacts.isEmpty) {
    return activeTurn;
  }

  final frozenTail = freezeCodexTurnArtifact(activeTurn.artifacts.last);
  if (identical(frozenTail, activeTurn.artifacts.last)) {
    return activeTurn;
  }

  final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[nextArtifacts.length - 1] = frozenTail;
  return activeTurn.copyWith(artifacts: nextArtifacts);
}

CodexActiveTurnState? _freezeArtifactsForRequest(
  CodexActiveTurnState? activeTurn, {
  required String? itemId,
}) {
  return _freezeCommandArtifact(
    _freezeTailArtifact(activeTurn),
    itemId: itemId,
  );
}

CodexActiveTurnState? _freezeCommandArtifact(
  CodexActiveTurnState? activeTurn, {
  required String? itemId,
}) {
  if (activeTurn == null || itemId == null) {
    return activeTurn;
  }

  final item = activeTurn.itemsById[itemId];
  if (item?.itemType != CodexCanonicalItemType.commandExecution) {
    return activeTurn;
  }

  final artifactId = activeTurn.itemArtifactIds[itemId];
  if (artifactId == null) {
    return activeTurn;
  }

  final index = activeTurn.artifacts.indexWhere(
    (artifact) => artifact.id == artifactId,
  );
  if (index == -1) {
    return activeTurn;
  }

  final artifact = activeTurn.artifacts[index];
  final frozenArtifact = freezeCodexTurnArtifact(artifact);
  if (identical(frozenArtifact, artifact)) {
    return activeTurn;
  }

  final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[index] = frozenArtifact;
  return activeTurn.copyWith(artifacts: nextArtifacts);
}

CodexActiveTurnState _replaceTailTurnBlock(
  CodexActiveTurnState activeTurn,
  CodexUiBlock block,
) {
  final nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[nextArtifacts.length - 1] = CodexTurnBlockArtifact(
    block: block,
  );
  return activeTurn.copyWith(artifacts: nextArtifacts);
}
