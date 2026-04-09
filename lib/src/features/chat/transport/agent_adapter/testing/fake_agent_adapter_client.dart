import 'dart:async';
import 'dart:math' as math;

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

/// Adapter-neutral fake for shared `AgentAdapterClient` tests.
class FakeAgentAdapterClient implements AgentAdapterClient {
  final _eventsController = StreamController<AgentAdapterEvent>.broadcast();

  int connectCalls = 0;
  int startSessionCalls = 0;
  final List<
    ({
      String threadId,
      String? path,
      String? cwd,
      String? model,
      String? modelProvider,
      bool? ephemeral,
      bool persistExtendedHistory,
    })
  >
  forkThreadRequests =
      <
        ({
          String threadId,
          String? path,
          String? cwd,
          String? model,
          String? modelProvider,
          bool? ephemeral,
          bool persistExtendedHistory,
        })
      >[];
  final List<
    ({
      String? cwd,
      String? model,
      AgentAdapterReasoningEffort? reasoningEffort,
      String? resumeThreadId,
    })
  >
  startSessionRequests =
      <
        ({
          String? cwd,
          String? model,
          AgentAdapterReasoningEffort? reasoningEffort,
          String? resumeThreadId,
        })
      >[];
  final List<String> readThreadCalls = <String>[];
  final List<({String threadId, int numTurns})> rollbackThreadCalls =
      <({String threadId, int numTurns})>[];
  final List<({String? cursor, int? limit})> listThreadCalls =
      <({String? cursor, int? limit})>[];
  final List<({String? cursor, int? limit, bool? includeHidden})>
  listModelCalls = <({String? cursor, int? limit, bool? includeHidden})>[];
  final List<String> sentMessages = <String>[];
  final List<
    ({
      String threadId,
      AgentAdapterTurnInput input,
      String text,
      String? model,
      AgentAdapterReasoningEffort? effort,
    })
  >
  sentTurns =
      <
        ({
          String threadId,
          AgentAdapterTurnInput input,
          String text,
          String? model,
          AgentAdapterReasoningEffort? effort,
        })
      >[];
  final List<String> steeredMessages = <String>[];
  final List<
    ({String threadId, String turnId, AgentAdapterTurnInput input, String text})
  >
  steeredTurns =
      <
        ({
          String threadId,
          String turnId,
          AgentAdapterTurnInput input,
          String text,
        })
      >[];
  final List<({String? threadId, String? turnId})> abortTurnCalls =
      <({String? threadId, String? turnId})>[];
  final List<({String requestId, bool approved})> approvalDecisions =
      <({String requestId, bool approved})>[];
  final List<({String requestId, Map<String, List<String>> answers})>
  userInputResponses =
      <({String requestId, Map<String, List<String>> answers})>[];
  final List<
    ({
      String requestId,
      AgentAdapterElicitationAction action,
      Object? content,
      Object? metadata,
    })
  >
  elicitationResponses =
      <
        ({
          String requestId,
          AgentAdapterElicitationAction action,
          Object? content,
          Object? metadata,
        })
      >[];
  final List<({String requestId, String message})> rejectedRequests =
      <({String requestId, String message})>[];
  final List<
    ({String requestId, bool success, List<Map<String, Object?>> contentItems})
  >
  dynamicToolResponses =
      <
        ({
          String requestId,
          bool success,
          List<Map<String, Object?>> contentItems,
        })
      >[];
  final Map<String, String> pendingServerRequestMethodsById =
      <String, String>{};
  final Map<String, List<AgentAdapterEvent>>
  resumeThreadReplayEventsByThreadId = <String, List<AgentAdapterEvent>>{};
  final List<AgentAdapterEvent> connectEventsBeforeThrow =
      <AgentAdapterEvent>[];
  Object? connectError;
  Completer<void>? connectGate;
  Object? startSessionError;
  Object? forkThreadError;
  Object? sendUserMessageError;
  Object? steerActiveTurnError;
  Object? readThreadWithTurnsError;
  Object? rollbackThreadError;
  Object? listModelsError;
  String? startSessionModel;
  String? forkThreadId;
  String? startSessionReasoningEffort;
  String? startSessionCwd;
  String? listModelsNextCursor;
  int? listModelsDefaultPageSize;
  final List<AgentAdapterModelListPage> listedModelPages =
      <AgentAdapterModelListPage>[];
  int disconnectCalls = 0;
  String? connectedThreadId;
  Completer<void>? sendUserMessageGate;
  Completer<void>? steerActiveTurnGate;
  Completer<void>? readThreadWithTurnsGate;
  Completer<void>? rollbackThreadGate;
  final Map<String, Completer<void>> readThreadWithTurnsGatesByThreadId =
      <String, Completer<void>>{};
  final Map<String, AgentAdapterThreadSummary> threadsById =
      <String, AgentAdapterThreadSummary>{};
  final Map<String, AgentAdapterThreadHistory> threadHistoriesById =
      <String, AgentAdapterThreadHistory>{};
  final List<AgentAdapterThreadSummary> listedThreads =
      <AgentAdapterThreadSummary>[];
  final List<AgentAdapterModel> listedModels = <AgentAdapterModel>[];

