import 'remote_owner_blep_test_support.dart';

void main() {
  test(
    'optional BLEP diagnostics verify dartssh2 owner startup reaches a running snapshot',
    () async {
      await verifyDartOwnerStartStatus();
    },
    skip: blepDiagnosticsConfig.skipReason ?? false,
    timeout: Timeout.factor(4),
  );
}
