import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_local_process.dart';

void main() {
  test('builds a direct local invocation for a plain codex binary', () {
    final invocation = buildLocalCodexAppServerInvocation(
      profile: _profile(),
      platform: TargetPlatform.macOS,
    );

    expect(invocation.executable, 'codex');
    expect(invocation.arguments, <String>[
      'app-server',
      '--listen',
      'stdio://',
    ]);
  });

  test('preserves fixed arguments in the configured agent command', () {
    final invocation = buildLocalCodexAppServerInvocation(
      profile: _profile(codexPath: '"./tools/codex wrapper" --profile turbo'),
      platform: TargetPlatform.macOS,
    );

    expect(invocation.executable, './tools/codex wrapper');
    expect(invocation.arguments, <String>[
      '--profile',
      'turbo',
      'app-server',
      '--listen',
      'stdio://',
    ]);
  });

  test('rejects shell snippets in the configured agent command', () {
    expect(
      () => buildLocalCodexAppServerInvocation(
        profile: _profile(codexPath: 'source /etc/profile && codex'),
        platform: TargetPlatform.macOS,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Shell operators'),
        ),
      ),
    );
  });

  test('emits a diagnostic event when local process startup fails', () async {
    final events = <CodexAppServerEvent>[];

    await expectLater(
      openLocalCodexAppServerProcess(
        profile: _profile(),
        secrets: const ConnectionSecrets(),
        emitEvent: events.add,
        processStarter:
            ({
              required executable,
              required arguments,
              required workingDirectory,
            }) {
              throw const ProcessException(
                'bash',
                <String>[],
                'missing shell',
                127,
              );
            },
      ),
      throwsA(isA<ProcessException>()),
    );

    expect(events.single, isA<CodexAppServerDiagnosticEvent>());
    final diagnostic = events.single as CodexAppServerDiagnosticEvent;
    expect(diagnostic.isError, isTrue);
    expect(
      diagnostic.message,
      contains('Failed to start local Codex app-server'),
    );
  });
}

ConnectionProfile _profile({String codexPath = 'codex'}) {
  return ConnectionProfile.defaults().copyWith(
    connectionMode: ConnectionMode.local,
    workspaceDir: '/workspace',
    codexPath: codexPath,
  );
}
