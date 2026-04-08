part of '../codex_app_server_remote_owner_ssh.dart';

Future<_RemoteProbeCommandResult> _runRemoteProbeCommand({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required CodexSshProcessBootstrap sshBootstrap,
  required String command,
}) async {
  final client = await sshBootstrap(
    profile: profile,
    secrets: secrets,
    verifyHostKey: (keyType, actualFingerprint) {
      final expectedFingerprint = profile.hostFingerprint.trim();
      if (expectedFingerprint.isEmpty) {
        return false;
      }
      return normalizeFingerprint(expectedFingerprint) ==
          normalizeFingerprint(actualFingerprint);
    },
  );

  try {
    await client.authenticate();
    final process = await client.launchProcess(command);
    try {
      final stdout = await _readProcessStream(process.stdout);
      final stderr = await _readProcessStream(process.stderr);
      await process.done;
      return _RemoteProbeCommandResult(
        stdout: stdout,
        stderr: stderr,
        exitCode: process.exitCode,
      );
    } finally {
      await process.close();
    }
  } catch (_) {
    client.close();
    rethrow;
  }
}

Future<void> _runRemoteControlCommand({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required CodexSshProcessBootstrap sshBootstrap,
  required String command,
}) async {
  final result = await _runRemoteProbeCommand(
    profile: profile,
    secrets: secrets,
    sshBootstrap: sshBootstrap,
    command: command,
  );
  final exitCode = result.exitCode ?? 0;
  if (exitCode == 0) {
    return;
  }
  final detail = [
    'exit $exitCode',
    if (result.stderr.trim().isNotEmpty) result.stderr.trim(),
    if (result.stdout.trim().isNotEmpty) result.stdout.trim(),
  ].join(' | ');
  throw StateError(
    detail.isEmpty
        ? 'Remote owner control command failed.'
        : 'Remote owner control command failed: $detail',
  );
}

Future<String> _readProcessStream(Stream<List<int>> stream) async {
  final buffer = StringBuffer();
  await for (final chunk in stream) {
    buffer.write(utf8.decode(chunk));
  }
  return buffer.toString();
}

CodexRemoteAppServerOwnerSnapshot _parseOwnerSnapshot({
  required String ownerId,
  required String workspaceDir,
  required String sessionName,
  required String stdout,
  required String stderr,
  required int? exitCode,
}) {
  final line = stdout
      .split('\n')
      .map((entry) => entry.trim())
      .firstWhere(
        (entry) => entry.startsWith('__pocket_relay_owner__'),
        orElse: () => '',
      );
  if (line.isEmpty) {
    final detail = [
      if (exitCode != null) 'exit $exitCode',
      if (stderr.trim().isNotEmpty) stderr.trim(),
      if (stdout.trim().isNotEmpty) stdout.trim(),
    ].join(' | ');
    throw StateError(
      detail.isEmpty
          ? 'Remote owner inspection returned no parseable result.'
          : 'Remote owner inspection returned no parseable result: $detail',
    );
  }

  final fields = <String, String>{};
  for (final segment in line.split(RegExp(r'\s+')).skip(1)) {
    final separatorIndex = segment.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }
    fields[segment.substring(0, separatorIndex)] = segment.substring(
      separatorIndex + 1,
    );
  }

  final status = switch (fields['status']) {
    'missing' => CodexRemoteAppServerOwnerStatus.missing,
    'stopped' => CodexRemoteAppServerOwnerStatus.stopped,
    'running' => CodexRemoteAppServerOwnerStatus.running,
    'unhealthy' => CodexRemoteAppServerOwnerStatus.unhealthy,
    _ => null,
  };
  if (status == null) {
    throw StateError(
      'Remote owner inspection returned an unknown status: ${fields['status']}.',
    );
  }

  final pid = int.tryParse(fields['pid'] ?? '');
  final host = fields['host'];
  final port = int.tryParse(fields['port'] ?? '');
  final logDetail = _decodedOwnerLog(fields['log_b64']);

  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: status,
    sessionName: sessionName,
    pid: pid,
    endpoint: host != null && host.isNotEmpty && port != null
        ? CodexRemoteAppServerEndpoint(host: host, port: port)
        : null,
    detail: _ownerDetailForCode(fields['detail'], logDetail: logDetail),
  );
}

