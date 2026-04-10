part of 'chat_session_controller.dart';

extension _ChatSessionControllerRecovery on ChatSessionController {
  Future<void> _resumeConversationThread(String threadId) async {
    await _ensureChatSessionAppServerConnected(this);
    final session = await agentAdapterClient.resumeThread(
      threadId: threadId,
      model: _selectedModelOverride(),
      reasoningEffort: _profile.reasoningEffort,
    );
    _clearConversationRecovery();
    _suppressTrackedThreadReuse = false;
    _rememberChatSessionHeaderMetadata(this, session);
    _applyRuntimeEvent(
      TranscriptRuntimeThreadStartedEvent(
        createdAt: DateTime.now(),
        threadId: session.threadId,
        providerThreadId: session.threadId,
        rawMethod: 'thread/resume(response)',
        threadName: session.thread?.name,
        sourceKind: session.thread?.sourceKind,
        agentNickname: session.thread?.agentNickname,
        agentRole: session.thread?.agentRole,
      ),
    );
  }

  Future<void> _reattachConversationWithHistoryBaseline(String threadId) async {
    Object? historyRestoreError;
    StackTrace? historyRestoreStackTrace;
    TranscriptSessionState? restoredState;
    TranscriptSessionHeaderMetadata? resumedHeaderMetadata;

    _startBufferingRuntimeEvents();
    try {
      await _resumeConversationThread(threadId);
      resumedHeaderMetadata = _sessionState.headerMetadata;
      try {
        final thread = await agentAdapterClient.readThreadWithTurns(
          threadId: threadId,
        );
        restoredState = _restoredChatSessionStateFromHistory(this, thread);
      } catch (error, stackTrace) {
        historyRestoreError = error;
        historyRestoreStackTrace = stackTrace;
      }
    } finally {
      final bufferedEvents = _stopBufferingRuntimeEvents();
      if (restoredState != null) {
        _applySessionState(
          restoredState!.copyWith(
            headerMetadata: _mergeHeaderMetadataForHistoryBaseline(
              restoredState!.headerMetadata,
              fallback: resumedHeaderMetadata,
            ),
          ),
        );
      }
      for (final bufferedEvent in bufferedEvents) {
        _applyRuntimeEvent(bufferedEvent);
      }
    }

    if (restoredState != null || _hasVisibleConversationState()) {
      return;
    }

    if (historyRestoreError != null) {
      Error.throwWithStackTrace(
        historyRestoreError!,
        historyRestoreStackTrace!,
      );
    }
  }

  void _setConversationRecovery(ChatConversationRecoveryState nextState) {
    final currentState = _conversationRecoveryState;
    if (currentState?.reason == nextState.reason &&
        currentState?.alternateThreadId == nextState.alternateThreadId &&
        currentState?.expectedThreadId == nextState.expectedThreadId &&
        currentState?.actualThreadId == nextState.actualThreadId) {
      return;
    }

    _conversationRecoveryState = nextState;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  void _clearConversationRecovery() {
    if (_conversationRecoveryState == null) {
      return;
    }

    _conversationRecoveryState = null;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  void _setHistoricalConversationRestoreState(
    ChatHistoricalConversationRestoreState nextState,
  ) {
    final currentState = _historicalConversationRestoreState;
    if (currentState?.phase == nextState.phase &&
        currentState?.threadId == nextState.threadId) {
      return;
    }

    _historicalConversationRestoreState = nextState;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  void _clearHistoricalConversationRestoreState() {
    if (_historicalConversationRestoreState == null) {
      return;
    }

    _historicalConversationRestoreState = null;
    if (!_isDisposed) {
      _notifyListenersIfMounted();
    }
  }

  String? _activeConversationThreadId() {
    if (_profile.ephemeralSession) {
      return null;
    }

    return _normalizedThreadId(_sessionState.rootThreadId);
  }

  String? _selectedConversationThreadId() {
    if (_profile.ephemeralSession) {
      return null;
    }

    return _normalizedThreadId(
      _sessionState.currentThreadId ?? _sessionState.rootThreadId,
    );
  }

  String? _trackedThreadReuseCandidate() {
    if (_profile.ephemeralSession ||
        _suppressTrackedThreadReuse ||
        _sessionState.hasMultipleTimelines) {
      return null;
    }

    return _normalizedThreadId(agentAdapterClient.threadId);
  }

  String? _normalizedThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}

TranscriptSessionHeaderMetadata _mergeHeaderMetadataForHistoryBaseline(
  TranscriptSessionHeaderMetadata restored, {
  TranscriptSessionHeaderMetadata? fallback,
}) {
  if (fallback == null) {
    return restored;
  }

  return restored.copyWith(
    cwd: _nonEmptyMetadataValue(restored.cwd, fallback.cwd),
    model: _nonEmptyMetadataValue(restored.model, fallback.model),
    modelProvider: _nonEmptyMetadataValue(
      restored.modelProvider,
      fallback.modelProvider,
    ),
    reasoningEffort: _nonEmptyMetadataValue(
      restored.reasoningEffort,
      fallback.reasoningEffort,
    ),
  );
}

String? _nonEmptyMetadataValue(String? preferred, String? fallback) {
  final normalizedPreferred = preferred?.trim();
  if (normalizedPreferred != null && normalizedPreferred.isNotEmpty) {
    return normalizedPreferred;
  }

  final normalizedFallback = fallback?.trim();
  if (normalizedFallback != null && normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }

  return null;
}
