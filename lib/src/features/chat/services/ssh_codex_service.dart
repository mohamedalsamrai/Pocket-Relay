import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/models/codex_remote_event.dart';
import 'package:pocket_relay/src/features/chat/services/codex_event_parser.dart';
import 'package:dartssh2/dartssh2.dart';

class SshCodexService {
  SshCodexService({CodexEventParser? eventParser})
    : _eventParser = eventParser ?? const CodexEventParser();

  final CodexEventParser _eventParser;

  SSHClient? _client;
  SSHSession? _session;

  bool get isRunning => _session != null;

  Stream<CodexRemoteEvent> runTurn({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String prompt,
    String? threadId,
  }) {
    final controller = StreamController<CodexRemoteEvent>();
    unawaited(
      _runTurn(
        controller: controller,
        profile: profile,
        secrets: secrets,
        prompt: prompt,
        threadId: threadId,
      ),
    );
    return controller.stream;
  }

  Future<void> cancel() async {
    final session = _session;
    final client = _client;
    _session = null;
    _client = null;

    if (session != null) {
      try {
        session.kill(SSHSignal.KILL);
      } catch (_) {
        // Ignore cancellation errors when the session has already ended.
      }
    }

    client?.close();
  }

  Future<void> _runTurn({
    required StreamController<CodexRemoteEvent> controller,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String prompt,
    String? threadId,
  }) async {
    try {
      final socket = await SSHSocket.connect(
        profile.host.trim(),
        profile.port,
        timeout: const Duration(seconds: 10),
      );

      final client = SSHClient(
        socket,
        username: profile.username.trim(),
        onVerifyHostKey: (type, fingerprint) {
          final actual = formatFingerprint(fingerprint);
          final expected = profile.hostFingerprint.trim();

          if (expected.isEmpty) {
            controller.add(
              InformationalEvent(
                message:
                    'Accepted $type host key fingerprint $actual. Pin it later if you want stricter verification.',
                isError: false,
              ),
            );
            return true;
          }

          if (normalizeFingerprint(expected) == normalizeFingerprint(actual)) {
            return true;
          }

          controller.add(
            InformationalEvent(
              message:
                  'Host key mismatch. Expected ${profile.hostFingerprint}, got $actual.',
              isError: true,
            ),
          );
          return false;
        },
        identities: _buildIdentities(profile, secrets),
        onPasswordRequest: profile.authMode == AuthMode.password
            ? () => secrets.password.trim().isEmpty ? null : secrets.password
            : null,
      );

      _client = client;
      await client.authenticated;
      controller.add(
        InformationalEvent(
          message:
              'Connected to ${profile.host}:${profile.port} as ${profile.username}.',
          isError: false,
        ),
      );

      final session = await client.execute(
        _buildRemoteCommand(
          profile: profile,
          prompt: prompt,
          threadId: threadId,
        ),
      );

      _session = session;

      final stdoutFuture = _consumeJsonLines(
        session.stdout,
        controller: controller,
      );
      final stderrFuture = _consumePlainLines(
        session.stderr,
        controller: controller,
      );

      final usage = await stdoutFuture;
      await stderrFuture;
      await session.done;

      controller.add(
        TurnFinishedEvent(exitCode: session.exitCode, usage: usage),
      );
    } catch (error) {
      controller.add(
        InformationalEvent(message: error.toString(), isError: true),
      );
    } finally {
      _session = null;
      _client?.close();
      _client = null;
      await controller.close();
    }
  }

  List<SSHKeyPair>? _buildIdentities(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) {
    if (profile.authMode != AuthMode.privateKey) {
      return null;
    }

    final privateKey = secrets.privateKeyPem.trim();
    if (privateKey.isEmpty) {
      throw StateError('A private key is required for key-based SSH auth.');
    }

    final passphrase = secrets.privateKeyPassphrase.trim();
    return SSHKeyPair.fromPem(
      privateKey,
      passphrase.isEmpty ? null : passphrase,
    );
  }

  Future<TurnUsage?> _consumeJsonLines(
    Stream<Uint8List> stream, {
    required StreamController<CodexRemoteEvent> controller,
  }) async {
    TurnUsage? usage;

    await for (final line in _decodeLines(stream)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      try {
        final parsedLine = _eventParser.parseLine(trimmed);
        for (final event in parsedLine.events) {
          controller.add(event);
        }
        usage = parsedLine.usage ?? usage;
      } catch (_) {
        controller.add(
          InformationalEvent(
            message: 'Non-JSON stdout: $trimmed',
            isError: false,
          ),
        );
      }
    }

    return usage;
  }

  Future<void> _consumePlainLines(
    Stream<Uint8List> stream, {
    required StreamController<CodexRemoteEvent> controller,
  }) async {
    await for (final line in _decodeLines(stream)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      controller.add(InformationalEvent(message: trimmed, isError: true));
    }
  }

  Stream<String> _decodeLines(Stream<Uint8List> stream) {
    return stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  String _buildRemoteCommand({
    required ConnectionProfile profile,
    required String prompt,
    String? threadId,
  }) {
    final shouldResume = threadId != null && !profile.ephemeralSession;
    final codexArgs = <String>[
      profile.codexPath.trim(),
      'exec',
      if (shouldResume) 'resume',
      '--json',
      if (profile.dangerouslyBypassSandbox)
        '--dangerously-bypass-approvals-and-sandbox'
      else
        '--full-auto',
      if (profile.skipGitRepoCheck) '--skip-git-repo-check',
      if (profile.ephemeralSession) '--ephemeral',
      if (shouldResume) threadId,
      prompt,
    ];

    final codexCommand = codexArgs.map(shellEscape).join(' ');
    final command =
        'cd ${shellEscape(profile.workspaceDir.trim())} && $codexCommand';
    return 'bash -lc ${shellEscape(command)}';
  }
}