CodexRemoteAppServerHostCapabilities _parseHostCapabilities({
  required String stdout,
  required String stderr,
  required int? exitCode,
}) {
  final match = RegExp(
    r'__pocket_relay_capabilities__\s+tmux=(\d+)\s+workspace=(\d+)\s+codex=(\d+)',
  ).firstMatch(stdout);
  if (match == null) {
    final detail = [
      if (exitCode != null) 'exit $exitCode',
      if (stderr.trim().isNotEmpty) stderr.trim(),
      if (stdout.trim().isNotEmpty) stdout.trim(),
    ].join(' | ');
    throw StateError(
      detail.isEmpty
          ? 'Remote host capability probe returned no parseable result.'
          : 'Remote host capability probe returned no parseable result: $detail',
    );
  }

  final issues = <ConnectionRemoteHostCapabilityIssue>{};
  if (match.group(1) != '0') {
    issues.add(ConnectionRemoteHostCapabilityIssue.tmuxMissing);
  }
  if (match.group(2) != '0') {
    issues.add(ConnectionRemoteHostCapabilityIssue.workspaceUnavailable);
  }
  if (match.group(3) != '0') {
    issues.add(ConnectionRemoteHostCapabilityIssue.agentCommandMissing);
  }

  return CodexRemoteAppServerHostCapabilities(
    issues: issues,
    detail: issues.isEmpty
        ? 'Remote host supports continuity and can run the managed remote app-server.'
        : null,
  );
}

String? _ownerDetailForCode(String? code, {String? logDetail}) {
  final baseDetail = switch (code) {
    null || '' => null,
    'ready' => 'Managed remote app-server is ready.',
    'session_missing' =>
      'No managed remote app-server is running for this connection.',
    'pane_missing' =>
      'The managed tmux owner exists but has no live pane process.',
    'process_missing' =>
      'The managed tmux owner exists but the app-server process is not running.',
    'workspace_mismatch' =>
      'The managed tmux owner exists but points at a different workspace.',
    'expected_workspace_unavailable' =>
      'The configured workspace directory is not accessible on the remote host.',
    'listen_url_missing' =>
      'The managed tmux owner is not running a websocket app-server.',
    'ready_check_failed' =>
      'The managed remote app-server is running but did not pass its readiness check.',
    'tmux_unavailable' => 'tmux is not available on the remote host.',
    _ => code,
  };

  final normalizedLog = logDetail?.trim();
  if (normalizedLog == null || normalizedLog.isEmpty) {
    return baseDetail;
  }
  if (baseDetail == null || baseDetail.isEmpty) {
    return normalizedLog;
  }
  if (baseDetail.contains(normalizedLog)) {
    return baseDetail;
  }
  return '$baseDetail Underlying error: $normalizedLog';
}

String? _decodedOwnerLog(String? encodedLog) {
  final normalized = encodedLog?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }

  try {
    final decoded = utf8.decode(base64.decode(normalized));
    final lines = decoded
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }
    return lines.join(' ');
  } catch (_) {
    return null;
  }
}

bool _shouldRetryRemoteOwnerStart(CodexRemoteAppServerOwnerSnapshot snapshot) {
  return switch (snapshot.status) {
    CodexRemoteAppServerOwnerStatus.stopped => true,
    _ => false,
  };
}

Future<CodexRemoteAppServerOwnerSnapshot> _waitForOwnerReady({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String ownerId,
  required String workspaceDir,
  required CodexSshProcessBootstrap sshBootstrap,
  required int attempts,
  required Duration delay,
}) async {
  CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    lastSnapshot =
        await CodexSshRemoteAppServerOwnerInspector(
          sshBootstrap: sshBootstrap,
        ).inspectOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: workspaceDir,
        );
    if (lastSnapshot.status == CodexRemoteAppServerOwnerStatus.running) {
      return lastSnapshot;
    }
    await Future<void>.delayed(delay);
  }
  if (lastSnapshot != null) {
    return lastSnapshot;
  }
  return CodexSshRemoteAppServerOwnerInspector(
    sshBootstrap: sshBootstrap,
  ).inspectOwner(
    profile: profile,
    secrets: secrets,
    ownerId: ownerId,
    workspaceDir: workspaceDir,
  );
}

Future<CodexRemoteAppServerOwnerSnapshot> _waitForOwnerStopped({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
  required String ownerId,
  required String workspaceDir,
  required CodexSshProcessBootstrap sshBootstrap,
  required int attempts,
  required Duration delay,
}) async {
  CodexRemoteAppServerOwnerSnapshot? lastSnapshot;
  for (var attempt = 0; attempt < attempts; attempt += 1) {
    lastSnapshot =
        await CodexSshRemoteAppServerOwnerInspector(
          sshBootstrap: sshBootstrap,
        ).inspectOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: workspaceDir,
        );
    if (lastSnapshot.status == CodexRemoteAppServerOwnerStatus.missing ||
        lastSnapshot.status == CodexRemoteAppServerOwnerStatus.stopped) {
      return lastSnapshot;
    }
    await Future<void>.delayed(delay);
  }
  if (lastSnapshot != null) {
    return lastSnapshot;
  }
  return CodexSshRemoteAppServerOwnerInspector(
    sshBootstrap: sshBootstrap,
  ).inspectOwner(
    profile: profile,
    secrets: secrets,
    ownerId: ownerId,
    workspaceDir: workspaceDir,
  );
}

final class _RemoteProbeCommandResult {
  const _RemoteProbeCommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int? exitCode;
}
