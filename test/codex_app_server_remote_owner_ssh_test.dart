import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';

void main() {
  test('builds a capability probe command for a plain codex binary', () {
    final command = buildSshRemoteHostCapabilityProbeCommand(
      profile: _profile().copyWith(codexPath: 'codex'),
    );

    expect(command, contains('command -v tmux'));
    expect(command, contains('codex app-server --help'));
    expect(command, contains('/workspace'));
  });

  test(
    'builds a capability probe command for a launch command with spaces',
    () {
      final command = buildSshRemoteHostCapabilityProbeCommand(
        profile: _profile().copyWith(codexPath: 'just codex-mcp'),
      );

      expect(command, contains('just codex-mcp app-server --help'));
    },
  );

  test(
    'probeHostCapabilities returns supported when tmux and codex are available',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>['__pocket_relay_capabilities__ tmux=0 codex=0'],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.supportsContinuity, isTrue);
      expect(capabilities.issues, isEmpty);
    },
  );

  test(
    'probeHostCapabilities reports explicit missing tmux and codex issues',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>['__pocket_relay_capabilities__ tmux=1 codex=1'],
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(capabilities.issues, <ConnectionRemoteHostCapabilityIssue>{
        ConnectionRemoteHostCapabilityIssue.tmuxMissing,
        ConnectionRemoteHostCapabilityIssue.codexMissing,
      });
    },
  );

  test(
    'probeHostCapabilities throws when the remote output is not parseable',
    () async {
      final process = _FakeCodexAppServerProcess(
        stdoutLines: <String>['unexpected output'],
        stderrLines: <String>['stderr detail'],
        exitCodeValue: 7,
      );
      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return _FakeSshBootstrapClient(process: process);
            },
      );

      await expectLater(
        probe.probeHostCapabilities(
          profile: _profile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('no parseable result'),
          ),
        ),
      );
    },
  );
}

ConnectionProfile _profile() {
  return const ConnectionProfile(
    label: 'Developer Box',
    host: 'example.com',
    port: 22,
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
    authMode: AuthMode.password,
    hostFingerprint: '',
    dangerouslyBypassSandbox: false,
    ephemeralSession: false,
  );
}

final class _FakeSshBootstrapClient implements CodexSshBootstrapClient {
  _FakeSshBootstrapClient({this.process, this.authenticateError});

  final CodexAppServerProcess? process;
  final Object? authenticateError;

  @override
  Future<void> authenticate() async {
    if (authenticateError != null) {
      throw authenticateError!;
    }
  }

  @override
  Future<CodexAppServerProcess> launchProcess(String command) async {
    return process ?? _FakeCodexAppServerProcess();
  }

  @override
  void close() {}
}

final class _FakeCodexAppServerProcess implements CodexAppServerProcess {
  _FakeCodexAppServerProcess({
    List<String> stdoutLines = const <String>[],
    List<String> stderrLines = const <String>[],
    this.exitCodeValue = 0,
  }) {
    unawaited(
      Future<void>(() async {
        for (final line in stdoutLines) {
          _stdoutController.add(Uint8List.fromList(utf8.encode('$line\n')));
        }
        for (final line in stderrLines) {
          _stderrController.add(Uint8List.fromList(utf8.encode('$line\n')));
        }
        await _stdoutController.close();
        await _stderrController.close();
        _doneCompleter.complete();
      }),
    );
  }

  final int? exitCodeValue;
  final _stdoutController = StreamController<Uint8List>();
  final _stderrController = StreamController<Uint8List>();
  final _stdinController = StreamController<Uint8List>();
  final _doneCompleter = Completer<void>();

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  int? get exitCode => exitCodeValue;

  @override
  Future<void> close() async {
    if (!_stdoutController.isClosed) {
      await _stdoutController.close();
    }
    if (!_stderrController.isClosed) {
      await _stderrController.close();
    }
    unawaited(_stdinController.close());
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}
