import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_fixture_foundation.dart';

abstract final class WidgetbookSshFixtures {
  static TranscriptSshUnpinnedHostKeyBlock sshUnpinnedHostKey({
    bool isSaved = false,
  }) {
    return TranscriptSshUnpinnedHostKeyBlock(
      id: 'ssh_unpinned_host_key',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      host: 'relay-dev.internal',
      port: 22,
      keyType: 'ed25519',
      fingerprint: 'SHA256:Kx4q1R3p0z2+9gQmQ4l0o0dXx2nM0Y5M7Fq7zQ8wR0s',
      isSaved: isSaved,
    );
  }

  static TranscriptSshConnectFailedBlock sshConnectFailedBlock() {
    return TranscriptSshConnectFailedBlock(
      id: 'ssh_connect_failed',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      host: 'relay-dev.internal',
      port: 22,
      message:
          'Connection timed out while opening the SSH session. Verify the host, port, and network reachability.',
    );
  }

  static TranscriptSshHostKeyMismatchBlock sshHostKeyMismatchBlock() {
    return TranscriptSshHostKeyMismatchBlock(
      id: 'ssh_host_key_mismatch',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      host: 'relay-dev.internal',
      port: 22,
      keyType: 'ed25519',
      expectedFingerprint: 'SHA256:0g1gQ2o1T6fK8Yw3oQ6zP2i4lP0d3qf7Jr1nM4xS7iA',
      actualFingerprint: 'SHA256:Yq7fA9nL2kP0rM8uB3cW6zT1hV4jD9pQ1sN6eR2xC5d',
    );
  }

  static TranscriptSshAuthenticationFailedBlock sshAuthenticationFailedBlock() {
    return TranscriptSshAuthenticationFailedBlock(
      id: 'ssh_auth_failed',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      host: 'relay-dev.internal',
      port: 22,
      username: 'vince',
      authMode: AuthMode.privateKey,
      message:
          'The server rejected the configured private key. Confirm the selected key and the server account permissions.',
    );
  }
}
