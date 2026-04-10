import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_errors.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_guardrail_errors.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

abstract interface class ChatSessionRequestCoordinator {
  Future<void> approveRequest(String requestId);
  Future<void> denyRequest(String requestId);
  Future<void> submitUserInput(
    String requestId,
    Map<String, List<String>> answers,
  );
  Future<void> handleUnsupportedHostRequest(AgentAdapterRequestEvent event);
}

abstract interface class ChatSessionRequestCoordinatorContext {
  AgentAdapterClient get agentAdapterClient;
  TranscriptSessionPendingRequest? findPendingApprovalRequest(String requestId);
  TranscriptSessionPendingUserInputRequest? findPendingUserInputRequest(
    String requestId,
  );
  void emitUserFacingError(PocketUserFacingError error);
  void reportAppServerFailure({
    required PocketUserFacingError userFacingError,
    String? runtimeErrorMessage,
    bool suppressRuntimeError,
    bool suppressSnackBar,
  });
  void applyRuntimeEvent(TranscriptRuntimeEvent event);
}

class DefaultChatSessionRequestCoordinator
    implements ChatSessionRequestCoordinator {
  const DefaultChatSessionRequestCoordinator({required this.context});

  final ChatSessionRequestCoordinatorContext context;

  @override
  Future<void> approveRequest(String requestId) {
    return _resolveApproval(requestId, approved: true);
  }

  @override
  Future<void> denyRequest(String requestId) {
    return _resolveApproval(requestId, approved: false);
  }

  @override
  Future<void> submitUserInput(
    String requestId,
    Map<String, List<String>> answers,
  ) async {
    final pendingRequest = context.findPendingUserInputRequest(requestId);
    if (pendingRequest == null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.userInputRequestUnavailable(),
      );
      return;
    }

    try {
      if (pendingRequest.requestType ==
          TranscriptCanonicalRequestType.mcpServerElicitation) {
        await context.agentAdapterClient.respondToElicitation(
          requestId: requestId,
          action: AgentAdapterElicitationAction.accept,
          content: _elicitationContentFromAnswers(answers),
        );
      } else {
        await context.agentAdapterClient.answerUserInput(
          requestId: requestId,
          answers: answers,
        );
      }
    } catch (error) {
      final userFacingError = ChatSessionErrors.submitUserInputFailed();
      context.reportAppServerFailure(
        userFacingError: userFacingError,
        runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
          userFacingError,
          error: error,
        ),
        suppressRuntimeError: false,
        suppressSnackBar: false,
      );
    }
  }

  @override
  Future<void> handleUnsupportedHostRequest(
    AgentAdapterRequestEvent event,
  ) async {
    final payload = _asObject(event.params);
    final threadId = _asString(payload?['threadId']);
    final turnId = _asString(payload?['turnId']);
    final itemId = _asString(payload?['itemId']);
    final toolName = _asString(payload?['tool']) ?? 'dynamic tool';

    final (title, message) = switch (event.method) {
      'account/chatgptAuthTokens/refresh' => (
        'Auth refresh unsupported',
        'Pocket Relay does not manage external ChatGPT tokens, so this app-server auth refresh request was rejected.',
      ),
      'item/tool/call' => (
        'Dynamic tool unsupported',
        'Pocket Relay does not implement the experimental host-side tool "$toolName", so the request was rejected.',
      ),
      _ => (
        'Request unsupported',
        'Pocket Relay rejected an unsupported app-server request.',
      ),
    };

    context.applyRuntimeEvent(
      TranscriptRuntimeStatusEvent(
        createdAt: DateTime.now(),
        threadId: threadId,
        turnId: turnId,
        itemId: itemId,
        requestId: event.requestId,
        rawMethod: event.method,
        rawPayload: event.params,
        title: title,
        message: message,
      ),
    );

    try {
      if (event.method == 'item/tool/call') {
        await context.agentAdapterClient.respondDynamicToolCall(
          requestId: event.requestId,
          success: false,
          contentItems: <Map<String, Object?>>[
            <String, Object?>{'type': 'inputText', 'text': message},
          ],
        );
        return;
      }

      await context.agentAdapterClient.rejectServerRequest(
        requestId: event.requestId,
        message: message,
      );
    } catch (error) {
      final userFacingError =
          ChatSessionErrors.rejectUnsupportedRequestFailed();
      context.reportAppServerFailure(
        userFacingError: userFacingError,
        runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
          userFacingError,
          error: error,
        ),
        suppressRuntimeError: false,
        suppressSnackBar: false,
      );
    }
  }

  Future<void> _resolveApproval(
    String requestId, {
    required bool approved,
  }) async {
    final pendingRequest = context.findPendingApprovalRequest(requestId);
    if (pendingRequest == null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.approvalRequestUnavailable(),
      );
      return;
    }

    try {
      await context.agentAdapterClient.resolveApproval(
        requestId: requestId,
        approved: approved,
      );
    } catch (error) {
      final userFacingError = approved
          ? ChatSessionErrors.approveRequestFailed()
          : ChatSessionErrors.denyRequestFailed();
      context.reportAppServerFailure(
        userFacingError: userFacingError,
        runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
          userFacingError,
          error: error,
        ),
        suppressRuntimeError: false,
        suppressSnackBar: false,
      );
    }
  }

  Object? _elicitationContentFromAnswers(Map<String, List<String>> answers) {
    if (answers.length == 1) {
      final entry = answers.entries.single;
      final values = entry.value;
      if (entry.key == 'response' && values.length == 1) {
        return values.single;
      }
      if (values.length == 1) {
        return <String, Object?>{entry.key: values.single};
      }
    }

    return answers.map<String, Object?>((key, values) {
      if (values.isEmpty) {
        return MapEntry<String, Object?>(key, null);
      }
      if (values.length == 1) {
        return MapEntry<String, Object?>(key, values.single);
      }
      return MapEntry<String, Object?>(key, values);
    });
  }
}

Map<String, dynamic>? _asObject(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _asString(Object? value) {
  return value is String ? value : null;
}
