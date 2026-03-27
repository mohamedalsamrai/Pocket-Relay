import 'client_test_support.dart';

void main() {
  test(
    'readThreadWithTurns preserves historical turns from thread/read',
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
            case 'thread/read':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{
                    'id': 'thread_saved',
                    'turns': <Object>[
                      <String, Object?>{
                        'id': 'turn_saved',
                        'status': 'completed',
                        'items': <Object>[
                          <String, Object?>{
                            'id': 'item_user',
                            'type': 'userMessage',
                            'status': 'completed',
                            'content': <Object>[
                              <String, Object?>{'text': 'Restore this'},
                            ],
                          },
                        ],
                      },
                    ],
                  },
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

      final thread = await client.readThreadWithTurns(threadId: 'thread_saved');

      expect(thread.id, 'thread_saved');
      expect(thread.turns, hasLength(1));
      expect(thread.turns.single.id, 'turn_saved');
      expect(thread.promptCount, 1);

      await client.disconnect();
    },
  );

  test(
    'readThreadWithTurns preserves historical turns from flat thread/read responses',
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
            case 'thread/read':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'threadId': 'thread_saved',
                  'turns': <Object>[
                    <String, Object?>{
                      'id': 'turn_saved',
                      'status': 'completed',
                      'items': <Object>[
                        <String, Object?>{
                          'id': 'item_user',
                          'type': 'userMessage',
                          'status': 'completed',
                          'content': <Object>[
                            <String, Object?>{
                              'type': 'text',
                              'text': 'Restore this',
                            },
                          ],
                        },
                      ],
                    },
                  ],
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

      final thread = await client.readThreadWithTurns(threadId: 'thread_saved');

      expect(thread.id, 'thread_saved');
      expect(thread.turns, hasLength(1));
      expect(thread.turns.single.id, 'turn_saved');
      expect(thread.promptCount, 1);

      await client.disconnect();
    },
  );

  test(
    'rollbackThread sends thread/rollback and preserves returned historical turns',
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
            case 'thread/rollback':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{
                    'id': 'thread_saved',
                    'turns': <Object>[
                      <String, Object?>{
                        'id': 'turn_saved',
                        'status': 'completed',
                        'items': <Object>[
                          <String, Object?>{
                            'id': 'item_user',
                            'type': 'userMessage',
                            'status': 'completed',
                            'content': <Object>[
                              <String, Object?>{
                                'type': 'text',
                                'text': 'Restore this',
                              },
                            ],
                          },
                        ],
                      },
                    ],
                  },
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

      final thread = await client.rollbackThread(
        threadId: 'thread_saved',
        numTurns: 2,
      );

      expect(thread.id, 'thread_saved');
      expect(thread.turns, hasLength(1));
      expect(thread.turns.single.id, 'turn_saved');
      expect(thread.promptCount, 1);

      final rollbackRequest = process.writtenMessages.firstWhere(
        (message) => message['method'] == 'thread/rollback',
      );
      expect(rollbackRequest['params'], <String, Object?>{
        'threadId': 'thread_saved',
        'numTurns': 2,
      });

      await client.disconnect();
    },
  );

  test(
    'rollbackThread rejects invalid turn counts before sending a request',
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

      await expectLater(
        client.rollbackThread(threadId: 'thread_saved', numTurns: 0),
        throwsA(
          isA<CodexAppServerException>().having(
            (error) => error.message,
            'message',
            'numTurns must be >= 1.',
          ),
        ),
      );
      expect(
        process.writtenMessages.where(
          (message) => message['method'] == 'thread/rollback',
        ),
        isEmpty,
      );

      await client.disconnect();
    },
  );

  test(
    'forkThread sends thread/fork and tracks the forked thread returned by the app server',
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
            case 'thread/fork':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{
                    'id': 'thread_forked',
                    'path': '/workspace/.codex/threads/thread_forked.jsonl',
                    'cwd': '/workspace',
                    'source': 'app-server',
                  },
                  'cwd': '/workspace',
                  'model': 'gpt-5.4',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'on-request',
                  'sandbox': <String, Object?>{'type': 'workspace-write'},
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

      final session = await client.forkThread(
        threadId: 'thread_saved',
        path: '/workspace/.codex/threads/thread_saved.jsonl',
        cwd: '/workspace',
        model: 'gpt-5.4',
        modelProvider: 'openai',
        persistExtendedHistory: true,
      );

      expect(session.threadId, 'thread_forked');
      expect(session.thread?.id, 'thread_forked');
      expect(
        session.thread?.path,
        '/workspace/.codex/threads/thread_forked.jsonl',
      );
      expect(client.threadId, 'thread_forked');

      final forkRequest = process.writtenMessages.firstWhere(
        (message) => message['method'] == 'thread/fork',
      );
      expect(forkRequest['params'], <String, Object?>{
        'threadId': 'thread_saved',
        'path': '/workspace/.codex/threads/thread_saved.jsonl',
        'cwd': '/workspace',
        'model': 'gpt-5.4',
        'modelProvider': 'openai',
        'approvalPolicy': 'on-request',
        'sandbox': 'workspace-write',
        'ephemeral': false,
        'persistExtendedHistory': true,
      });

      await client.disconnect();
    },
  );

  test(
    'forkThread rejects empty thread ids before sending a request',
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

      await expectLater(
        client.forkThread(threadId: '   '),
        throwsA(
          isA<CodexAppServerException>().having(
            (error) => error.message,
            'message',
            'Thread id cannot be empty.',
          ),
        ),
      );
      expect(
        process.writtenMessages.where(
          (message) => message['method'] == 'thread/fork',
        ),
        isEmpty,
      );

      await client.disconnect();
    },
  );

  test(
    'resumeThread exposes thread/resume as a first-class client request',
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
            case 'thread/resume':
              process.sendStdout(<String, Object?>{
                'id': message['id'],
                'result': <String, Object?>{
                  'thread': <String, Object?>{'id': 'thread_old'},
                  'cwd': '/workspace/subdir',
                  'model': 'gpt-5.3-codex',
                  'modelProvider': 'openai',
                  'approvalPolicy': 'on-request',
                  'sandbox': <String, Object?>{'type': 'workspace-write'},
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

      final session = await client.resumeThread(
        threadId: 'thread_old',
        cwd: '/workspace/subdir',
      );

      expect(session.threadId, 'thread_old');
      final resumeRequest = process.writtenMessages.firstWhere(
        (message) => message['method'] == 'thread/resume',
      );
      expect(resumeRequest['params'], <String, Object?>{
        'cwd': '/workspace/subdir',
        'approvalPolicy': 'on-request',
        'sandbox': 'workspace-write',
        'threadId': 'thread_old',
      });

      await client.disconnect();
    },
  );
}
