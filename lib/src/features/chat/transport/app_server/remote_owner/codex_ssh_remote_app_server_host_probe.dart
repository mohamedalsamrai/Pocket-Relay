part of '../codex_app_server_remote_owner_ssh.dart';

class CodexSshRemoteAppServerHostProbe
    implements CodexRemoteAppServerHostProbe {
  const CodexSshRemoteAppServerHostProbe({
    this.sshBootstrap = connectSshBootstrapClient,
  });

  final CodexSshProcessBootstrap sshBootstrap;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final result = await _runRemoteProbeCommand(
      profile: profile,
      secrets: secrets,
      sshBootstrap: sshBootstrap,
      command: buildSshRemoteHostCapabilityProbeCommand(profile: profile),
    );
    return _parseHostCapabilities(
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode,
    );
  }
}
