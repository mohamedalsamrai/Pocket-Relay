part of 'transcript_item_policy.dart';

int? _extractExitCode(Map<String, dynamic>? snapshot) {
  final value = snapshot?['exitCode'] ?? snapshot?['exit_code'];
  return value is num ? value.toInt() : null;
}

bool _shouldForkVisibleArtifact(
  CodexActiveTurnState? activeTurn,
  CodexSessionActiveItem? existing, {
  CodexCanonicalItemType? itemType,
}) {
  final effectiveItemType = itemType ?? existing?.itemType;
  if (effectiveItemType == CodexCanonicalItemType.commandExecution) {
    return false;
  }

  if (activeTurn == null || existing == null || activeTurn.artifacts.isEmpty) {
    return false;
  }

  final currentArtifactId = activeTurn.itemArtifactIds[existing.itemId];
  if (currentArtifactId == null) {
    return false;
  }

  return activeTurn.artifacts.last.id != currentArtifactId;
}

String _nextItemEntryId(
  TranscriptItemPolicy policy,
  CodexSessionState state,
  CodexActiveTurnState? activeTurn, {
  required String itemId,
}) {
  final usedIds = <String>{
    ...codexUiBlockIds(state.blocks),
    if (activeTurn != null) ...codexTurnArtifactIds(activeTurn.artifacts),
  };
  final baseId = 'item_$itemId';
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

String _visibleBodyForArtifact(
  String aggregatedBody, {
  required String artifactBaseBody,
  bool fallbackToFullBody = false,
}) {
  if (artifactBaseBody.isEmpty) {
    return aggregatedBody;
  }

  final visibleBody = aggregatedBody.startsWith(artifactBaseBody)
      ? aggregatedBody.substring(artifactBaseBody.length)
      : aggregatedBody;
  if (visibleBody.isEmpty && fallbackToFullBody) {
    return aggregatedBody;
  }
  return visibleBody;
}

CodexSessionState? _suppressedLocalUserMessageState(
  CodexSessionState state,
  CodexActiveTurnState? activeTurn,
  CodexSessionActiveItem item,
) {
  if (item.itemType != CodexCanonicalItemType.userMessage) {
    return null;
  }

  if (state.localUserMessageProviderBindings.containsKey(item.itemId)) {
    return _stateAfterSuppressedLocalUserMessage(
      state,
      activeTurn: state.activeTurn,
      itemId: item.itemId,
    );
  }

  if (state.pendingLocalUserMessageBlockIds.isEmpty) {
    return null;
  }

  final text = item.body.trim();
  if (text.isEmpty) {
    return null;
  }

  final pendingMatch = _matchingPendingLocalUserMessage(
    state.blocks,
    state.pendingLocalUserMessageBlockIds,
    text: text,
  );
  if (pendingMatch == null) {
    return null;
  }

  return _stateAfterSuppressedLocalUserMessage(
    state,
    activeTurn: activeTurn,
    itemId: item.itemId,
    pendingLocalUserMessageBlockIds: pendingMatch.$2,
    localUserMessageProviderBindings: <String, String>{
      ...state.localUserMessageProviderBindings,
      item.itemId: pendingMatch.$1.id,
    },
  );
}

CodexSessionState _stateAfterSuppressedLocalUserMessage(
  CodexSessionState state, {
  required CodexActiveTurnState? activeTurn,
  required String itemId,
  List<String>? pendingLocalUserMessageBlockIds,
  Map<String, String>? localUserMessageProviderBindings,
}) {
  return state.copyWithProjectedTranscript(
    activeTurn: _activeTurnAfterSuppressedLocalUserMessage(
      activeTurn,
      itemId: itemId,
    ),
    pendingLocalUserMessageBlockIds:
        pendingLocalUserMessageBlockIds ?? state.pendingLocalUserMessageBlockIds,
    localUserMessageProviderBindings:
        localUserMessageProviderBindings ??
        state.localUserMessageProviderBindings,
  );
}

CodexUserMessageBlock? _userMessageBlockById(
  List<CodexUiBlock> blocks,
  String blockId,
) {
  for (final block in blocks.reversed) {
    if (block is CodexUserMessageBlock && block.id == blockId) {
      return block;
    }
  }
  return null;
}

(CodexUserMessageBlock, List<String>)? _matchingPendingLocalUserMessage(
  List<CodexUiBlock> blocks,
  List<String> pendingBlockIds, {
  required String text,
}) {
  final nextPendingBlockIds = <String>[];

  for (var index = 0; index < pendingBlockIds.length; index += 1) {
    final blockId = pendingBlockIds[index];
    final block = _userMessageBlockById(blocks, blockId);
    if (block == null) {
      continue;
    }
    if (block.text.trim() == text) {
      nextPendingBlockIds.addAll(pendingBlockIds.skip(index + 1));
      return (block, nextPendingBlockIds);
    }
    nextPendingBlockIds.add(blockId);
  }

  return null;
}

CodexActiveTurnState? _activeTurnAfterSuppressedLocalUserMessage(
  CodexActiveTurnState? activeTurn, {
  required String itemId,
}) {
  if (activeTurn == null) {
    return null;
  }

  final hasItem = activeTurn.itemsById.containsKey(itemId);
  final hasArtifactBinding = activeTurn.itemArtifactIds.containsKey(itemId);
  if (!hasItem && !hasArtifactBinding) {
    return activeTurn;
  }

  final nextItems = <String, CodexSessionActiveItem>{...activeTurn.itemsById}
    ..remove(itemId);
  final nextArtifactIds = <String, String>{...activeTurn.itemArtifactIds}
    ..remove(itemId);

  return activeTurn.copyWith(
    itemsById: nextItems,
    itemArtifactIds: nextArtifactIds,
  );
}
