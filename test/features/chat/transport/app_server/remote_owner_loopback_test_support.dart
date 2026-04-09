import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart';

export 'dart:async';
export 'dart:io';
export 'dart:typed_data';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_ssh_forward.dart';

final String? installedSystemTmuxPath = _resolveSystemTmuxPathSync();

enum RemoteOwnerTmuxMode { none, shim, system }

final class RemoteOwnerLoopbackHarness {
  RemoteOwnerLoopbackHarness._({
    required this.rootDir,
    required this.sessionRoot,
    required this.profile,
    required this.environment,
    required this.tmuxMode,
    required this.systemTmuxPath,
    required this.logFile,
    required this.tmuxSocketPath,
  });

  final Directory rootDir;
  final Directory sessionRoot;
  final ConnectionProfile profile;
  final Map<String, String> environment;
  final RemoteOwnerTmuxMode tmuxMode;
  final String? systemTmuxPath;
  final File logFile;
  final String? tmuxSocketPath;
  final ConnectionSecrets secrets = const ConnectionSecrets(password: 'secret');
  final Set<String> _ownerIds = <String>{};
  int _ownerCounter = 0;
  bool _disposed = false;

  static Future<RemoteOwnerLoopbackHarness> create({
    required RemoteOwnerTmuxMode tmuxMode,
  }) async {
    final rootDir = await Directory.systemTemp.createTemp(
      'pocket_relay_remote_owner_loopback_',
    );
    final binDir = Directory(_joinPath(rootDir.path, 'bin'))..createSync();
    final workspaceDir = Directory(_joinPath(rootDir.path, 'workspace'))
      ..createSync();
    final sessionRoot = Directory(_joinPath(rootDir.path, 'tmux_sessions'))
      ..createSync();
    final logFile = File(_joinPath(rootDir.path, 'fake_codex.log'));
    await logFile.writeAsString('');
    final tmuxSocketPath = tmuxMode == RemoteOwnerTmuxMode.system
        ? _joinPath(rootDir.path, 'tmux.socket')
        : null;

    final dartExecutable = await _resolveDartExecutable();
    final fakeCodexServer = File(
      _joinPath(rootDir.path, 'fake_codex_server.dart'),
    );
    final fakeCodexPath = _joinPath(binDir.path, 'codex');
    await fakeCodexServer.writeAsString(_fakeCodexServerSource);
    await _writeExecutable(
      File(fakeCodexPath),
      _buildFakeCodexShim(
        dartExecutable: dartExecutable,
        serverScriptPath: fakeCodexServer.path,
        logFilePath: logFile.path,
      ),
    );
    await _writeExecutable(
      File(_joinPath(binDir.path, 'bash')),
      _bashWrapperScript,
    );

    if (tmuxMode == RemoteOwnerTmuxMode.shim) {
      await _writeExecutable(
        File(_joinPath(binDir.path, 'tmux')),
        _buildTmuxShim(sessionRoot.path),
      );
    }
    final resolvedSystemTmuxPath = tmuxMode == RemoteOwnerTmuxMode.system
        ? (installedSystemTmuxPath ??
              (throw StateError('tmux is required for real-tmux E2E tests.')))
        : null;
    if (tmuxMode == RemoteOwnerTmuxMode.system) {
      await _writeExecutable(
        File(_joinPath(binDir.path, 'tmux')),
        _buildSystemTmuxWrapper(
          systemTmuxPath: resolvedSystemTmuxPath!,
          socketPath: tmuxSocketPath!,
        ),
      );
    }
    final environment = <String, String>{
      'PATH': [binDir.path, _controlledSystemPath()].join(':'),
    };

    return RemoteOwnerLoopbackHarness._(
      rootDir: rootDir,
      sessionRoot: sessionRoot,
      profile: ConnectionProfile.defaults().copyWith(
        label: 'Loopback Host',
        host: '127.0.0.1',
        username: 'loopback',
        workspaceDir: workspaceDir.path,
        codexPath: fakeCodexPath,
        connectionMode: ConnectionMode.remote,
      ),
      environment: environment,
      tmuxMode: tmuxMode,
      systemTmuxPath: resolvedSystemTmuxPath,
      logFile: logFile,
      tmuxSocketPath: tmuxSocketPath,
    );
  }

