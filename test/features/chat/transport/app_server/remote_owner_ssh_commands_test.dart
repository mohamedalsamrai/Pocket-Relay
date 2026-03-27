import 'remote_owner_ssh_test_support.dart';

void main() {
  test('builds a capability probe command for a plain codex binary', () {
    final command = buildSshRemoteHostCapabilityProbeCommand(
      profile: sshProfile().copyWith(codexPath: 'codex'),
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('command -v tmux'));
    expect(command, contains('run_requested_codex app-server --help'));
    expect(command, contains(r'$HOME/.local/bin/$requested_codex'));
    expect(command, contains('/workspace'));
  });

  test(
    'capability probe command executes successfully for a plain codex binary',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'pocket_relay_capability_probe_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final workspaceDir = Directory('${tempDir.path}/workspace')..createSync();
      final localBinDir = Directory('${tempDir.path}/.local/bin')
        ..createSync(recursive: true);
      final codexFile = File('${localBinDir.path}/codex');
      codexFile.writeAsStringSync('''
#!/bin/bash
if [ "\$1" = "app-server" ] && [ "\$2" = "--help" ]; then
  exit 0
fi
exit 1
''');
      await Process.run('/bin/chmod', <String>['+x', codexFile.path]);

      final command = buildSshRemoteHostCapabilityProbeCommand(
        profile: sshProfile().copyWith(
          codexPath: 'codex',
          workspaceDir: workspaceDir.path,
        ),
      );

      final result = await Process.run(
        '/bin/bash',
        <String>['-c', command],
        environment: <String, String>{
          'HOME': tempDir.path,
          'PATH': Platform.environment['PATH'] ?? '',
        },
      );

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        result.stdout.toString(),
        contains('__pocket_relay_capabilities__ tmux='),
      );
    },
  );

  test(
    'builds a capability probe command for a launch command with spaces',
    () {
      final command = buildSshRemoteHostCapabilityProbeCommand(
        profile: sshProfile().copyWith(codexPath: 'just codex-mcp'),
      );

      expect(command, contains('just codex-mcp'));
      expect(command, contains('run_requested_codex app-server --help'));
    },
  );

  test(
    'buildPocketRelayRemoteOwnerSessionName normalizes unsafe characters',
    () {
      expect(
        buildPocketRelayRemoteOwnerSessionName(
          ownerId: ' remote owner / feature ',
        ),
        'pocket-relay-remote-owner-feature',
      );
    },
  );

  test('buildPocketRelayRemoteOwnerPortCandidates are deterministic', () {
    final first = buildPocketRelayRemoteOwnerPortCandidates(
      ownerId: 'remote-1',
    );
    final second = buildPocketRelayRemoteOwnerPortCandidates(
      ownerId: 'remote-1',
    );

    expect(first, second);
    expect(first, hasLength(8));
    expect(first.toSet(), hasLength(8));
    expect(first.every((port) => port >= 42000 && port < 62000), isTrue);
  });

  test('buildSshRemoteOwnerInspectCommand checks tmux and readyz', () {
    final command = buildSshRemoteOwnerInspectCommand(
      sessionName: 'pocket-relay-remote-1',
      workspaceDir: '/workspace',
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('tmux has-session'));
    expect(command, contains('/readyz'));
    expect(command, contains('resolve_pocket_relay_log_dir()'));
    expect(command, contains(r'$XDG_RUNTIME_DIR/pocket-relay'));
    expect(command, contains(r'cache_root="$HOME/.cache"'));
    expect(command, contains(r'$cache_root/pocket-relay'));
    expect(command, contains(r'[ -n "${HOME-}" ] && [ -d "${HOME-}" ]'));
    expect(command, contains(r'[ -d "$cache_root" ] && [ -w "$cache_root" ]'));
    expect(command, contains(r'[ ! -e "$cache_root" ] && [ -w "$HOME" ]'));
    expect(command, contains('resolve_pocket_relay_log_file'));
    expect(command, contains('pocket-relay-remote-1'));
  });

  test('buildSshRemoteOwnerStartCommand starts a tmux websocket owner', () {
    final command = buildSshRemoteOwnerStartCommand(
      sessionName: 'pocket-relay-remote-1',
      workspaceDir: '/workspace',
      codexPath: 'codex',
      port: 45123,
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('tmux new-session'));
    expect(command, contains('ws://127.0.0.1:45123'));
    expect(command, contains('ensure_pocket_relay_log_dir'));
    expect(command, contains('umask 077'));
    expect(command, contains('previous_umask=\$(umask)'));
    expect(command, contains('mkdir -p'));
    expect(command, contains('chmod 700'));
    expect(command, contains('umask "\$previous_umask"'));
    expect(command, contains('resolve_pocket_relay_log_file'));
    expect(command, contains('requested_codex='));
    expect(command, contains('resolve_requested_codex()'));
    expect(command, contains('run_requested_codex app-server --listen'));
    expect(command, contains('codex app-server exited with status'));
    expect(command, contains('pocket-relay-remote-1'));
    expect(command, contains('tmux respawn-pane'));
    expect(command, contains('exec bash -lc'));
    expect(command, contains('tmux new-session -d -P -F'));
    expect(command, contains('#{pane_id}'));
  });

  test(
    'buildSshRemoteOwnerStartCommand preserves shell-wrapped launch commands',
    () {
      final command = buildSshRemoteOwnerStartCommand(
        sessionName: 'pocket-relay-remote-1',
        workspaceDir: '/workspace',
        codexPath: 'source /etc/profile && codex',
        port: 45123,
      );

      expect(command, contains('source /etc/profile && codex'));
      expect(command, contains('run_requested_codex app-server --listen'));
    },
  );

  test('buildSshRemoteOwnerStopCommand kills the expected tmux session', () {
    final command = buildSshRemoteOwnerStopCommand(
      sessionName: 'pocket-relay-remote-1',
    );

    expect(
      command,
      contains(
        r'PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"',
      ),
    );
    expect(command, contains('tmux kill-session'));
    expect(command, contains('resolve_pocket_relay_log_file'));
    expect(command, contains('pocket-relay-remote-1'));
  });
}
