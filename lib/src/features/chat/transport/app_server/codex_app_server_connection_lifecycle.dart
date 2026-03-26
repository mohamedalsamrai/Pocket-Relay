part of 'codex_app_server_connection.dart';

Future<void> _connectImpl(
  CodexAppServerConnection connection, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  connection._ensureNotDisposed();
  if (connection.isConnected) {
    await connection.disconnect();
  }

  connection._disconnecting = false;

  try {
    final transport = await connection._transportOpener(
      profile: profile,
      secrets: secrets,
      emitEvent: connection._emitEvent,
    );

    connection._transport = transport;
    connection._profile = profile;
    connection._protocolMessagesClosedCompleter = Completer<void>();
    connection._diagnosticsClosedCompleter = Completer<void>();
    connection._protocolMessageSubscription = transport.protocolMessages.listen(
      connection._handleProtocolMessage,
      onError: (Object error, StackTrace stackTrace) {
        connection._emitEvent(
          CodexAppServerDiagnosticEvent(
            message: 'Failed to read app-server protocol messages: $error',
            isError: true,
          ),
        );
      },
      onDone: () {
        connection._protocolMessagesClosedCompleter?.complete();
        connection._handleProcessClosed();
      },
    );
    connection._diagnosticSubscription = transport.diagnostics.listen(
      (line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return;
        }

        connection._emitEvent(
          CodexAppServerDiagnosticEvent(message: trimmed, isError: true),
        );
      },
      onDone: () {
        connection._diagnosticsClosedCompleter?.complete();
      },
    );

    transport.done.then((_) {
      if (!connection._disconnecting) {
        connection._handleProcessClosed();
      }
    });

    final initializeResponse = await connection
        .sendRequest('initialize', <String, Object?>{
          'clientInfo': <String, String>{
            'name': connection.clientName,
            'title': 'Pocket Relay',
            'version': connection.clientVersion,
          },
          'capabilities': const <String, bool>{'experimentalApi': true},
        })
        .timeout(const Duration(seconds: 10));

    connection.writeMessage(
      const CodexJsonRpcNotification(method: 'initialized'),
    );
    final payload = CodexAppServerConnection._asObject(initializeResponse);
    connection._emitEvent(
      CodexAppServerConnectedEvent(
        userAgent: CodexAppServerConnection._asString(payload?['userAgent']),
      ),
    );
  } catch (error) {
    await connection._disconnect(emitDisconnectedEvent: false);
    rethrow;
  }
}

Future<void> _disconnectImpl(
  CodexAppServerConnection connection, {
  required bool emitDisconnectedEvent,
}) async {
  connection._disconnecting = true;

  final transport = connection._transport;
  connection._transport = null;
  connection._profile = null;
  connection._threadId = null;
  connection._activeTurnId = null;

  if (transport != null) {
    final exitCode = transport.termination?.exitCode;
    await transport.close();
    await connection._drainOutputStreams();
    await connection._protocolMessageSubscription?.cancel();
    await connection._diagnosticSubscription?.cancel();
    connection._protocolMessageSubscription = null;
    connection._diagnosticSubscription = null;
    connection._protocolMessagesClosedCompleter = null;
    connection._diagnosticsClosedCompleter = null;
    connection._requestTracker.failPending(
      const CodexAppServerException('App-server session disconnected.'),
    );
    connection._inboundRequestStore.clear();
    if (emitDisconnectedEvent) {
      connection._emitEvent(
        CodexAppServerDisconnectedEvent(exitCode: exitCode),
      );
    }
    return;
  }

  await connection._protocolMessageSubscription?.cancel();
  await connection._diagnosticSubscription?.cancel();
  connection._protocolMessageSubscription = null;
  connection._diagnosticSubscription = null;
  connection._protocolMessagesClosedCompleter = null;
  connection._diagnosticsClosedCompleter = null;
  connection._requestTracker.failPending(
    const CodexAppServerException('App-server session disconnected.'),
  );
  connection._inboundRequestStore.clear();
}

void _handleProcessClosedImpl(CodexAppServerConnection connection) {
  if (connection._transport == null) {
    return;
  }
  unawaited(connection._disconnect(emitDisconnectedEvent: true));
}