  String createOwnerId(String label) {
    final sanitizedLabel = label
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final rootSuffix = rootDir.uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .last
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    final ownerId = '$sanitizedLabel-$rootSuffix-${_ownerCounter++}';
    _ownerIds.add(ownerId);
    return ownerId;
  }

  Future<String> readLog() async {
    if (!await logFile.exists()) {
      return '';
    }
    return logFile.readAsString();
  }

  Future<String> debugTmuxState() async {
    if (tmuxMode != RemoteOwnerTmuxMode.system ||
        systemTmuxPath == null ||
        tmuxSocketPath == null) {
      return '';
    }

    final sessions = await Process.run(systemTmuxPath!, <String>[
      '-S',
      tmuxSocketPath!,
      'list-sessions',
    ]);
    final panes = await Process.run(systemTmuxPath!, <String>[
      '-S',
      tmuxSocketPath!,
      'list-panes',
      '-a',
      '-F',
      '#S pid=#{pane_pid} cmd=#{pane_current_command} path=#{pane_current_path}',
    ]);
    return [
      'tmux list-sessions:',
      (sessions.stdout as String).trim(),
      (sessions.stderr as String).trim(),
      'tmux list-panes:',
      (panes.stdout as String).trim(),
      (panes.stderr as String).trim(),
    ].where((entry) => entry.isNotEmpty).join('\n');
  }

  CodexSshRemoteAppServerOwnerControl createOwnerControl() {
    final usesRealTmux = tmuxMode == RemoteOwnerTmuxMode.system;
    return CodexSshRemoteAppServerOwnerControl(
      sshBootstrap: sshBootstrap,
      readyPollAttempts: usesRealTmux ? 100 : 30,
      readyPollDelay: Duration(milliseconds: usesRealTmux ? 100 : 50),
      stopPollAttempts: usesRealTmux ? 40 : 20,
      stopPollDelay: Duration(milliseconds: usesRealTmux ? 100 : 50),
    );
  }

  CodexAppServerClient createClient({required String ownerId}) {
    return CodexAppServerClient(
      transportOpener: buildConnectionScopedCodexAppServerTransportOpener(
        ownerId: ownerId,
        remoteOwnerInspector: CodexSshRemoteAppServerOwnerInspector(
          sshBootstrap: sshBootstrap,
        ),
        remoteTransportOpener:
            ({
              required profile,
              required secrets,
              required remoteHost,
              required remotePort,
              required emitEvent,
            }) {
              return openSshForwardedCodexAppServerWebSocketTransport(
                profile: profile,
                secrets: secrets,
                remoteHost: remoteHost,
                remotePort: remotePort,
                emitEvent: emitEvent,
                sshBootstrap: sshBootstrap,
                connectTimeout: const Duration(seconds: 5),
              );
            },
      ),
    );
  }

  CodexSshProcessBootstrap get sshBootstrap =>
      ({required profile, required secrets, required verifyHostKey}) async =>
          _LoopbackSshBootstrapClient(
            environment: environment,
            workingDirectory: rootDir.path,
          );

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    if (tmuxMode == RemoteOwnerTmuxMode.system &&
        systemTmuxPath != null &&
        tmuxSocketPath != null) {
      await Process.run(systemTmuxPath!, <String>[
        '-S',
        tmuxSocketPath!,
        'kill-server',
      ]);
    }

