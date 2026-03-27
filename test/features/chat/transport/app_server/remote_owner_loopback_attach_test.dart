import 'remote_owner_loopback_test_support.dart';

void main() {
  test(
    'real tmux E2E keeps the owner running across client disconnect and reconnect',
    () async {
      final harness = await RemoteOwnerLoopbackHarness.create(
        tmuxMode: RemoteOwnerTmuxMode.system,
      );
      addTearDown(harness.dispose);

      final ownerId = harness.createOwnerId('real-tmux-reconnect');
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

      final firstClient = harness.createClient(ownerId: ownerId);
      addTearDown(firstClient.dispose);
      await firstClient.connect(
        profile: harness.profile,
        secrets: harness.secrets,
      );
      final firstSession = await firstClient.startSession();

      await firstClient.disconnect();

      final stillRunning = await control.inspectOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );
      expect(stillRunning.status.name, 'running');

      final secondClient = harness.createClient(ownerId: ownerId);
      addTearDown(secondClient.dispose);
      await secondClient.connect(
        profile: harness.profile,
        secrets: harness.secrets,
      );
      final resumed = await secondClient.resumeThread(
        threadId: firstSession.threadId,
      );

      expect(resumed.threadId, firstSession.threadId);
      expect(secondClient.threadId, firstSession.threadId);

      final stopped = await control.stopOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );
      expect(stopped.status.name, anyOf('missing', 'stopped'));
    },
    skip: installedSystemTmuxPath == null
        ? 'tmux is not installed on this machine.'
        : false,
  );

  test(
    'real tmux E2E emits disconnected when the owner stops during an active session',
    () async {
      final harness = await RemoteOwnerLoopbackHarness.create(
        tmuxMode: RemoteOwnerTmuxMode.system,
      );
      addTearDown(harness.dispose);

      final ownerId = harness.createOwnerId('real-tmux-disconnect');
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

      final client = harness.createClient(ownerId: ownerId);
      addTearDown(client.dispose);
      final disconnectedFuture = client.events
          .firstWhere((event) => event is CodexAppServerDisconnectedEvent)
          .then((event) => event as CodexAppServerDisconnectedEvent)
          .timeout(const Duration(seconds: 10));

      await client.connect(profile: harness.profile, secrets: harness.secrets);
      await client.startSession();

      final stopped = await control.stopOwner(
        profile: harness.profile,
        secrets: harness.secrets,
        ownerId: ownerId,
        workspaceDir: harness.profile.workspaceDir,
      );
      final disconnected = await disconnectedFuture;

      expect(disconnected, isNotNull);
      expect(stopped.status.name, anyOf('missing', 'stopped'));
    },
    skip: installedSystemTmuxPath == null
        ? 'tmux is not installed on this machine.'
        : false,
  );
}
