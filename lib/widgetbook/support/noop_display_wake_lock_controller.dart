import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';

class NoopDisplayWakeLockController implements DisplayWakeLockController {
  const NoopDisplayWakeLockController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
