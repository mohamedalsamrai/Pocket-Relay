import 'client_test_support.dart';

void main() {
  test(
    'session exit notifications clear tracked thread and turn ids',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
        onClientMessage: (message) {
          switch (message['method']) {
            case 'initialize':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'userAgent': 'codex-app-server-test',
                },
              });
            case 'thread/start':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{'id': 'thread_123'},
                  'cwd': '/workspace',
                  'model': 'gpt-5.3-codex',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'on-request',
                  'sandbox': <String, Object?>{'type': 'workspace-write'},
                },
              });
            case 'turn/start':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'turn': <String, Object?>{'id': 'turn_123'},
                },
              });
          }
        },
      );

      final client = CodexAppServerClient(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async =>
                process,
      );

      await client.connect(
        profile: clientProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      final session = await client.startSession();
      await client.sendUserMessage(
        threadId: session.threadId,
        text: 'hello from phone',
      );

      expect(client.threadId, 'thread_123');
      expect(client.activeTurnId, 'turn_123');

      process.sendStdout(<String, Object?>{
        'method': 'session/exited',
        'params': <String, Object?>{'exitCode': 0},
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.threadId, isNull);
      expect(client.activeTurnId, isNull);

      await client.disconnect();
    },
  );

  test('starting a new session clears the active turn pointer', () async {
    late FakeCodexAppServerProcess process;
    process = FakeCodexAppServerProcess(
      onClientMessage: (message) {
        switch (message['method']) {
          case 'initialize':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
            });
          case 'thread/start':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{
                'thread': <String, Object?>{'id': 'thread_123'},
                'cwd': '/workspace',
                'model': 'gpt-5.3-codex',
                'modelProvider': 'openai',
                'approvalPolicy': 'on-request',
                'sandbox': <String, Object?>{'type': 'workspace-write'},
              },
            });
          case 'thread/resume':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{
                'thread': <String, Object?>{'id': 'thread_456'},
                'cwd': '/workspace',
                'model': 'gpt-5.3-codex',
                'modelProvider': 'openai',
                'approvalPolicy': 'on-request',
                'sandbox': <String, Object?>{'type': 'workspace-write'},
              },
            });
          case 'turn/start':
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{
                'turn': <String, Object?>{'id': 'turn_123'},
              },
            });
        }
      },
    );

    final client = CodexAppServerClient(
      processLauncher:
          ({required profile, required secrets, required emitEvent}) async =>
              process,
    );

    await client.connect(
      profile: clientProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    final session = await client.startSession();
    await client.sendUserMessage(threadId: session.threadId, text: 'hello');
    expect(client.activeTurnId, 'turn_123');

    final resumed = await client.startSession(resumeThreadId: 'thread_456');

    expect(resumed.threadId, 'thread_456');
    expect(client.threadId, 'thread_456');
    expect(client.activeTurnId, isNull);

    await client.disconnect();
  });

  test(
    'notification pointer updates ignore stale turn completions and clear closed threads',
    () async {
      late FakeCodexAppServerProcess process;
      process = FakeCodexAppServerProcess(
        onClientMessage: (message) {
          if (message['method'] == 'initialize') {
            process.sendStdout(<String, Object?>{
              'id': message['id'],
              'result': <String, Object?>{'userAgent': 'codex-app-server-test'},
            });
          }
        },
      );

      final client = CodexAppServerClient(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async =>
                process,
      );

      await client.connect(
        profile: clientProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      process.sendStdout(<String, Object?>{
        'method': 'thread/started',
        'params': <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_123'},
        },
      });
      process.sendStdout(<String, Object?>{
        'method': 'turn/started',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{'id': 'turn_old'},
        },
      });
      process.sendStdout(<String, Object?>{
        'method': 'turn/started',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{'id': 'turn_new'},
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.threadId, 'thread_123');
      expect(client.activeTurnId, 'turn_new');

      process.sendStdout(<String, Object?>{
        'method': 'turn/completed',
        'params': <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{'id': 'turn_old'},
        },
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.activeTurnId, 'turn_new');

      process.sendStdout(<String, Object?>{
        'method': 'thread/closed',
        'params': <String, Object?>{'threadId': 'thread_123'},
      });
      await Future<void>.delayed(Duration.zero);

      expect(client.threadId, isNull);
      expect(client.activeTurnId, isNull);

      await client.disconnect();
    },
  );
}
