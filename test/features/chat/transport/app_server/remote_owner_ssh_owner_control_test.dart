import 'remote_owner_ssh_test_support.dart';

void main() {
  test('inspectOwner appends captured launch output when provided', () async {
    final encodedLog = base64.encode(utf8.encode('codex: command not found\n'));
    final process = FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing log_b64=$encodedLog',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
    expect(
      snapshot.detail,
      contains('Underlying error: codex: command not found'),
    );
  });

  test('inspectOwner reports missing when no managed session exists', () async {
    final process = FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
    expect(snapshot.sessionName, 'pocket-relay-remote-1');
    expect(
      snapshot.detail,
      contains('No managed remote app-server is running'),
    );
    expect(snapshot.isConnectable, isFalse);
  });

  test(
    'inspectOwner reports stopped when websocket launch metadata is missing',
    () async {
      final process = FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_owner__ status=stopped pid=2041 host= port= detail=listen_url_missing',
        ],
      );
      final inspector = CodexSshRemoteAppServerOwnerInspector(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return FakeSshBootstrapClient(process: process);
            },
      );

      final snapshot = await inspector.inspectOwner(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.stopped);
      expect(snapshot.pid, 2041);
      expect(snapshot.detail, contains('not running a websocket app-server'));
    },
  );

  test(
    'inspectOwner appends explicit app-server exit status from the launch log',
    () async {
      final encodedLog = base64.encode(
        utf8.encode('pocket-relay: codex app-server exited with status 23\n'),
      );
      final process = FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_owner__ status=stopped pid=2041 host= port= detail=process_missing log_b64=$encodedLog',
        ],
      );
      final inspector = CodexSshRemoteAppServerOwnerInspector(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return FakeSshBootstrapClient(process: process);
            },
      );

      final snapshot = await inspector.inspectOwner(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.stopped);
      expect(snapshot.detail, contains('Underlying error:'));
      expect(
        snapshot.detail,
        contains('codex app-server exited with status 23'),
      );
    },
  );

  test('inspectOwner reports unhealthy when readyz fails', () async {
    final process = FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=unhealthy pid=2041 host=127.0.0.1 port=4100 detail=ready_check_failed',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.unhealthy);
    expect(snapshot.endpoint, isNotNull);
    expect(snapshot.endpoint!.port, 4100);
    expect(snapshot.detail, contains('did not pass its readiness check'));
  });

  test(
    'inspectOwner reports unhealthy when the configured workspace is inaccessible',
    () async {
      final process = FakeCodexAppServerProcess(
        stdoutLines: <String>[
          '__pocket_relay_owner__ status=unhealthy pid=2041 host= port= detail=expected_workspace_unavailable',
        ],
      );
      final inspector = CodexSshRemoteAppServerOwnerInspector(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return FakeSshBootstrapClient(process: process);
            },
      );

      final snapshot = await inspector.inspectOwner(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.unhealthy);
      expect(
        snapshot.detail,
        contains('configured workspace directory is not accessible'),
      );
    },
  );

  test('inspectOwner reports running when readyz succeeds', () async {
    final process = FakeCodexAppServerProcess(
      stdoutLines: <String>[
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=4100 detail=ready',
      ],
    );
    final inspector = CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return FakeSshBootstrapClient(process: process);
          },
    );

    final snapshot = await inspector.inspectOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    expect(snapshot.endpoint, isNotNull);
    expect(snapshot.endpoint!.host, '127.0.0.1');
    expect(snapshot.endpoint!.port, 4100);
    expect(snapshot.isConnectable, isTrue);
  });

  test('startOwner creates a new tmux-managed server when missing', () async {
    final inspectOutputs = <FakeCodexAppServerProcess>[
      ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      ownerProcess(
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
      ),
    ];
    final launchedCommands = <String>[];
    final control = CodexSshRemoteAppServerOwnerControl(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                launchedCommands.add(command);
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.startOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    expect(snapshot.endpoint?.port, 45123);
    expect(
      launchedCommands.any((command) => command.contains('tmux new-session')),
      isTrue,
    );
  });

  test('startOwner waits through delayed readyz before reporting running', () async {
    final inspectOutputs = <FakeCodexAppServerProcess>[
      ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      for (var index = 0; index < 24; index += 1)
        ownerProcess(
          '__pocket_relay_owner__ status=unhealthy pid=2041 host=127.0.0.1 port=45123 detail=ready_check_failed',
        ),
      ownerProcess(
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
      ),
    ];
    final control = CodexSshRemoteAppServerOwnerControl(
      readyPollDelay: Duration.zero,
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.startOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    expect(snapshot.endpoint?.port, 45123);
  });

  test(
    'startOwner returns the existing running owner without relaunch',
    () async {
      final launchedCommands = <String>[];
      final control = CodexSshRemoteAppServerOwnerControl(
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return ScriptedSshBootstrapClient(
                onLaunch: (command) async {
                  launchedCommands.add(command);
                  return ownerProcess(
                    '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=4100 detail=ready',
                  );
                },
              );
            },
      );

      final snapshot = await control.startOwner(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
      expect(
        launchedCommands.any((command) => command.contains('tmux new-session')),
        isFalse,
      );
    },
  );

  test('stopOwner kills the tmux owner and returns the missing state', () async {
    final inspectOutputs = <FakeCodexAppServerProcess>[
      ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
    ];
    final launchedCommands = <String>[];
    final control = CodexSshRemoteAppServerOwnerControl(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                launchedCommands.add(command);
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.stopOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
    expect(
      launchedCommands.any((command) => command.contains('tmux kill-session')),
      isTrue,
    );
  });

  test(
    'stopOwner waits through delayed owner shutdown before reporting missing',
    () async {
      final inspectOutputs = <FakeCodexAppServerProcess>[
        for (var index = 0; index < 4; index += 1)
          ownerProcess(
            '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
          ),
        ownerProcess(
          '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
        ),
      ];
      final launchedCommands = <String>[];
      final control = CodexSshRemoteAppServerOwnerControl(
        stopPollDelay: Duration.zero,
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return ScriptedSshBootstrapClient(
                onLaunch: (command) async {
                  launchedCommands.add(command);
                  if (command.contains('__pocket_relay_owner__')) {
                    return inspectOutputs.removeAt(0);
                  }
                  return FakeCodexAppServerProcess();
                },
              );
            },
      );

      final snapshot = await control.stopOwner(
        profile: sshProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        ownerId: 'remote-1',
        workspaceDir: '/workspace',
      );

      expect(snapshot.status, CodexRemoteAppServerOwnerStatus.missing);
      expect(
        launchedCommands
            .where((command) => command.contains('__pocket_relay_owner__'))
            .length,
        5,
      );
    },
  );

  test('restartOwner is explicit stop plus start', () async {
    final inspectOutputs = <FakeCodexAppServerProcess>[
      ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      ownerProcess(
        '__pocket_relay_owner__ status=missing pid= host= port= detail=session_missing',
      ),
      ownerProcess(
        '__pocket_relay_owner__ status=running pid=2041 host=127.0.0.1 port=45123 detail=ready',
      ),
    ];
    final launchedCommands = <String>[];
    final control = CodexSshRemoteAppServerOwnerControl(
      sshBootstrap:
          ({required profile, required secrets, required verifyHostKey}) async {
            return ScriptedSshBootstrapClient(
              onLaunch: (command) async {
                launchedCommands.add(command);
                if (command.contains('__pocket_relay_owner__')) {
                  return inspectOutputs.removeAt(0);
                }
                return FakeCodexAppServerProcess();
              },
            );
          },
    );

    final snapshot = await control.restartOwner(
      profile: sshProfile(),
      secrets: const ConnectionSecrets(password: 'secret'),
      ownerId: 'remote-1',
      workspaceDir: '/workspace',
    );

    expect(snapshot.status, CodexRemoteAppServerOwnerStatus.running);
    final killIndex = launchedCommands.indexWhere(
      (command) => command.contains('tmux kill-session'),
    );
    final startIndex = launchedCommands.indexWhere(
      (command) => command.contains('tmux new-session'),
    );
    expect(killIndex, isNonNegative);
    expect(startIndex, greaterThan(killIndex));
  });
}
