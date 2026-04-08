part of '../fake_codex_app_server_client.dart';

mixin _FakeCodexAppServerClientTurnOps
    on CodexAppServerClient, _FakeCodexAppServerClientState {
  @override
  Future<CodexAppServerTurn> sendUserMessage({
    required String threadId,
    String? text,
    AgentAdapterTurnInput? input,
    String? model,
    CodexReasoningEffort? effort,
  }) async {
    if (sendUserMessageGate case final gate? when !gate.isCompleted) {
      await gate.future;
    }
    if (sendUserMessageError != null) {
      throw sendUserMessageError!;
    }
    final effectiveInput =
        codexTurnInputFromAgentAdapter(input) ??
        CodexAppServerTurnInput.text(text ?? '');
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
    return CodexAppServerTurn(threadId: threadId, turnId: _activeTurnId!);
  }

  @override
  Future<CodexAppServerTurn> steerActiveTurn({
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
    final effectiveInput =
        codexTurnInputFromAgentAdapter(input) ??
        CodexAppServerTurnInput.text(text ?? '');
    steeredMessages.add(effectiveInput.text);
    steeredTurns.add((
      threadId: threadId,
      turnId: turnId,
      input: effectiveInput,
      text: effectiveInput.text,
    ));
    _threadId = threadId;
    _activeTurnId = turnId;
    return CodexAppServerTurn(threadId: threadId, turnId: turnId);
  }

  @override
  Future<void> resolveApproval({
    required String requestId,
    required bool approved,
  }) async {
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{
        'item/commandExecution/requestApproval',
        'item/fileChange/requestApproval',
        'item/permissions/requestApproval',
        'applyPatchApproval',
        'execCommandApproval',
      },
    );
    approvalDecisions.add((requestId: requestId, approved: approved));
  }

  @override
  Future<void> answerUserInput({
    required String requestId,
    required Map<String, List<String>> answers,
  }) async {
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{
        'item/tool/requestUserInput',
        'tool/requestUserInput',
      },
    );
    userInputResponses.add((requestId: requestId, answers: answers));
  }

  @override
  Future<void> respondToElicitation({
    required String requestId,
    required AgentAdapterElicitationAction action,
    Object? content,
    Object? metadata,
  }) async {
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{'mcpServer/elicitation/request'},
    );
    elicitationResponses.add((
      requestId: requestId,
      action: codexElicitationActionFromAgentAdapter(action),
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
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{'item/tool/call'},
    );
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
    emit(const CodexAppServerDisconnectedEvent(exitCode: 0));
  }

  void _removePendingServerRequest(
    String requestId, {
    Set<String>? allowedMethods,
  }) {
    final method = pendingServerRequestMethodsById[requestId];
    if (method == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }
    if (allowedMethods != null && !allowedMethods.contains(method)) {
      throw CodexAppServerException(
        'Request $requestId is $method, not a compatible pending server request.',
      );
    }
    pendingServerRequestMethodsById.remove(requestId);
  }
}
