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
  final _ = secrets;
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
      return false;
    },
  );

  try {
    final result = await observedHostKey.future.timeout(
      const Duration(seconds: 10),
    );
    if (result.fingerprint.isEmpty || result.keyType.isEmpty) {
      throw StateError('Could not read the SSH host fingerprint.');
    }
    return result;
  } finally {
    client.close();
  }
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