    if (await sessionRoot.exists()) {
      await for (final entity in sessionRoot.list()) {
        if (entity is! Directory) {
          continue;
        }
        final pidFile = File(_joinPath(entity.path, 'pid'));
        if (!await pidFile.exists()) {
          continue;
        }
        final pid = int.tryParse((await pidFile.readAsString()).trim());
        if (pid == null) {
          continue;
        }
        Process.killPid(pid, ProcessSignal.sigterm);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        Process.killPid(pid, ProcessSignal.sigkill);
      }
    }

    if (await rootDir.exists()) {
      await rootDir.delete(recursive: true);
    }
  }
}

final class _LoopbackSshBootstrapClient implements CodexSshBootstrapClient {
  _LoopbackSshBootstrapClient({
    required this.environment,
    required this.workingDirectory,
  });

  final Map<String, String> environment;
  final String workingDirectory;

  @override
  Future<void> authenticate() async {}

  @override
  Future<CodexAppServerProcess> launchProcess(String command) async {
    final process = await Process.start(
      '/bin/bash',
      <String>['-c', command],
      workingDirectory: workingDirectory,
      environment: environment,
    );
    return _LoopbackCodexAppServerProcess(process);
  }

  @override
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) async {
    final socket = await Socket.connect(remoteHost, remotePort);
    return _LoopbackSshForwardChannel(socket);
  }

  @override
  void close() {}
}

final class _LoopbackSshForwardChannel implements CodexSshForwardChannel {
  _LoopbackSshForwardChannel(this._socket);

  final Socket _socket;

  @override
  Stream<Uint8List> get stream => _socket;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() {
    _socket.destroy();
  }
}

final class _LoopbackCodexAppServerProcess implements CodexAppServerProcess {
  _LoopbackCodexAppServerProcess(this._process) {
    _process.exitCode.then((code) {
      _exitCode = code;
    });
    _stdinController.stream.listen(
      _process.stdin.add,
      onDone: () {
        unawaited(_process.stdin.close());
      },
    );
  }

  final Process _process;
  final StreamController<Uint8List> _stdinController =
      StreamController<Uint8List>();
  int? _exitCode;

