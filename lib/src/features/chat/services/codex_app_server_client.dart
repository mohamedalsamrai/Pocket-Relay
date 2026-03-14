import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/services/codex_json_rpc_codec.dart';
import 'package:dartssh2/dartssh2.dart';

sealed class CodexAppServerEvent {
  const CodexAppServerEvent();
}

class CodexAppServerConnectedEvent extends CodexAppServerEvent {
  const CodexAppServerConnectedEvent({this.userAgent});

  final String? userAgent;
}

class CodexAppServerDisconnectedEvent extends CodexAppServerEvent {
  const CodexAppServerDisconnectedEvent({this.exitCode});

  final int? exitCode;
}

class CodexAppServerNotificationEvent extends CodexAppServerEvent {
  const CodexAppServerNotificationEvent({
    required this.method,
    required this.params,
  });

  final String method;
  final Object? params;
}

class CodexAppServerRequestEvent extends CodexAppServerEvent {
  const CodexAppServerRequestEvent({
    required this.requestId,
    required this.method,
    required this.params,
  });

  final String requestId;
  final String method;
  final Object? params;
}

class CodexAppServerDiagnosticEvent extends CodexAppServerEvent {
  const CodexAppServerDiagnosticEvent({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;
}

class CodexAppServerSession {
  const CodexAppServerSession({
    required this.threadId,
    required this.cwd,
    required this.model,
    required this.modelProvider,
    this.approvalPolicy,
    this.sandbox,
  });

  final String threadId;
  final String cwd;
  final String model;
  final String modelProvider;
  final Object? approvalPolicy;
  final Object? sandbox;
}

class CodexAppServerTurn {
  const CodexAppServerTurn({required this.threadId, required this.turnId});

  final String threadId;
  final String turnId;
}

enum CodexAppServerElicitationAction { accept, decline, cancel }

class CodexAppServerException implements Exception {
  const CodexAppServerException(this.message, {this.code, this.data});

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() {
    if (code == null) {
      return 'CodexAppServerException: $message';
    }
    return 'CodexAppServerException($code): $message';
  }
}

abstract interface class CodexAppServerProcess {
  Stream<Uint8List> get stdout;
  Stream<Uint8List> get stderr;
  StreamSink<Uint8List> get stdin;
  Future<void> get done;
  int? get exitCode;
  Future<void> close();
}

typedef CodexAppServerProcessLauncher =
    Future<CodexAppServerProcess> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required void Function(CodexAppServerEvent event) emitEvent,
    });

class CodexAppServerClient {
  CodexAppServerClient({
    CodexAppServerProcessLauncher? processLauncher,
    CodexJsonRpcCodec? jsonRpcCodec,
    CodexJsonRpcRequestTracker? requestTracker,
    CodexJsonRpcInboundRequestStore? inboundRequestStore,
    this.clientName = 'pocket_relay',
    this.clientVersion = '1.0.0',
  }) : _processLauncher = processLauncher ?? _openSshProcess,
       _jsonRpcCodec = jsonRpcCodec ?? const CodexJsonRpcCodec(),
       _requestTracker = requestTracker ?? CodexJsonRpcRequestTracker(),
       _inboundRequestStore =
           inboundRequestStore ?? CodexJsonRpcInboundRequestStore();

  final CodexAppServerProcessLauncher _processLauncher;
  final CodexJsonRpcCodec _jsonRpcCodec;
  final CodexJsonRpcRequestTracker _requestTracker;
  final CodexJsonRpcInboundRequestStore _inboundRequestStore;
  final String clientName;
  final String clientVersion;

  final _eventsController = StreamController<CodexAppServerEvent>.broadcast();

  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  CodexAppServerProcess? _process;
  ConnectionProfile? _profile;
  bool _disconnecting = false;
  String? _threadId;
  String? _activeTurnId;

  Stream<CodexAppServerEvent> get events => _eventsController.stream;

  bool get isConnected => _process != null;
  String? get threadId => _threadId;
  String? get activeTurnId => _activeTurnId;

  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    if (isConnected) {
      await disconnect();
    }

    _disconnecting = false;

