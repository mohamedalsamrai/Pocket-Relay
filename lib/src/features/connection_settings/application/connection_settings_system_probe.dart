import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';

class ConnectionSettingsSystemTestResult {
  const ConnectionSettingsSystemTestResult({
    required this.keyType,
    required this.fingerprint,
  });

  final String keyType;
  final String fingerprint;
}

Future<ConnectionSettingsSystemTestResult> testConnectionSettingsRemoteSystem({
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final observedHostKey = Completer<ConnectionSettingsSystemTestResult>();
  final socket = await SSHSocket.connect(
    profile.host.trim(),
    profile.port,
    timeout: const Duration(seconds: 10),
  );
  final client = SSHClient(
    socket,
    username: profile.username.trim(),
    onVerifyHostKey: (type, fingerprint) {
      if (!observedHostKey.isCompleted) {
        observedHostKey.complete(
          ConnectionSettingsSystemTestResult(
            keyType: type,
            fingerprint: formatFingerprint(fingerprint),
          ),
        );
      }
      return true;
    },
    identities: _connectionSettingsSystemProbeIdentities(profile, secrets),
    onPasswordRequest: profile.authMode == AuthMode.password
        ? () => secrets.password.trim().isEmpty ? null : secrets.password
        : null,
  );

  try {
    final result = await Future.any<ConnectionSettingsSystemTestResult>([
      observedHostKey.future,
      client.authenticated.then<ConnectionSettingsSystemTestResult>((_) {
        throw StateError('Could not read the SSH host fingerprint.');
      }),
    ]).timeout(const Duration(seconds: 10));
    await client.authenticated;
    if (result.fingerprint.isEmpty || result.keyType.isEmpty) {
      throw StateError('Could not read the SSH host fingerprint.');
    }
    return result;
  } finally {
    client.close();
  }
}

List<SSHKeyPair>? _connectionSettingsSystemProbeIdentities(
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
  return SSHKeyPair.fromPem(privateKey, passphrase.isEmpty ? null : passphrase);
}

String connectionSettingsSystemProbeErrorMessage(Object error) {
  return switch (error) {
    SSHAuthFailError(:final message) ||
    SSHAuthAbortError(:final message) ||
    SSHHandshakeError(:final message) ||
    SSHChannelRequestError(:final message) ||
    SSHHostkeyError(:final message) => message,
    SSHChannelOpenError(:final description) => description,
    SSHSocketError(:final error) => '$error',
    _ => '$error',
  };
}