  @override
  Stream<Uint8List> get stdout => _process.stdout.map(
    (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
  );

  @override
  Stream<Uint8List> get stderr => _process.stderr.map(
    (chunk) => chunk is Uint8List ? chunk : Uint8List.fromList(chunk),
  );

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => _process.exitCode.then((_) {});

  @override
  int? get exitCode => _exitCode;

  @override
  Future<void> close() async {
    await _stdinController.close();
    _process.kill();
    try {
      await _process.exitCode;
    } catch (_) {
      // Ignore teardown races.
    }
  }
}

Future<void> _writeExecutable(File file, String contents) async {
  await file.writeAsString(contents);
  final result = await Process.run('/bin/chmod', <String>['+x', file.path]);
  if (result.exitCode != 0) {
    throw StateError(
      'Failed to mark ${file.path} executable: ${result.stderr}',
    );
  }
}

Future<String> _resolveDartExecutable() async {
  final result = await Process.run('/bin/bash', <String>[
    '-lc',
    'command -v dart',
  ]);
  final path = (result.stdout as String).trim();
  if (result.exitCode != 0 || path.isEmpty) {
    throw StateError('Unable to resolve a dart executable for loopback tests.');
  }
  return path;
}

String? _resolveSystemTmuxPathSync() {
  final result = Process.runSync('/bin/bash', <String>[
    '-lc',
    'command -v tmux',
  ]);
  final path = (result.stdout as String?)?.trim() ?? '';
  if (result.exitCode != 0 || path.isEmpty) {
    return null;
  }
  return path;
}

String _controlledSystemPath() {
  return '/usr/bin:/bin:/usr/sbin:/sbin';
}

String _joinPath(String parent, String child) {
  return '$parent${Platform.pathSeparator}$child';
}

String _buildFakeCodexShim({
  required String dartExecutable,
  required String serverScriptPath,
  required String logFilePath,
}) {
  final escapedDartExecutable = _shellEscape(dartExecutable);
  final escapedServerScriptPath = _shellEscape(serverScriptPath);
  final escapedLogFilePath = _shellEscape(logFilePath);
  return '''
#!/bin/bash
set -euo pipefail

if [ "\${1-}" = "app-server" ] && [ "\${2-}" = "--help" ]; then
  echo 'usage: codex app-server --listen <uri>'
  exit 0
fi

log_file=$escapedLogFilePath
printf 'fake codex invoked: %s\n' "\$*" >> "\${log_file}"

if [ "\${1-}" != "app-server" ] || [ "\${2-}" != "--listen" ] || [ -z "\${3-}" ]; then
  echo "Unsupported fake codex invocation: \$*" >&2
  printf 'fake codex unsupported invocation\n' >> "\${log_file}"
  exit 64
fi

listen_uri="\$3"
child_pid=

cleanup() {
  if [ -n "\${child_pid}" ] && kill -0 "\${child_pid}" 2>/dev/null; then
    kill "\${child_pid}" 2>/dev/null || true
    wait "\${child_pid}" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

$escapedDartExecutable $escapedServerScriptPath "\${listen_uri}" "\${log_file}" >> "\${log_file}" 2>&1 &
child_pid=\$!
if wait "\${child_pid}"; then
  child_exit=0
else
  child_exit=\$?
fi
printf 'fake codex child exit=%s\n' "\${child_exit}" >> "\${log_file}"
exit "\${child_exit}"
''';
}

String _buildTmuxShim(String sessionRootPath) {
  final escapedSessionRoot = _shellEscape(sessionRootPath);
  return '''
#!/bin/bash
set -euo pipefail

session_root=$escapedSessionRoot
mkdir -p "\${session_root}"

session_dir() {
  local session_name="\$1"
  local safe_name
  safe_name=\$(printf '%s' "\${session_name}" | tr '/:' '__')
  printf '%s/%s' "\${session_root}" "\${safe_name}"
}

session_dir_for_pane() {
  local pane_id="\$1"
  local target_dir
  for target_dir in "\${session_root}"/*; do
    [ -d "\${target_dir}" ] || continue
    if [ -f "\${target_dir}/pane_id" ] && [ "\$(cat "\${target_dir}/pane_id")" = "\${pane_id}" ]; then
      printf '%s' "\${target_dir}"
      return 0
    fi
  done
  return 1
}

command_name="\${1-}"
shift || true

case "\${command_name}" in
  has-session)
    session_name=
    while [ \$# -gt 0 ]; do
      case "\$1" in
        -t)
          session_name="\$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    [ -n "\${session_name}" ] || exit 1
    [ -d "\$(session_dir "\${session_name}")" ]
    ;;
  new-session)
    session_name=
    workspace_dir=
    print_pane_id=0
    pane_format=
    while [ \$# -gt 0 ]; do
      case "\$1" in
        -d)
          shift
          ;;
        -P)
          print_pane_id=1
          shift
          ;;
        -F)
          pane_format="\$2"
          shift 2
          ;;
        -s)
          session_name="\$2"
          shift 2
          ;;
        -c)
          workspace_dir="\$2"
          shift 2
          ;;
        *)
          break
          ;;
      esac
    done
    launch_command="\${1-}"
    [ -n "\${session_name}" ] || exit 64
    [ -n "\${workspace_dir}" ] || exit 64

    target_dir="\$(session_dir "\${session_name}")"
    if [ -d "\${target_dir}" ]; then
      exit 1
    fi
    mkdir -p "\${target_dir}"

    printf '%s' "\${workspace_dir}" > "\${target_dir}/cwd"
    pane_id="%\$(printf '%s' "\${session_name}" | tr '/:' '__')"
    printf '%s' "\${pane_id}" > "\${target_dir}/pane_id"
    if [ -n "\${launch_command}" ]; then
      printf '%s' "\${launch_command}" > "\${target_dir}/command"
      (
        cd "\${workspace_dir}" || exit 1
        exec /bin/bash -lc "\${launch_command}"
      ) >"\${target_dir}/stdout.log" 2>"\${target_dir}/stderr.log" < /dev/null &
      pane_pid=\$!
      printf '%s' "\${pane_pid}" > "\${target_dir}/pid"
    fi

    if [ "\${print_pane_id}" = "1" ]; then
      if [ "\${pane_format}" = '#{pane_id}' ] || [ -z "\${pane_format}" ]; then
        printf '%s\n' "\${pane_id}"
      else
        exit 64
      fi
    fi
    ;;
  respawn-pane)
    pane_target=
    while [ \$# -gt 0 ]; do
      case "\$1" in
        -k)
          shift
          ;;
        -t)
          pane_target="\$2"
          shift 2
          ;;
        *)
          break
          ;;
      esac
    done
    launch_command="\${1-}"
    [ -n "\${pane_target}" ] || exit 64
    [ -n "\${launch_command}" ] || exit 64

    target_dir="\$(session_dir_for_pane "\${pane_target}")" || exit 1
    workspace_dir="\$(cat "\${target_dir}/cwd")"
    if [ -f "\${target_dir}/pid" ]; then
      pane_pid=\$(cat "\${target_dir}/pid")
      kill "\${pane_pid}" 2>/dev/null || true
    fi
    printf '%s' "\${launch_command}" > "\${target_dir}/command"
    (
      cd "\${workspace_dir}" || exit 1
      exec /bin/bash -lc "\${launch_command}"
    ) >"\${target_dir}/stdout.log" 2>"\${target_dir}/stderr.log" < /dev/null &
    pane_pid=\$!
    printf '%s' "\${pane_pid}" > "\${target_dir}/pid"
    ;;
  list-panes)
    session_name=
    while [ \$# -gt 0 ]; do
      case "\$1" in
        -t)
          session_name="\$2"
          shift 2
          ;;
        -F)
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    target_dir="\$(session_dir "\${session_name}")"
    [ -d "\${target_dir}" ] || exit 1
    cat "\${target_dir}/pid"
    ;;
  display-message)
    session_name=
    while [ \$# -gt 0 ]; do
      case "\$1" in
        -p)
          shift
          ;;
        -t)
          session_name="\$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    target_dir="\$(session_dir "\${session_name}")"
    [ -d "\${target_dir}" ] || exit 1
    cat "\${target_dir}/cwd"
    ;;
  kill-session)
    session_name=
    while [ \$# -gt 0 ]; do
      case "\$1" in
        -t)
          session_name="\$2"
          shift 2
          ;;
        *)
          shift
          ;;
      esac
    done
    target_dir="\$(session_dir "\${session_name}")"
    if [ -d "\${target_dir}" ]; then
      if [ -f "\${target_dir}/pid" ]; then
        pane_pid=\$(cat "\${target_dir}/pid")
        kill "\${pane_pid}" 2>/dev/null || true
      fi
      rm -rf "\${target_dir}"
    fi
    ;;
  *)
    echo "Unsupported tmux shim command: \${command_name}" >&2
    exit 64
    ;;
esac
''';
}

String _buildSystemTmuxWrapper({
  required String systemTmuxPath,
  required String socketPath,
}) {
  final escapedSystemTmuxPath = _shellEscape(systemTmuxPath);
  final escapedSocketPath = _shellEscape(socketPath);
  return '''
#!/bin/bash
set -euo pipefail

exec $escapedSystemTmuxPath -S $escapedSocketPath "\$@"
''';
}

String _shellEscape(String value) {
  return "'${value.replaceAll("'", r"'\''")}'";
}

const String _bashWrapperScript = '''
#!/bin/bash
set -euo pipefail

if [ "\${1-}" = "-lc" ] && [ -n "\${2-}" ]; then
  script="\$2"
  shift 2
  exec /bin/bash --noprofile --norc -c "\${script}" "\$@"
fi

exec /bin/bash "\$@"
''';

const String _fakeCodexServerSource = '''
import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final logPath = args.length > 1
      ? args[1]
      : Platform.environment['POCKET_RELAY_FAKE_CODEX_LOG'];
  Future<void> appendLog(String message) async {
    if (logPath == null || logPath.isEmpty) {
      return;
    }
    await File(logPath).writeAsString('\$message\\n', mode: FileMode.append);
  }

  if (args.isEmpty) {
    stderr.writeln('listen uri required');
    await appendLog('fake server missing listen uri');
    exitCode = 64;
    return;
  }

  final listenUri = Uri.parse(args.first);
  await appendLog('fake server starting on port \${listenUri.port}');
  late final HttpServer server;
  try {
    server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      listenUri.port,
    );
  } catch (error) {
    await appendLog('fake server bind failed: \$error');
    rethrow;
  }

  Future<void> shutdown() async {
    await appendLog('fake server shutting down');
    await server.close(force: true);
    exit(0);
  }

  ProcessSignal.sigint.watch().listen((_) {
    unawaited(shutdown());
  });
  ProcessSignal.sigterm.watch().listen((_) {
    unawaited(shutdown());
  });

  final threads = <String, Map<String, Object?>>{};
  var nextThreadNumber = 1;

  await for (final request in server) {
    if (request.uri.path == '/readyz') {
      await appendLog('fake server readyz');
      request.response.statusCode = HttpStatus.ok;
      request.response.headers.contentType = ContentType.text;
      request.response.write('ok');
      await request.response.close();
      continue;
    }

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      await appendLog('fake server websocket upgrade');
      final socket = await WebSocketTransformer.upgrade(request);
      unawaited(
        _handleSocket(
          socket,
          threads: threads,
          nextThreadNumber: () => nextThreadNumber++,
        ),
      );
      continue;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }
}

Future<void> _handleSocket(
  WebSocket socket, {
  required Map<String, Map<String, Object?>> threads,
  required int Function() nextThreadNumber,
}) async {
  await for (final message in socket) {
    if (message is! String) {
      continue;
    }

    final payload = jsonDecode(message) as Map<String, dynamic>;
    final method = payload['method'] as String?;
    final id = payload['id'];

    if (method == 'initialize') {
      socket.add(
        jsonEncode(<String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'userAgent': 'pocket-relay-loopback-codex',
          },
        }),
      );
      continue;
    }

    if (method == 'thread/start') {
      final threadId = 'thread_\${nextThreadNumber()}';
      final thread = <String, Object?>{
        'id': threadId,
        'cwd': Directory.current.path,
      };
      threads[threadId] = thread;
      socket.add(
        jsonEncode(<String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'thread': thread,
            'cwd': Directory.current.path,
            'model': 'gpt-5.3-codex',
            'modelProvider': 'openai',
            'approvalPolicy': 'on-request',
            'sandbox': <String, Object?>{'type': 'workspace-write'},
          },
        }),
      );
      continue;
    }

    if (method == 'thread/resume') {
      final params = payload['params'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final threadId = params['threadId'] as String? ?? '';
      final thread =
          threads[threadId] ??
          <String, Object?>{
            'id': threadId,
            'cwd': Directory.current.path,
          };
      threads[threadId] = thread;
      socket.add(
        jsonEncode(<String, Object?>{
          'id': id,
          'result': <String, Object?>{
            'thread': thread,
            'cwd': Directory.current.path,
            'model': 'gpt-5.3-codex',
            'modelProvider': 'openai',
            'approvalPolicy': 'on-request',
            'sandbox': <String, Object?>{'type': 'workspace-write'},
          },
        }),
      );
      continue;
    }

    if (id != null) {
      socket.add(
        jsonEncode(<String, Object?>{
          'id': id,
          'result': <String, Object?>{},
        }),
      );
    }
  }
}
''';
