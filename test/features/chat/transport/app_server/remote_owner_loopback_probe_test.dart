import 'remote_owner_loopback_test_support.dart';

void main() {
  test(
    'loopback probe reports missing tmux when no system tmux is available',
    () async {
      final harness = await RemoteOwnerLoopbackHarness.create(
        tmuxMode: RemoteOwnerTmuxMode.none,
      );
      addTearDown(harness.dispose);

      final probe = CodexSshRemoteAppServerHostProbe(
        sshBootstrap: harness.sshBootstrap,
      );

      final capabilities = await probe.probeHostCapabilities(
        profile: harness.profile,
        secrets: harness.secrets,
      );

      expect(capabilities.supportsContinuity, isFalse);
      expect(capabilities.issues, <ConnectionRemoteHostCapabilityIssue>{
        ConnectionRemoteHostCapabilityIssue.tmuxMissing,
      });
    },
    skip: installedSystemTmuxPath != null
        ? 'System tmux is installed, so the probe intentionally finds it via explicit system paths.'
        : false,
  );

  test('loopback probe reports continuity support with tmux shim', () async {
    final harness = await RemoteOwnerLoopbackHarness.create(
      tmuxMode: RemoteOwnerTmuxMode.shim,
    );
    addTearDown(harness.dispose);

    final probe = CodexSshRemoteAppServerHostProbe(
      sshBootstrap: harness.sshBootstrap,
    );

    final capabilities = await probe.probeHostCapabilities(
      profile: harness.profile,
      secrets: harness.secrets,
    );

    expect(capabilities.supportsContinuity, isTrue);
    expect(capabilities.issues, isEmpty);
    expect(
      capabilities.detail,
      'Remote host supports continuity and can run the managed remote app-server.',
    );
  });
}
