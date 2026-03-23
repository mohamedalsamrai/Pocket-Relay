import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';

import 'codex_app_server_models.dart';
import 'codex_app_server_remote_owner.dart';
import 'codex_app_server_ssh_process.dart';

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
      final process = await client.launchProcess(
        buildSshRemoteHostCapabilityProbeCommand(profile: profile),
      );
      try {
        final stdout = await _readProcessStream(process.stdout);
        final stderr = await _readProcessStream(process.stderr);
        await process.done;

        return _parseHostCapabilities(
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
}

@visibleForTesting
String buildSshRemoteHostCapabilityProbeCommand({
  required ConnectionProfile profile,
}) {
  final command =
      '''
tmux_status=1
if command -v tmux >/dev/null 2>&1; then
  tmux_status=0
fi
codex_status=1
if cd ${shellEscape(profile.workspaceDir.trim())} >/dev/null 2>&1 && ${profile.codexPath.trim()} app-server --help >/dev/null 2>&1; then
  codex_status=0
fi
printf '__pocket_relay_capabilities__ tmux=%s codex=%s\\n' "\$tmux_status" "\$codex_status"
''';
  return 'bash -lc ${shellEscape(command)}';
}

Future<String> _readProcessStream(Stream<List<int>> stream) async {
  final buffer = StringBuffer();
  await for (final chunk in stream) {
    buffer.write(utf8.decode(chunk));
  }
  return buffer.toString();
}

CodexRemoteAppServerHostCapabilities _parseHostCapabilities({
  required String stdout,
  required String stderr,
  required int? exitCode,
}) {
  final match = RegExp(
    r'__pocket_relay_capabilities__\s+tmux=(\d+)\s+codex=(\d+)',
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
    issues.add(ConnectionRemoteHostCapabilityIssue.codexMissing);
  }

  return CodexRemoteAppServerHostCapabilities(
    issues: issues,
    detail: issues.isEmpty
        ? 'Remote host supports Pocket Relay continuity.'
        : null,
  );
}
