import 'remote_owner_blep_test_support.dart';

void main() {
  test(
    'optional BLEP diagnostics allow the Dart inspector to see an OpenSSH-started owner',
    () async {
      await verifyOpenSshOwnerInspection();
    },
    skip: blepDiagnosticsConfig.skipReason ?? false,
    timeout: Timeout.factor(4),
  );
}
