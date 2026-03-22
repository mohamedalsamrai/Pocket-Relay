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
    final process = await connection._processLauncher(
      profile: profile,
      secrets: secrets,
      emitEvent: connection._emitEvent,
    );

    connection._process = process;
    connection._profile = profile;
    connection._stdoutClosedCompleter = Completer<void>();
    connection._stderrClosedCompleter = Completer<void>();
    connection._stdoutSubscription = connection._decodeLines(process.stdout).listen(
      connection._handleStdoutLine,
      onError: (Object error, StackTrace stackTrace) {
        connection._emitEvent(
          CodexAppServerDiagnosticEvent(
            message: 'Failed to decode app-server stdout: $error',
            isError: true,
          ),
        );
      },
      onDone: () {
        connection._stdoutClosedCompleter?.complete();
        connection._handleProcessClosed();
      },
    );
    connection._stderrSubscription = connection._decodeLines(process.stderr).listen(
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
        connection._stderrClosedCompleter?.complete();
      },
    );

    process.done.then((_) {
      if (!connection._disconnecting) {
        connection._handleProcessClosed();
      }
    });

    final initializeResponse = await connection
        .sendRequest(
          'initialize',
          <String, Object?>{
            'clientInfo': <String, String>{
              'name': connection.clientName,
              'title': 'Pocket Relay',
              'version': connection.clientVersion,
            },
            'capabilities': const <String, bool>{'experimentalApi': true},
          },
        )
        .timeout(const Duration(seconds: 10));

    connection.writeMessage(const CodexJsonRpcNotification(method: 'initialized'));
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

  final process = connection._process;
  connection._process = null;
  connection._profile = null;
  connection._threadId = null;
  connection._activeTurnId = null;

  if (process != null) {
    final exitCode = process.exitCode;
    await process.close();
    await connection._drainOutputStreams();
    await connection._stdoutSubscription?.cancel();
    await connection._stderrSubscription?.cancel();
    connection._stdoutSubscription = null;
    connection._stderrSubscription = null;
    connection._stdoutClosedCompleter = null;
    connection._stderrClosedCompleter = null;
    connection._requestTracker.failPending(
      const CodexAppServerException('App-server session disconnected.'),
    );
    connection._inboundRequestStore.clear();
    if (emitDisconnectedEvent) {
      connection._emitEvent(CodexAppServerDisconnectedEvent(exitCode: exitCode));
    }
    return;
  }

  await connection._stdoutSubscription?.cancel();
  await connection._stderrSubscription?.cancel();
  connection._stdoutSubscription = null;
  connection._stderrSubscription = null;
  connection._stdoutClosedCompleter = null;
  connection._stderrClosedCompleter = null;
  connection._requestTracker.failPending(
    const CodexAppServerException('App-server session disconnected.'),
  );
  connection._inboundRequestStore.clear();
}

void _handleProcessClosedImpl(CodexAppServerConnection connection) {
  if (connection._process == null) {
    return;
  }
  unawaited(connection._disconnect(emitDisconnectedEvent: true));
}
