part of '../codex_app_server_remote_owner_ssh.dart';

class CodexSshRemoteAppServerOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const CodexSshRemoteAppServerOwnerInspector({
    this.sshBootstrap = connectSshBootstrapClient,
  });

  final CodexSshProcessBootstrap sshBootstrap;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return CodexSshRemoteAppServerHostProbe(
      sshBootstrap: sshBootstrap,
    ).probeHostCapabilities(profile: profile, secrets: secrets);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    final sessionName = buildPocketRelayRemoteOwnerSessionName(
      ownerId: ownerId,
    );
    final result = await _runRemoteProbeCommand(
      profile: profile,
      secrets: secrets,
      sshBootstrap: sshBootstrap,
      command: buildSshRemoteOwnerInspectCommand(
        sessionName: sessionName,
        workspaceDir: workspaceDir,
      ),
    );
    return _parseOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      sessionName: sessionName,
      stdout: result.stdout,
      stderr: result.stderr,
      exitCode: result.exitCode,
    );
  }
}
