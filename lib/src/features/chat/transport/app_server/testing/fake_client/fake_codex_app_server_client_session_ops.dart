part of '../fake_codex_app_server_client.dart';

mixin _FakeCodexAppServerClientSessionOps
    on CodexAppServerClient, _FakeCodexAppServerClientState {
  @override
  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    if (connectError != null) {
      for (final event in connectEventsBeforeThrow) {
        emit(event);
      }
      throw connectError!;
    }
    final gate = connectGate;
    if (gate != null) {
      await gate.future;
    }
    connectCalls += 1;
    _isConnected = true;
    _threadId = connectedThreadId;
    emit(const CodexAppServerConnectedEvent(userAgent: 'codex-cli/test'));
  }

  @override
  Future<CodexAppServerSession> startSession({
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
    String? resumeThreadId,
  }) async {
    if (startSessionError != null) {
      throw startSessionError!;
    }
    startSessionCalls += 1;
    startSessionRequests.add((
      cwd: cwd,
      model: model,
      reasoningEffort: reasoningEffort,
      resumeThreadId: resumeThreadId,
    ));
    _threadId = resumeThreadId ?? 'thread_123';
    final session = CodexAppServerSession(
      threadId: _threadId!,
      cwd: startSessionCwd ?? cwd ?? '/workspace',
      model: startSessionModel ?? model ?? 'gpt-5.3-codex',
      modelProvider: 'openai',
      reasoningEffort: startSessionReasoningEffort,
      thread: CodexAppServerThreadSummary(
        id: _threadId!,
        sourceKind: 'app-server',
      ),
    );
    if (resumeThreadId != null && resumeThreadId.trim().isNotEmpty) {
      final replayEvents = resumeThreadReplayEventsByThreadId[resumeThreadId];
      if (replayEvents != null) {
        for (final event in replayEvents) {
          emit(event);
        }
      }
    }
    return session;
  }

  @override
  Future<CodexAppServerSession> resumeThread({
    required String threadId,
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
  }) {
    return startSession(
      cwd: cwd,
      model: model,
      reasoningEffort: reasoningEffort,
      resumeThreadId: threadId,
    );
  }

  @override
  Future<CodexAppServerSession> forkThread({
    required String threadId,
    String? path,
    String? cwd,
    String? model,
    String? modelProvider,
    bool? ephemeral,
    bool persistExtendedHistory = false,
  }) async {
    if (forkThreadError != null) {
      throw forkThreadError!;
    }
    forkThreadRequests.add((
      threadId: threadId,
      path: path,
      cwd: cwd,
      model: model,
      modelProvider: modelProvider,
      ephemeral: ephemeral,
      persistExtendedHistory: persistExtendedHistory,
    ));
    _threadId = forkThreadId ?? '${threadId}_fork';
    return CodexAppServerSession(
      threadId: _threadId!,
      cwd: cwd ?? '/workspace',
      model: model ?? 'gpt-5.3-codex',
      modelProvider: modelProvider ?? 'openai',
      thread: CodexAppServerThreadSummary(
        id: _threadId!,
        path: path,
        cwd: cwd,
        sourceKind: 'app-server',
      ),
      approvalPolicy: 'on-request',
      sandbox: const <String, Object?>{'type': 'workspace-write'},
    );
  }

  @override
  Future<CodexAppServerThreadSummary> readThread({
    required String threadId,
  }) async {
    readThreadCalls.add(threadId);
    final configuredThread = threadsById[threadId];
    if (configuredThread != null) {
      return _codexThreadSummaryFromConfiguredThread(configuredThread);
    }
    final configuredHistory = threadHistoriesById[threadId];
    if (configuredHistory != null) {
      return _codexThreadSummaryFromConfiguredThread(configuredHistory);
    }
    return CodexAppServerThreadSummary(id: threadId, sourceKind: 'app-server');
  }

  @override
  Future<CodexAppServerThreadHistory> readThreadWithTurns({
    required String threadId,
  }) async {
    final configuredHistory = threadHistoriesById[threadId];
    final configuredThread = threadsById[threadId];
    if (configuredHistory != null || configuredThread != null) {
      readThreadCalls.add(threadId);
      await _awaitReadThreadWithTurnsGate(threadId);
      if (readThreadWithTurnsError != null) {
        throw readThreadWithTurnsError!;
      }
      if (configuredHistory != null) {
        return configuredHistory;
      }
      return _codexThreadHistoryFromConfiguredThread(configuredThread!);
    }

    final summary = await readThread(threadId: threadId);
    await _awaitReadThreadWithTurnsGate(threadId);
    if (readThreadWithTurnsError != null) {
      throw readThreadWithTurnsError!;
    }
    return CodexAppServerThreadHistory(
      id: summary.id,
      preview: summary.preview,
      ephemeral: summary.ephemeral,
      modelProvider: summary.modelProvider,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      path: summary.path,
      cwd: summary.cwd,
      promptCount: summary.promptCount,
      name: summary.name,
      sourceKind: summary.sourceKind,
      agentNickname: summary.agentNickname,
      agentRole: summary.agentRole,
    );
  }

  Future<void> _awaitReadThreadWithTurnsGate(String threadId) async {
    final threadGate = readThreadWithTurnsGatesByThreadId[threadId];
    if (threadGate != null) {
      await threadGate.future;
      return;
    }
    if (readThreadWithTurnsGate case final gate?) {
      await gate.future;
    }
  }

  @override
  Future<CodexAppServerThreadHistory> rollbackThread({
    required String threadId,
    required int numTurns,
  }) async {
    rollbackThreadCalls.add((threadId: threadId, numTurns: numTurns));
    if (rollbackThreadGate case final gate?) {
      await gate.future;
    }
    if (rollbackThreadError != null) {
      throw rollbackThreadError!;
    }

    final configuredHistory = threadHistoriesById[threadId];
    if (configuredHistory != null) {
      return configuredHistory;
    }

    return CodexAppServerThreadHistory(id: threadId, sourceKind: 'app-server');
  }

  @override
  Future<CodexAppServerThreadListPage> listThreads({
    String? cursor,
    int? limit,
  }) async {
    listThreadCalls.add((cursor: cursor, limit: limit));
    return CodexAppServerThreadListPage(
      threads: List<CodexAppServerThreadSummary>.from(listedThreads),
      nextCursor: null,
    );
  }

  @override
  Future<CodexAppServerModelListPage> listModels({
    String? cursor,
    int? limit,
    bool? includeHidden,
  }) async {
    if (listModelsError != null) {
      throw listModelsError!;
    }
    listModelCalls.add((
      cursor: cursor,
      limit: limit,
      includeHidden: includeHidden,
    ));
    if (listedModelPages.isNotEmpty) {
      return listedModelPages.removeAt(0);
    }
    final defaultPageSize = listModelsDefaultPageSize;
    if (defaultPageSize != null) {
      final effectivePageSize = limit != null && limit > 0
          ? limit
          : defaultPageSize;
      final startIndex = int.tryParse(cursor ?? '') ?? 0;
      final boundedStartIndex = math.min(
        math.max(startIndex, 0),
        listedModels.length,
      );
      final endIndex = math.min(
        boundedStartIndex + effectivePageSize,
        listedModels.length,
      );
      return CodexAppServerModelListPage(
        models: List<CodexAppServerModel>.from(
          listedModels.sublist(boundedStartIndex, endIndex),
        ),
        nextCursor: endIndex < listedModels.length ? '$endIndex' : null,
      );
    }
    return CodexAppServerModelListPage(
      models: List<CodexAppServerModel>.from(listedModels),
      nextCursor: listModelsNextCursor,
    );
  }

  CodexAppServerThreadSummary _codexThreadSummaryFromConfiguredThread(
    AgentAdapterThreadSummary thread,
  ) {
    if (thread case final CodexAppServerThreadSummary summary) {
      return summary;
    }

    return CodexAppServerThreadSummary(
      id: thread.id,
      preview: thread.preview,
      ephemeral: thread.ephemeral,
      modelProvider: thread.modelProvider,
      createdAt: thread.createdAt,
      updatedAt: thread.updatedAt,
      path: thread.path,
      cwd: thread.cwd,
      promptCount: thread.promptCount,
      name: thread.name,
      sourceKind: thread.sourceKind,
      agentNickname: thread.agentNickname,
      agentRole: thread.agentRole,
    );
  }

  CodexAppServerThreadHistory _codexThreadHistoryFromConfiguredThread(
    AgentAdapterThreadSummary thread,
  ) {
    if (thread case final CodexAppServerThreadHistory history) {
      return history;
    }

    return CodexAppServerThreadHistory(
      id: thread.id,
      preview: thread.preview,
      ephemeral: thread.ephemeral,
      modelProvider: thread.modelProvider,
      createdAt: thread.createdAt,
      updatedAt: thread.updatedAt,
      path: thread.path,
      cwd: thread.cwd,
      promptCount: thread.promptCount,
      name: thread.name,
      sourceKind: thread.sourceKind,
      agentNickname: thread.agentNickname,
      agentRole: thread.agentRole,
      turns: thread is AgentAdapterThreadHistory
          ? thread.turns
                .map<CodexAppServerHistoryTurn>(
                  (turn) => switch (turn) {
                    CodexAppServerHistoryTurn() => turn,
                    _ => CodexAppServerHistoryTurn(
                      id: turn.id,
                      threadId: turn.threadId,
                      status: turn.status,
                      model: turn.model,
                      effort: turn.effort,
                      stopReason: turn.stopReason,
                      usage: turn.usage,
                      modelUsage: turn.modelUsage,
                      totalCostUsd: turn.totalCostUsd,
                      error: turn.error,
                      items: turn.items
                          .map<CodexAppServerHistoryItem>(
                            (item) => switch (item) {
                              CodexAppServerHistoryItem() => item,
                              _ => CodexAppServerHistoryItem(
                                id: item.id,
                                type: item.type,
                                status: item.status,
                                raw: item.raw,
                              ),
                            },
                          )
                          .toList(growable: false),
                      raw: turn.raw,
                    ),
                  },
                )
                .toList(growable: false)
          : const <CodexAppServerHistoryTurn>[],
    );
  }
}
