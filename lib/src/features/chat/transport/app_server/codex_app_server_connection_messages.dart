part of 'codex_app_server_connection.dart';

void _handleProtocolMessageImpl(
  CodexAppServerConnection connection,
  String line,
) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return;
  }

  switch (connection._jsonRpcCodec.decodeLine(trimmed)) {
    case CodexJsonRpcMalformedMessage(:final problem):
      connection._emitEvent(
        CodexAppServerDiagnosticEvent(
          message: 'Malformed app-server message: $problem',
          isError: true,
        ),
      );
    case CodexJsonRpcDecodedMessage(:final message):
      switch (message) {
        case CodexJsonRpcRequest():
          connection._inboundRequestStore.remember(message);
          connection._emitEvent(
            CodexAppServerRequestEvent(
              requestId: message.id.token,
              method: message.method,
              params: message.params,
            ),
          );
        case CodexJsonRpcNotification():
          connection._updateRuntimePointers(message.method, message.params);
          connection._emitEvent(
            CodexAppServerNotificationEvent(
              method: message.method,
              params: message.params,
            ),
          );
        case CodexJsonRpcResponse():
          if (connection._requestTracker.completeResponse(message)) {
            return;
          }

          connection._emitEvent(
            CodexAppServerDiagnosticEvent(
              message:
                  'Received response for unknown request ${message.id.displayValue}.',
              isError: false,
            ),
          );
      }
  }
}

void _updateRuntimePointersImpl(
  CodexAppServerConnection connection,
  String method,
  Object? params,
) {
  final payload = CodexAppServerConnection._asObject(params);
  switch (method) {
    case 'session/exited':
    case 'session/closed':
      connection._threadId = null;
      connection._activeTurnId = null;
      break;
    case 'thread/started':
      final thread = CodexAppServerConnection._asObject(payload?['thread']);
      connection._threadId =
          CodexAppServerConnection._asString(thread?['id']) ??
          CodexAppServerConnection._asString(payload?['threadId']);
      connection._activeTurnId = null;
      break;
    case 'thread/closed':
      final threadId = CodexAppServerConnection._asString(payload?['threadId']);
      if (threadId == null || threadId == connection._threadId) {
        connection._threadId = null;
        connection._activeTurnId = null;
      }
      break;
    case 'turn/started':
      connection._threadId =
          CodexAppServerConnection._asString(payload?['threadId']) ??
          connection._threadId;
      final turn = CodexAppServerConnection._asObject(payload?['turn']);
      connection._activeTurnId =
          CodexAppServerConnection._asString(turn?['id']) ??
          CodexAppServerConnection._asString(payload?['turnId']);
      break;
    case 'turn/completed':
    case 'turn/aborted':
      final turn = CodexAppServerConnection._asObject(payload?['turn']);
      final turnId =
          CodexAppServerConnection._asString(turn?['id']) ??
          CodexAppServerConnection._asString(payload?['turnId']);
      if (turnId == null || turnId == connection._activeTurnId) {
        connection._activeTurnId = null;
      }
      break;
  }
}