  bool _isConnected = false;
  bool _isClosed = false;
  String? _threadId;
  String? _activeTurnId;

  @override
  Stream<AgentAdapterEvent> get events => _eventsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  String? get threadId => _threadId;

  @override
  String? get activeTurnId => _activeTurnId;

  void emit(AgentAdapterEvent event) {
    switch (event) {
      case AgentAdapterRequestEvent(:final requestId, :final method):
        pendingServerRequestMethodsById[requestId] = method;
      case AgentAdapterNotificationEvent(:final method, :final params):
        _updateRuntimePointers(method: method, params: params);
      case AgentAdapterDisconnectedEvent():
        pendingServerRequestMethodsById.clear();
      default:
        break;
    }
    if (_isClosed) {
      return;
    }
    _eventsController.add(event);
  }

  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    await _eventsController.close();
  }

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
    emit(const AgentAdapterConnectedEvent(userAgent: 'agent-adapter/test'));
  }

  @override
  Future<AgentAdapterSession> startSession({
    String? cwd,
    String? model,
    AgentAdapterReasoningEffort? reasoningEffort,
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
    final session = AgentAdapterSession(
      threadId: _threadId!,
      cwd: startSessionCwd ?? cwd ?? '/workspace',
      model: startSessionModel ?? model ?? 'test-model',
      modelProvider: 'test-provider',
      reasoningEffort: startSessionReasoningEffort ?? reasoningEffort?.name,
      thread: AgentAdapterThreadSummary(id: _threadId!),
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
  Future<AgentAdapterSession> resumeThread({
    required String threadId,
    String? cwd,
    String? model,
    AgentAdapterReasoningEffort? reasoningEffort,
  }) {
    return startSession(
      cwd: cwd,
      model: model,
      reasoningEffort: reasoningEffort,
      resumeThreadId: threadId,
    );
  }

  @override
  Future<AgentAdapterSession> forkThread({
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
    return AgentAdapterSession(
      threadId: _threadId!,
      cwd: cwd ?? '/workspace',
      model: model ?? 'test-model',
      modelProvider: modelProvider ?? 'test-provider',
      thread: AgentAdapterThreadSummary(id: _threadId!, path: path, cwd: cwd),
      approvalPolicy: 'on-request',
      sandbox: const <String, Object?>{'type': 'workspace-write'},
    );
  }

  @override
  Future<AgentAdapterThreadSummary> readThread({
    required String threadId,
  }) async {
    readThreadCalls.add(threadId);
    return threadsById[threadId] ??
        threadHistoriesById[threadId] ??
        AgentAdapterThreadSummary(id: threadId);
  }

  @override
  Future<AgentAdapterThreadHistory> readThreadWithTurns({
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
      return _threadHistoryFromConfiguredThread(configuredThread!);
    }

    final summary = await readThread(threadId: threadId);
    await _awaitReadThreadWithTurnsGate(threadId);
    if (readThreadWithTurnsError != null) {
      throw readThreadWithTurnsError!;
    }
    return _threadHistoryFromConfiguredThread(summary);
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
  Future<AgentAdapterThreadHistory> rollbackThread({
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
    return threadHistoriesById[threadId] ??
        AgentAdapterThreadHistory(id: threadId);
  }

  @override
  Future<AgentAdapterThreadListPage> listThreads({
    String? cursor,
    int? limit,
  }) async {
    listThreadCalls.add((cursor: cursor, limit: limit));
    return AgentAdapterThreadListPage(
      threads: List<AgentAdapterThreadSummary>.from(listedThreads),
      nextCursor: null,
    );
  }

  @override
  Future<AgentAdapterModelListPage> listModels({
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
      return AgentAdapterModelListPage(
        models: List<AgentAdapterModel>.from(
          listedModels.sublist(boundedStartIndex, endIndex),
        ),
        nextCursor: endIndex < listedModels.length ? '$endIndex' : null,
      );
    }
    return AgentAdapterModelListPage(
      models: List<AgentAdapterModel>.from(listedModels),
      nextCursor: listModelsNextCursor,
    );
  }

  @override
  Future<AgentAdapterTurn> sendUserMessage({
    required String threadId,
    String? text,
    AgentAdapterTurnInput? input,
    String? model,
    AgentAdapterReasoningEffort? effort,
  }) async {
    if (sendUserMessageGate case final gate? when !gate.isCompleted) {
      await gate.future;
    }
    if (sendUserMessageError != null) {
      throw sendUserMessageError!;
    }
    final effectiveInput = input ?? AgentAdapterTurnInput.text(text ?? '');
    sentMessages.add(effectiveInput.text);
    sentTurns.add((
      threadId: threadId,
      input: effectiveInput,
      text: effectiveInput.text,
      model: model,
      effort: effort,
    ));
    _threadId = threadId;
    _activeTurnId = 'turn_${sentMessages.length}';
    return AgentAdapterTurn(threadId: threadId, turnId: _activeTurnId!);
  }

  @override
  Future<AgentAdapterTurn> steerActiveTurn({
    required String threadId,
    required String turnId,
    String? text,
    AgentAdapterTurnInput? input,
  }) async {
    if (steerActiveTurnGate case final gate? when !gate.isCompleted) {
      await gate.future;
    }
    if (steerActiveTurnError != null) {
      throw steerActiveTurnError!;
    }
    final effectiveInput = input ?? AgentAdapterTurnInput.text(text ?? '');
    steeredMessages.add(effectiveInput.text);
    steeredTurns.add((
      threadId: threadId,
      turnId: turnId,
      input: effectiveInput,
      text: effectiveInput.text,
    ));
    _threadId = threadId;
    _activeTurnId = turnId;
    return AgentAdapterTurn(threadId: threadId, turnId: turnId);
  }

  @override
  Future<void> resolveApproval({
    required String requestId,
    required bool approved,
  }) async {
    _removePendingServerRequest(requestId);
    approvalDecisions.add((requestId: requestId, approved: approved));
  }

  @override
  Future<void> answerUserInput({
    required String requestId,
    required Map<String, List<String>> answers,
  }) async {
    _removePendingServerRequest(requestId);
    userInputResponses.add((requestId: requestId, answers: answers));
  }

  @override
  Future<void> respondToElicitation({
    required String requestId,
    required AgentAdapterElicitationAction action,
    Object? content,
    Object? metadata,
  }) async {
    _removePendingServerRequest(requestId);
    elicitationResponses.add((
      requestId: requestId,
      action: action,
      content: content,
      metadata: metadata,
    ));
  }

  @override
  Future<void> respondDynamicToolCall({
    required String requestId,
    required bool success,
    List<Map<String, Object?>> contentItems = const <Map<String, Object?>>[],
  }) async {
    _removePendingServerRequest(requestId);
    dynamicToolResponses.add((
      requestId: requestId,
      success: success,
      contentItems: contentItems,
    ));
  }

  @override
  Future<void> rejectServerRequest({
    required String requestId,
    required String message,
    int code = -32000,
    Object? data,
  }) async {
    _removePendingServerRequest(requestId);
    rejectedRequests.add((requestId: requestId, message: message));
  }

  @override
  Future<void> abortTurn({String? threadId, String? turnId}) async {
    abortTurnCalls.add((threadId: threadId, turnId: turnId));
    _activeTurnId = null;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    if (!_isConnected) {
      return;
    }
    _isConnected = false;
    _threadId = null;
    _activeTurnId = null;
    pendingServerRequestMethodsById.clear();
    emit(const AgentAdapterDisconnectedEvent(exitCode: 0));
  }

  @override
  Future<void> dispose() => close();

  void _removePendingServerRequest(String requestId) {
    final method = pendingServerRequestMethodsById.remove(requestId);
    if (method == null) {
      throw StateError('Unknown pending server request: $requestId');
    }
  }

  AgentAdapterThreadHistory _threadHistoryFromConfiguredThread(
    AgentAdapterThreadSummary thread,
  ) {
    if (thread is AgentAdapterThreadHistory) {
      return thread;
    }
    return AgentAdapterThreadHistory(
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

  void _updateRuntimePointers({
    required String method,
    required Object? params,
  }) {
    final payload = _asObject(params);
    switch (method) {
      case 'session/exited':
      case 'session/closed':
        _threadId = null;
        _activeTurnId = null;
      case 'thread/started':
        final thread = _asObject(payload?['thread']);
        _threadId = _asString(thread?['id']) ?? _asString(payload?['threadId']);
        _activeTurnId = null;
      case 'thread/closed':
        final threadId = _asString(payload?['threadId']);
        if (threadId == null || threadId == _threadId) {
          _threadId = null;
          _activeTurnId = null;
        }
      case 'turn/started':
        _threadId = _asString(payload?['threadId']) ?? _threadId;
        final turn = _asObject(payload?['turn']);
        _activeTurnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
      case 'turn/completed':
      case 'turn/aborted':
        final turn = _asObject(payload?['turn']);
        final turnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
        if (turnId == null || turnId == _activeTurnId) {
          _activeTurnId = null;
        }
    }
  }

  Map<String, Object?>? _asObject(Object? value) {
    if (value is Map<Object?, Object?>) {
      return value.map(
        (key, value) => MapEntry<String, Object?>(key.toString(), value),
      );
    }
    return null;
  }

  String? _asString(Object? value) => value is String ? value : null;
}
