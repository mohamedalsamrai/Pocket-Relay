part of '../codex_app_server_remote_owner_ssh.dart';

class CodexSshRemoteAppServerOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const CodexSshRemoteAppServerOwnerControl({
    this.sshBootstrap = connectSshBootstrapClient,
    this.readyPollAttempts = 40,
    this.readyPollDelay = const Duration(milliseconds: 250),
    this.stopPollAttempts = 10,
    this.stopPollDelay = const Duration(milliseconds: 100),
  });

  final CodexSshProcessBootstrap sshBootstrap;
  final int readyPollAttempts;
  final Duration readyPollDelay;
  final int stopPollAttempts;
  final Duration stopPollDelay;

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
  }) {
    return CodexSshRemoteAppServerOwnerInspector(
      sshBootstrap: sshBootstrap,
    ).inspectOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    final existingSnapshot = await inspectOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
    switch (existingSnapshot.status) {
      case CodexRemoteAppServerOwnerStatus.running:
        return existingSnapshot;
      case CodexRemoteAppServerOwnerStatus.unhealthy:
        return existingSnapshot;
      case CodexRemoteAppServerOwnerStatus.stopped:
        await stopOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: workspaceDir,
        );
      case CodexRemoteAppServerOwnerStatus.missing:
        break;
    }

    final sessionName = buildPocketRelayRemoteOwnerSessionName(
      ownerId: ownerId,
    );
    CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
    for (final port in buildPocketRelayRemoteOwnerPortCandidates(
      ownerId: ownerId,
    )) {
      await _runRemoteControlCommand(
        profile: profile,
        secrets: secrets,
        sshBootstrap: sshBootstrap,
        command: buildSshRemoteOwnerStartCommand(
          sessionName: sessionName,
          workspaceDir: workspaceDir,
          codexPath: profile.codexPath,
          port: port,
        ),
      );
      lastSnapshot = await _waitForOwnerReady(
        profile: profile,
        secrets: secrets,
        ownerId: ownerId,
        workspaceDir: workspaceDir,
        sshBootstrap: sshBootstrap,
        attempts: readyPollAttempts,
        delay: readyPollDelay,
      );
      if (lastSnapshot.status == CodexRemoteAppServerOwnerStatus.running) {
        return lastSnapshot;
      }
      if (!_shouldRetryRemoteOwnerStart(lastSnapshot)) {
        return lastSnapshot;
      }
      await _runRemoteControlCommand(
        profile: profile,
        secrets: secrets,
        sshBootstrap: sshBootstrap,
        command: buildSshRemoteOwnerStopCommand(sessionName: sessionName),
      );
    }

    if (lastSnapshot != null) {
      return lastSnapshot;
    }
    return inspectOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    final sessionName = buildPocketRelayRemoteOwnerSessionName(
      ownerId: ownerId,
    );
    await _runRemoteControlCommand(
      profile: profile,
      secrets: secrets,
      sshBootstrap: sshBootstrap,
      command: buildSshRemoteOwnerStopCommand(sessionName: sessionName),
    );
    return _waitForOwnerStopped(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      sshBootstrap: sshBootstrap,
      attempts: stopPollAttempts,
      delay: stopPollDelay,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    await stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
    return startOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }
}
