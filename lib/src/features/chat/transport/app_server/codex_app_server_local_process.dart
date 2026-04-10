import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/trusted_agent_command.dart';

import 'codex_app_server_models.dart';

class CodexLocalProcessInvocation {
  const CodexLocalProcessInvocation({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

typedef CodexLocalProcessStarter =
    Future<Process> Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
    });

Future<CodexAppServerProcess> openLocalCodexAppServerProcess({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required void Function(CodexAppServerEvent event) emitEvent,
  @visibleForTesting
  CodexLocalProcessStarter processStarter = _startLocalProcess,
}) async {
  final invocation = buildLocalCodexAppServerInvocation(profile: profile);

  try {
    final process = await processStarter(
      executable: invocation.executable,
      arguments: invocation.arguments,
      workingDirectory: profile.workspaceDir.trim(),
    );
    return _LocalCodexAppServerProcess(process);
  } catch (error) {
    emitEvent(
      CodexAppServerDiagnosticEvent(
        message: 'Failed to start local Codex app-server: $error',
        isError: true,
      ),
    );
    rethrow;
  }
}

CodexLocalProcessInvocation buildLocalCodexAppServerInvocation({
  required ConnectionProfile profile,
  TargetPlatform? platform,
}) {
  final configuredCommand = parseTrustedAgentCommand(profile.codexPath);
  return CodexLocalProcessInvocation(
    executable: _localExecutableForCommand(
      configuredCommand.executable,
      platform: platform ?? defaultTargetPlatform,
    ),
    arguments: <String>[
      ...configuredCommand.arguments,
      'app-server',
      '--listen',
      'stdio://',
    ],
  );
}

Future<Process> _startLocalProcess({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
}) {
  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
}

String _localExecutableForCommand(
  String executable, {
  required TargetPlatform platform,
}) {
  final homeDirectory = switch (platform) {
    TargetPlatform.windows =>
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'],
    _ => Platform.environment['HOME'],
  };
  if (homeDirectory == null || homeDirectory.isEmpty) {
    return executable;
  }
  if (executable == '~') {
    return homeDirectory;
  }
  if (executable.startsWith('~/')) {
    return _joinHomePath(
      homeDirectory: homeDirectory,
      suffix: executable.substring(2),
      separator: '/',
    );
  }
  if (executable.startsWith('~\\')) {
    return _joinHomePath(
      homeDirectory: homeDirectory,
      suffix: executable.substring(2),
      separator: '\\',
    );
  }
  return executable;
}

String _joinHomePath({
  required String homeDirectory,
  required String suffix,
  required String separator,
}) {
  if (suffix.isEmpty) {
    return homeDirectory;
  }
  final needsSeparator =
      !homeDirectory.endsWith(separator) &&
      !homeDirectory.endsWith('/') &&
      !homeDirectory.endsWith('\\');
  final normalizedHome = needsSeparator
      ? '$homeDirectory$separator'
      : homeDirectory;
  return '$normalizedHome$suffix';
}

class _LocalCodexAppServerProcess implements CodexAppServerProcess {
  _LocalCodexAppServerProcess(this._process) {
    _process.exitCode.then((code) {
      _exitCode = code;
    });
    _stdinController.stream.listen(
      (data) {
        _process.stdin.add(data);
      },
      onDone: () {
        unawaited(_process.stdin.close());
      },
    );
  }

  final Process _process;
  final _stdinController = StreamController<Uint8List>();
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
      // Ignore exit errors during teardown.
    }
  }
}
