import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/errors/device_capability_errors.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

bool supportsDisplayWakeLock([TargetPlatform? platform]) {
  return PocketPlatformBehavior.resolve(
    platform: platform,
    isWeb: kIsWeb,
  ).supportsWakeLock;
}

abstract interface class DisplayWakeLockController {
  Future<void> setEnabled(bool enabled);
}

class WakelockPlusDisplayWakeLockController
    implements DisplayWakeLockController {
  const WakelockPlusDisplayWakeLockController();

  @override
  Future<void> setEnabled(bool enabled) {
    return WakelockPlus.toggle(enable: enabled);
  }
}

class DisplayWakeLockHost extends StatefulWidget {
  const DisplayWakeLockHost({
    super.key,
    required this.child,
    this.keepDisplayAwake = true,
    this.displayWakeLockController =
        const WakelockPlusDisplayWakeLockController(),
    this.supportsWakeLock,
    this.appLifecycleVisibilityListenable,
    this.onWarningChanged,
  });

  final Widget child;
  final bool keepDisplayAwake;
  final DisplayWakeLockController displayWakeLockController;
  final bool? supportsWakeLock;
  final ValueListenable<AppLifecycleVisibility>?
  appLifecycleVisibilityListenable;
  final ValueChanged<PocketUserFacingError?>? onWarningChanged;

  @override
  State<DisplayWakeLockHost> createState() => _DisplayWakeLockHostState();
}

class _DisplayWakeLockHostState extends State<DisplayWakeLockHost>
    with
        WidgetsBindingObserver,
        AppLifecycleVisibilityObserver<DisplayWakeLockHost> {
  bool _requestedWakeLockEnabled = false;

  bool get _supportsWakeLock {
    return widget.supportsWakeLock ?? supportsDisplayWakeLock();
  }

  bool get _shouldEnableWakeLock {
    return _supportsWakeLock &&
        widget.keepDisplayAwake &&
        _appLifecycleVisibility.isForegroundVisible;
  }

  AppLifecycleVisibility get _appLifecycleVisibility {
    return appLifecycleVisibility;
  }

  @override
  ValueListenable<AppLifecycleVisibility>?
  get appLifecycleVisibilityListenable {
    return widget.appLifecycleVisibilityListenable;
  }

  @override
  void initState() {
    super.initState();
    initAppLifecycleVisibilityObserver();
    _syncWakeLock();
  }

  @override
  void didUpdateWidget(covariant DisplayWakeLockHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncAppLifecycleVisibilityObserver(
      oldWidget.appLifecycleVisibilityListenable,
    );
    if (oldWidget.displayWakeLockController !=
            widget.displayWakeLockController &&
        _requestedWakeLockEnabled) {
      unawaited(_setEnabledSafely(oldWidget.displayWakeLockController, false));
      _requestedWakeLockEnabled = false;
    }
    _syncWakeLock();
  }

  @override
  void dispose() {
    disposeAppLifecycleVisibilityObserver();
    _setWarning(null);
    if (_requestedWakeLockEnabled) {
      _requestedWakeLockEnabled = false;
      unawaited(_setEnabledSafely(widget.displayWakeLockController, false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void handleAppLifecycleVisibilityChanged() {
    _syncWakeLock();
  }

  void _syncWakeLock() {
    final shouldEnableWakeLock = _shouldEnableWakeLock;
    if (shouldEnableWakeLock == _requestedWakeLockEnabled) {
      if (!shouldEnableWakeLock) {
        _setWarning(null);
      }
      return;
    }

    _requestedWakeLockEnabled = shouldEnableWakeLock;
    unawaited(
      _setEnabledSafely(widget.displayWakeLockController, shouldEnableWakeLock),
    );
  }

  Future<void> _setEnabledSafely(
    DisplayWakeLockController controller,
    bool enabled,
  ) async {
    try {
      await controller.setEnabled(enabled);
      _setWarning(null);
    } catch (error) {
      _setWarning(DeviceCapabilityErrors.wakeLockEnableFailed(error: error));
    }
  }

  void _setWarning(PocketUserFacingError? warning) {
    widget.onWarningChanged?.call(warning);
  }
}
