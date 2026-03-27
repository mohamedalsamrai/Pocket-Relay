import 'remote_owner_loopback_test_support.dart';

void main() {
  test(
    'loopback remote owner lifecycle supports websocket attach and session start',
    () async {
      final harness = await RemoteOwnerLoopbackHarness.create(
        tmuxMode: RemoteOwnerTmuxMode.shim,
      );
      addTearDown(harness.dispose);

      final ownerId = harness.createOwnerId('loopback-owner');
      final control = harness.createOwnerControl();

      final started = await control.startOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );

      if (!started.isConnectable) {
        final log = await harness.readLog();
        final tmuxState = await harness.debugTmuxState();
        fail(
          'Owner did not become connectable. '
          'status=${started.status} detail=${started.detail} port=${started.endpoint?.port}\n'
          '$log\n$tmuxState',
        );
      }
      expect(started.endpoint?.host, '127.0.0.1');
      expect(started.endpoint?.port, isNotNull);

      final client = CodexAppServerClient(
        transportOpener: buildConnectionScopedCodexAppServerTransportOpener(
          ownerId: ownerId,
          remoteOwnerInspector: CodexSshRemoteAppServerOwnerInspector(
            sshBootstrap: harness.sshBootstrap,
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
                  sshBootstrap: harness.sshBootstrap,
                  connectTimeout: const Duration(seconds: 5),
                );
              },
        ),
      );
      addTearDown(client.dispose);

      final events = <CodexAppServerEvent>[];
      final subscription = client.events.listen(events.add);
      addTearDown(subscription.cancel);

      await client.connect(profile: harness.profile, secrets: harness.secrets);

      final session = await client.startSession();

      expect(session.threadId, startsWith('thread_'));
      expect(
        events.whereType<CodexAppServerConnectedEvent>().single.userAgent,
        'pocket-relay-loopback-codex',
      );
      expect(
        events
            .whereType<CodexAppServerSshPortForwardStartedEvent>()
            .single
            .remotePort,
        started.endpoint!.port,
      );

      await client.dispose();

      final stopped = await control.stopOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );

      expect(stopped.status.name, anyOf('missing', 'stopped'));
    },
  );

  test(
    'real tmux E2E supports owner restart after forced disconnect',
    () async {
      final harness = await RemoteOwnerLoopbackHarness.create(
        tmuxMode: RemoteOwnerTmuxMode.system,
      );
      addTearDown(harness.dispose);

      final ownerId = harness.createOwnerId('real-tmux-restart');
      final control = harness.createOwnerControl();
      final started = await control.startOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );
      if (!started.isConnectable) {
        fail(
          'Owner did not become connectable. '
          'status=${started.status} detail=${started.detail} port=${started.endpoint?.port}',
        );
      }

      final firstClient = harness.createClient(ownerId: ownerId);
      addTearDown(firstClient.dispose);
      final disconnectedFuture = firstClient.events
          .firstWhere((event) => event is CodexAppServerDisconnectedEvent)
          .then((event) => event as CodexAppServerDisconnectedEvent)
          .timeout(const Duration(seconds: 10));

      await firstClient.connect(
        profile: harness.profile,
        secrets: harness.secrets,
      );
      await firstClient.startSession();

      await control.stopOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );
      await disconnectedFuture;

      final restarted = await control.startOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );
      expect(restarted.isConnectable, isTrue);

      final secondClient = harness.createClient(ownerId: ownerId);
      addTearDown(secondClient.dispose);
      await secondClient.connect(
        profile: harness.profile,
        secrets: harness.secrets,
      );
      final session = await secondClient.startSession();

      expect(session.threadId, startsWith('thread_'));
    },
    skip: installedSystemTmuxPath == null
        ? 'tmux is not installed on this machine.'
        : false,
  );
}
