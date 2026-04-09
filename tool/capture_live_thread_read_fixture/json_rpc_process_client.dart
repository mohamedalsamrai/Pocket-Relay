import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:pocket_relay/src/features/chat/transport/app_server/codex_json_rpc_codec.dart';

final class JsonRpcProcessClient {
  JsonRpcProcessClient(this._process) {
    _stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine);
    _stderrSubscription = _process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_handleStderrLine);
  }

  final Process _process;
  final CodexJsonRpcCodec _codec = const CodexJsonRpcCodec();
  final List<String> _stderrLines = <String>[];
  final Map<String, Completer<Object?>> _pendingRequests =
      <String, Completer<Object?>>{};
  late final StreamSubscription<String> _stdoutSubscription;
  late final StreamSubscription<String> _stderrSubscription;
  int _nextRequestId = 1;

  Future<void> initialize() async {
    await _sendRequest(
      method: 'initialize',
      params: <String, Object?>{
        'clientInfo': const <String, String>{
          'name': 'pocket_relay_fixture_capture',
          'title': 'Pocket Relay Fixture Capture',
          'version': '1.0.0',
        },
        'capabilities': const <String, bool>{'experimentalApi': true},
      },
    );
    _writeMessage(const CodexJsonRpcNotification(method: 'initialized'));
  }

  Future<Map<String, dynamic>> readThread(String threadId) async {
    final response = await _sendRequest(
      method: 'thread/read',
      params: <String, Object?>{'threadId': threadId, 'includeTurns': true},
    );
    if (response is! Map) {
      throw StateError('thread/read response was not a JSON object.');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<String> stderrTail() async {
    if (_stderrLines.isEmpty) {
      return '';
    }
    return _stderrLines.join('\n');
  }

  Future<void> close() async {
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('App-server process closed before request completed.'),
        );
      }
    }
    _pendingRequests.clear();
    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    _process.kill();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore shutdown races.
    }
  }

  Future<Object?> _sendRequest({
    required String method,
    required Object? params,
  }) {
    final request = CodexJsonRpcRequest(
      id: CodexJsonRpcId(_nextRequestId++),
      method: method,
      params: params,
    );
    final completer = Completer<Object?>();
    _pendingRequests[request.id.token] = completer;
    _writeMessage(request);
    return completer.future;
  }

  void _writeMessage(CodexJsonRpcMessage message) {
    _process.stdin.write(_codec.encodeLine(message));
  }

  void _handleStdoutLine(String line) {
    final decoded = _codec.decodeLine(line);
    if (decoded is! CodexJsonRpcDecodedMessage) {
      return;
    }

    final message = decoded.message;
    switch (message) {
      case CodexJsonRpcResponse(:final id, :final isError):
        final completer = _pendingRequests.remove(id.token);
        if (completer == null || completer.isCompleted) {
          return;
        }
        if (isError) {
          completer.completeError(
            JsonRpcRemoteException(
              message.error?.message ?? 'Unknown JSON-RPC error.',
              code: message.error?.code,
              data: message.error?.data,
            ),
          );
        } else {
          completer.complete(message.result);
        }
      case CodexJsonRpcRequest(:final id):
        _writeMessage(
          CodexJsonRpcResponse.failure(
            id: id,
            error: const CodexJsonRpcError(
              code: -32000,
              message: 'Unexpected server request during fixture capture.',
            ),
          ),
        );
      case CodexJsonRpcNotification():
      // Ignore notifications during capture.
    }
  }

  void _handleStderrLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _stderrLines.add(trimmed);
    if (_stderrLines.length > 40) {
      _stderrLines.removeAt(0);
    }
  }
}

final class JsonRpcRemoteException implements Exception {
  const JsonRpcRemoteException(this.message, {this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() {
    if (code == null) {
      return message;
    }
    return '[$code] $message';
  }
}