    try {
      final process = await _processLauncher(
        profile: profile,
        secrets: secrets,
        emitEvent: _emitEvent,
      );

      _process = process;
      _profile = profile;
      _stdoutSubscription = _decodeLines(process.stdout).listen(
        _handleStdoutLine,
        onError: (Object error, StackTrace stackTrace) {
          _emitEvent(
            CodexAppServerDiagnosticEvent(
              message: 'Failed to decode app-server stdout: $error',
              isError: true,
            ),
          );
        },
        onDone: _handleProcessClosed,
      );
      _stderrSubscription = _decodeLines(process.stderr).listen((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return;
        }

        _emitEvent(
          CodexAppServerDiagnosticEvent(message: trimmed, isError: true),
        );
      });

      process.done.then((_) {
        if (!_disconnecting) {
          _handleProcessClosed();
        }
      });

      final initializeResponse = await _sendRequest(
        'initialize',
        <String, Object?>{
          'clientInfo': <String, String>{
            'name': clientName,
            'title': 'Pocket Relay',
            'version': clientVersion,
          },
          'capabilities': const <String, bool>{'experimentalApi': true},
        },
      ).timeout(const Duration(seconds: 10));

      _writeMessage(const CodexJsonRpcNotification(method: 'initialized'));
      final payload = _asObject(initializeResponse);
      _emitEvent(
        CodexAppServerConnectedEvent(
          userAgent: _asString(payload?['userAgent']),
        ),
      );
    } catch (error) {
      await _disconnect(emitDisconnectedEvent: false);
      rethrow;
    }
  }

  Future<CodexAppServerSession> startSession({
    String? cwd,
    String? model,
    String? resumeThreadId,
  }) async {
    final profile = _requireProfile();
    _requireConnected();

    final effectiveCwd = (cwd ?? profile.workspaceDir).trim().isEmpty
        ? profile.workspaceDir.trim()
        : (cwd ?? profile.workspaceDir).trim();
    final normalizedResumeThreadId = resumeThreadId?.trim();
    final effectiveResumeThreadId =
        profile.ephemeralSession ||
            normalizedResumeThreadId == null ||
            normalizedResumeThreadId.isEmpty
        ? null
        : normalizedResumeThreadId;
    final baseParams = <String, Object?>{
      'cwd': effectiveCwd,
      'approvalPolicy': _approvalPolicyFor(profile),
      'sandbox': _sandboxFor(profile),
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    };
    var method = effectiveResumeThreadId != null
        ? 'thread/resume'
        : 'thread/start';
    final resumeThreadParam = effectiveResumeThreadId == null
        ? null
        : <String, Object?>{'threadId': effectiveResumeThreadId};
    var params = <String, Object?>{
      ...baseParams,
      if (method == 'thread/start') 'ephemeral': profile.ephemeralSession,
      ...?resumeThreadParam,
    };

    Object? response;
    try {
      response = await _sendRequest(method, params);
    } on CodexAppServerException catch (error) {
      if (effectiveResumeThreadId == null ||
          !_isRecoverableThreadResumeError(error)) {
        rethrow;
      }

      method = 'thread/start';
      params = <String, Object?>{
        ...baseParams,
        'ephemeral': profile.ephemeralSession,
      };
      response = await _sendRequest(method, params);
    }

    final payload = _requireObject(response, '$method response');
    final thread = _requireObject(payload['thread'], '$method thread');
    final threadId =
        _asString(thread['id']) ?? _asString(payload['threadId']) ?? '';

    if (threadId.isEmpty) {
      throw CodexAppServerException(
        '$method response did not include a thread id.',
      );
    }

    _threadId = threadId;
    _activeTurnId = null;

    return CodexAppServerSession(
      threadId: threadId,
      cwd: _asString(payload['cwd']) ?? effectiveCwd,
      model: _asString(payload['model']) ?? '',
      modelProvider: _asString(payload['modelProvider']) ?? '',
      approvalPolicy: payload['approvalPolicy'],
      sandbox: payload['sandbox'],
    );
  }

  Future<CodexAppServerTurn> sendUserMessage({
    required String threadId,
    required String text,
    String? model,
  }) async {
    _requireConnected();

    final effectiveThreadId = threadId.trim();
    final trimmedText = text.trim();
    if (effectiveThreadId.isEmpty) {
      throw const CodexAppServerException('Thread id cannot be empty.');
    }
    if (trimmedText.isEmpty) {
      throw const CodexAppServerException('Turn input cannot be empty.');
    }

    final params = <String, Object?>{
      'threadId': effectiveThreadId,
      'input': <Object>[
        <String, Object?>{
          'type': 'text',
          'text': trimmedText,
          'text_elements': const <Object>[],
        },
      ],
      if (model != null && model.trim().isNotEmpty) 'model': model.trim(),
    };

    final response = await _sendRequest('turn/start', params);
    final payload = _requireObject(response, 'turn/start response');
    final turn = _requireObject(payload['turn'], 'turn/start turn');
    final turnId = _asString(turn['id']) ?? '';

    if (turnId.isEmpty) {
      throw const CodexAppServerException(
        'turn/start response did not include a turn id.',
      );
    }

    _threadId = effectiveThreadId;
    _activeTurnId = turnId;

    return CodexAppServerTurn(threadId: effectiveThreadId, turnId: turnId);
  }

  Future<void> answerUserInput({
    required String requestId,
    required Map<String, List<String>> answers,
  }) async {
    final pending = _requirePendingServerRequest(requestId);
    if (pending.method != 'item/tool/requestUserInput') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not item/tool/requestUserInput.',
      );
    }

    await sendServerResult(
      requestId: requestId,
      result: <String, Object?>{
        'answers': answers.map(
          (key, value) => MapEntry<String, Object?>(key, <String, Object?>{
            'answers': value,
          }),
        ),
      },
    );
  }

  Future<void> resolveApproval({
    required String requestId,
    required bool approved,
  }) async {
    final pending = _requirePendingServerRequest(requestId);
    if (pending.method == 'item/permissions/requestApproval') {
      await resolvePermissionsRequest(requestId: requestId, approved: approved);
      return;
    }

    final decision = switch (pending.method) {
      'item/commandExecution/requestApproval' =>
        approved ? 'accept' : 'decline',
      'item/fileChange/requestApproval' => approved ? 'accept' : 'decline',
      'applyPatchApproval' => approved ? 'approved' : 'denied',
      'execCommandApproval' => approved ? 'approved' : 'denied',
      _ => throw CodexAppServerException(
        'Boolean approval is not supported for ${pending.method}.',
      ),
    };

    await sendServerResult(
      requestId: requestId,
      result: <String, Object?>{'decision': decision},
    );
  }

  Future<void> resolvePermissionsRequest({
    required String requestId,
    required bool approved,
    String scope = 'turn',
  }) async {
    if (scope != 'turn' && scope != 'session') {
      throw CodexAppServerException('Unsupported permission scope: $scope');
    }

    final pending = _requirePendingServerRequest(requestId);
    if (pending.method != 'item/permissions/requestApproval') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not item/permissions/requestApproval.',
      );
    }

    final payload = _asObject(pending.params);
    final requestedPermissions = _asObject(payload?['permissions']);
    await sendServerResult(
      requestId: requestId,
      result: <String, Object?>{
        'permissions': approved
            ? _grantedPermissionsFromRequest(requestedPermissions)
            : const <String, Object?>{},
        'scope': scope,
      },
    );
  }

  Future<void> respondToElicitation({
    required String requestId,
    required CodexAppServerElicitationAction action,
    Object? content,
    Object? metadata,
  }) async {
    final pending = _requirePendingServerRequest(requestId);
    if (pending.method != 'mcpServer/elicitation/request') {
      throw CodexAppServerException(
        'Request $requestId is ${pending.method}, not mcpServer/elicitation/request.',
      );
    }

    if (action != CodexAppServerElicitationAction.accept && content != null) {
      throw const CodexAppServerException(
        'Only accepted elicitation responses may include content.',
      );
    }

    final result = <String, Object?>{'action': action.name};
    if (content != null) {
      result['content'] = content;
    }
    if (metadata != null) {
      result['_meta'] = metadata;
    }

    await sendServerResult(requestId: requestId, result: result);
  }

  Future<void> sendServerResult({
    required String requestId,
    required Object? result,
  }) async {
    final pending = _inboundRequestStore.take(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }
    _writeMessage(CodexJsonRpcResponse.success(id: pending.id, result: result));
  }

  Future<void> abortTurn({String? threadId, String? turnId}) async {
    final effectiveThreadId = threadId ?? _threadId;
    final effectiveTurnId = turnId ?? _activeTurnId;

    if (effectiveThreadId == null || effectiveTurnId == null) {
      return;
    }

    await _sendRequest('turn/interrupt', <String, Object?>{
      'threadId': effectiveThreadId,
      'turnId': effectiveTurnId,
    });
  }

  Future<void> disconnect() async {
    await _disconnect(emitDisconnectedEvent: true);
  }

  Future<void> _disconnect({required bool emitDisconnectedEvent}) async {
    _disconnecting = true;

    final process = _process;
    _process = null;
    _profile = null;
    _threadId = null;
    _activeTurnId = null;

    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;

    _requestTracker.failPending(
      const CodexAppServerException('App-server session disconnected.'),
    );
    _inboundRequestStore.clear();

    if (process != null) {
      final exitCode = process.exitCode;
      await process.close();
      if (emitDisconnectedEvent) {
        _emitEvent(CodexAppServerDisconnectedEvent(exitCode: exitCode));
      }
    }
  }

  Future<Object?> _sendRequest(String method, Map<String, Object?> params) {
    _requireConnected();

    final trackedRequest = _requestTracker.createRequest(
      method,
      params: params,
    );
    _writeMessage(trackedRequest.request);
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

  void _handleStdoutLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }

    switch (_jsonRpcCodec.decodeLine(trimmed)) {
      case CodexJsonRpcMalformedMessage(:final problem):
        _emitEvent(
          CodexAppServerDiagnosticEvent(
            message: 'Malformed app-server message: $problem',
            isError: true,
          ),
        );
      case CodexJsonRpcDecodedMessage(:final message):
        switch (message) {
          case CodexJsonRpcRequest():
            _inboundRequestStore.remember(message);
            _emitEvent(
              CodexAppServerRequestEvent(
                requestId: message.id.token,
                method: message.method,
                params: message.params,
              ),
            );
          case CodexJsonRpcNotification():
            _updateRuntimePointers(message.method, message.params);
            _emitEvent(
              CodexAppServerNotificationEvent(
                method: message.method,
                params: message.params,
              ),
            );
          case CodexJsonRpcResponse():
            if (_requestTracker.completeResponse(message)) {
              return;
            }

            _emitEvent(
              CodexAppServerDiagnosticEvent(
                message:
                    'Received response for unknown request ${message.id.displayValue}.',
                isError: false,
              ),
            );
        }
    }
  }

  void _updateRuntimePointers(String method, Object? params) {
    final payload = _asObject(params);
    switch (method) {
      case 'session/exited':
      case 'session/closed':
        _threadId = null;
        _activeTurnId = null;
        break;
      case 'thread/started':
        final thread = _asObject(payload?['thread']);
        _threadId = _asString(thread?['id']) ?? _asString(payload?['threadId']);
        _activeTurnId = null;
        break;
      case 'thread/closed':
        final threadId = _asString(payload?['threadId']);
        if (threadId == null || threadId == _threadId) {
          _threadId = null;
          _activeTurnId = null;
        }
        break;
      case 'turn/started':
        _threadId = _asString(payload?['threadId']) ?? _threadId;
        final turn = _asObject(payload?['turn']);
        _activeTurnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
        break;
      case 'turn/completed':
      case 'turn/aborted':
        final turn = _asObject(payload?['turn']);
        final turnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
        if (turnId == null || turnId == _activeTurnId) {
          _activeTurnId = null;
        }
        break;
    }
  }

  void _handleProcessClosed() {
    if (_process == null) {
      return;
    }
    unawaited(_disconnect(emitDisconnectedEvent: true));
  }

  void _writeMessage(CodexJsonRpcMessage message) {
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

  ConnectionProfile _requireProfile() {
    final profile = _profile;
    if (profile == null) {
      throw const CodexAppServerException(
        'Connect to app-server before starting a session.',
      );
    }
    return profile;
  }

  void _requireConnected() {
    if (_process == null) {
      throw const CodexAppServerException('App-server is not connected.');
    }
  }

  CodexJsonRpcRequest _requirePendingServerRequest(String requestId) {
    final pending = _inboundRequestStore.lookup(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }
    return pending;
  }

  Stream<String> _decodeLines(Stream<Uint8List> stream) {
    return stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  static Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Map<String, dynamic> _requireObject(Object? value, String label) {
    final object = _asObject(value);
    if (object == null) {
      throw CodexAppServerException('$label was not an object.');
    }
    return object;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }

  static String _approvalPolicyFor(ConnectionProfile profile) {
    return profile.dangerouslyBypassSandbox ? 'never' : 'onRequest';
  }

  static String _sandboxFor(ConnectionProfile profile) {
    return profile.dangerouslyBypassSandbox
        ? 'danger-full-access'
        : 'workspace-write';
  }

  static Map<String, Object?> _grantedPermissionsFromRequest(
    Map<String, dynamic>? requested,
  ) {
    if (requested == null) {
      return const <String, Object?>{};
    }

    return <String, Object?>{
      if (requested['network'] != null) 'network': requested['network'],
      if (requested['fileSystem'] != null)
        'fileSystem': requested['fileSystem'],
      if (requested['macos'] != null) 'macos': requested['macos'],
    };
  }

  static bool _isRecoverableThreadResumeError(Object error) {
    final message = error.toString().toLowerCase();
    if (!message.contains('thread/resume')) {
      return false;
    }

    return const <String>[
      'not found',
      'missing thread',
      'no such thread',
      'unknown thread',
      'does not exist',
    ].any(message.contains);
  }
}

Future<CodexAppServerProcess> _openSshProcess({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
}) async {
  final socket = await SSHSocket.connect(
    profile.host.trim(),
    profile.port,
    timeout: const Duration(seconds: 10),
  );

  final client = SSHClient(
    socket,
    username: profile.username.trim(),
    onVerifyHostKey: (type, fingerprint) {
      final actual = formatFingerprint(fingerprint);
      final expected = profile.hostFingerprint.trim();

      if (expected.isEmpty) {
        emitEvent(
          CodexAppServerDiagnosticEvent(
            message:
                'Accepted $type host key fingerprint $actual. Pin it later if you want stricter verification.',
            isError: false,
          ),
        );
        return true;
      }

      if (normalizeFingerprint(expected) == normalizeFingerprint(actual)) {
        return true;
      }

      emitEvent(
        CodexAppServerDiagnosticEvent(
          message:
              'Host key mismatch. Expected ${profile.hostFingerprint}, got $actual.',
          isError: true,
        ),
      );
      return false;
    },
    identities: _buildIdentities(profile, secrets),
    onPasswordRequest: profile.authMode == AuthMode.password
        ? () => secrets.password.trim().isEmpty ? null : secrets.password
        : null,
  );

  await client.authenticated;
  emitEvent(
    CodexAppServerDiagnosticEvent(
      message:
          'Connected to ${profile.host}:${profile.port} as ${profile.username}.',
      isError: false,
    ),
  );

  final session = await client.execute(_buildRemoteCommand(profile: profile));
  return _SshCodexAppServerProcess(client: client, session: session);
}

List<SSHKeyPair>? _buildIdentities(
  ConnectionProfile profile,
  ConnectionSecrets secrets,
) {
  if (profile.authMode != AuthMode.privateKey) {
    return null;
  }

  final privateKey = secrets.privateKeyPem.trim();
  if (privateKey.isEmpty) {
    throw StateError('A private key is required for key-based SSH auth.');
  }

  final passphrase = secrets.privateKeyPassphrase.trim();
  return SSHKeyPair.fromPem(privateKey, passphrase.isEmpty ? null : passphrase);
}

String _buildRemoteCommand({required ConnectionProfile profile}) {
  final codexArgs = <String>[
    profile.codexPath.trim(),
    'app-server',
    '--listen',
    'stdio://',
  ];
  final codexCommand = codexArgs.map(shellEscape).join(' ');
  final command =
      'cd ${shellEscape(profile.workspaceDir.trim())} && $codexCommand';
  return 'bash -lc ${shellEscape(command)}';
}

class _SshCodexAppServerProcess implements CodexAppServerProcess {
  _SshCodexAppServerProcess({required this.client, required this.session});

  final SSHClient client;
  final SSHSession session;

  @override
  Stream<Uint8List> get stdout => session.stdout;

  @override
  Stream<Uint8List> get stderr => session.stderr;

  @override
  StreamSink<Uint8List> get stdin => session.stdin;

  @override
  Future<void> get done => session.done;

  @override
  int? get exitCode => session.exitCode;

  @override
  Future<void> close() async {
    try {
      session.close();
    } catch (_) {
      // Ignore close errors when the remote process has already ended.
    }
    client.close();
  }
}
