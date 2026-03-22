import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_models.dart';
import 'codex_json_rpc_codec.dart';

part 'codex_app_server_connection_lifecycle.dart';
part 'codex_app_server_connection_messages.dart';

class CodexAppServerConnection {
  CodexAppServerConnection({
    required CodexAppServerProcessLauncher processLauncher,
    required CodexJsonRpcCodec jsonRpcCodec,
    required CodexJsonRpcRequestTracker requestTracker,
    required CodexJsonRpcInboundRequestStore inboundRequestStore,
    required this.clientName,
    required this.clientVersion,
  }) : _processLauncher = processLauncher,
       _jsonRpcCodec = jsonRpcCodec,
       _requestTracker = requestTracker,
       _inboundRequestStore = inboundRequestStore;

  final CodexAppServerProcessLauncher _processLauncher;
  final CodexJsonRpcCodec _jsonRpcCodec;
  final CodexJsonRpcRequestTracker _requestTracker;
  final CodexJsonRpcInboundRequestStore _inboundRequestStore;
  final String clientName;
  final String clientVersion;

  final _eventsController = StreamController<CodexAppServerEvent>.broadcast();

  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Completer<void>? _stdoutClosedCompleter;
  Completer<void>? _stderrClosedCompleter;
  CodexAppServerProcess? _process;
  ConnectionProfile? _profile;
  bool _disconnecting = false;
  bool _isDisposed = false;
  String? _threadId;
  String? _activeTurnId;

  Stream<CodexAppServerEvent> get events => _eventsController.stream;
  bool get isConnected => _process != null;
  String? get threadId => _threadId;
  String? get activeTurnId => _activeTurnId;

  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _connectImpl(this, profile: profile, secrets: secrets);
  }

  Future<void> disconnect() {
    if (_isDisposed) {
      return Future<void>.value();
    }
    return _disconnect(emitDisconnectedEvent: true);
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _disconnect(emitDisconnectedEvent: false);
    await _eventsController.close();
  }

  Future<Object?> sendRequest(String method, Object? params) {
    _ensureNotDisposed();
    requireConnected();

    final trackedRequest = _requestTracker.createRequest(
      method,
      params: params,
    );
    writeMessage(trackedRequest.request);
    return trackedRequest.response.then<Object?>(
      (value) => value,
      onError: (Object error, StackTrace stackTrace) {
        if (error is CodexJsonRpcRemoteException) {
          throw CodexAppServerException(
            error.error.message,
            code: error.error.code,
            data: error.error.data,
          );
        }
        throw error;
      },
    );
  }

  Future<void> sendServerResult({
    required String requestId,
    required Object? result,
  }) async {
    _ensureNotDisposed();
    final pending = _inboundRequestStore.take(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }

    writeMessage(CodexJsonRpcResponse.success(id: pending.id, result: result));
  }

  Future<void> rejectServerRequest({
    required String requestId,
    required String message,
    int code = -32000,
    Object? data,
  }) async {
    _ensureNotDisposed();
    final pending = _inboundRequestStore.take(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }

    writeMessage(
      CodexJsonRpcResponse.failure(
        id: pending.id,
        error: CodexJsonRpcError(message: message, code: code, data: data),
      ),
    );
  }

  ConnectionProfile requireProfile() {
    _ensureNotDisposed();
    final profile = _profile;
    if (profile == null) {
      throw const CodexAppServerException(
        'Connect to app-server before starting a session.',
      );
    }
    return profile;
  }

  void requireConnected() {
    _ensureNotDisposed();
    if (_process == null) {
      throw const CodexAppServerException('App-server is not connected.');
    }
  }

  CodexJsonRpcRequest requirePendingServerRequest(String requestId) {
    _ensureNotDisposed();
    final pending = _inboundRequestStore.lookup(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }
    return pending;
  }

  void setTrackedThread(String? threadId) {
    _ensureNotDisposed();
    _threadId = threadId;
    _activeTurnId = null;
  }

  void setTrackedTurn({required String threadId, required String turnId}) {
    _ensureNotDisposed();
    _threadId = threadId;
    _activeTurnId = turnId;
  }

  Future<void> _disconnect({required bool emitDisconnectedEvent}) {
    return _disconnectImpl(this, emitDisconnectedEvent: emitDisconnectedEvent);
  }

  void _handleStdoutLine(String line) {
    _handleStdoutLineImpl(this, line);
  }

  void _updateRuntimePointers(String method, Object? params) {
    _updateRuntimePointersImpl(this, method, params);
  }

  void _handleProcessClosed() {
    _handleProcessClosedImpl(this);
  }

  void writeMessage(CodexJsonRpcMessage message) {
    final process = _process;
    if (process == null) {
      throw const CodexAppServerException('App-server is not connected.');
    }

    final line = _jsonRpcCodec.encodeLine(message);
    process.stdin.add(Uint8List.fromList(utf8.encode(line)));
  }

  void _emitEvent(CodexAppServerEvent event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  Future<void> _drainOutputStreams() async {
    final futures = <Future<void>>[];
    final stdoutClosedCompleter = _stdoutClosedCompleter;
    final stderrClosedCompleter = _stderrClosedCompleter;
    if (stdoutClosedCompleter != null && !stdoutClosedCompleter.isCompleted) {
      futures.add(stdoutClosedCompleter.future);
    }
    if (stderrClosedCompleter != null && !stderrClosedCompleter.isCompleted) {
      futures.add(stderrClosedCompleter.future);
    }
    if (futures.isEmpty) {
      return;
    }

    try {
      await Future.wait(futures).timeout(const Duration(milliseconds: 100));
    } on TimeoutException {
      // Don't block teardown indefinitely if a transport stream never closes.
    }
  }

  Stream<String> _decodeLines(Stream<Uint8List> stream) {
    return stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw const CodexAppServerException(
        'App-server connection has been disposed.',
      );
    }
  }

  static Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }
}
