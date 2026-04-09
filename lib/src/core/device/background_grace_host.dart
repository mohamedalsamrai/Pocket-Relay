import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/errors/device_capability_errors.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

bool supportsFiniteBackgroundGrace([TargetPlatform? platform]) {
  return PocketPlatformBehavior.resolve(
    platform: platform,
    isWeb: kIsWeb,
  ).supportsFiniteBackgroundGrace;
}

abstract interface class BackgroundGraceController {
  Future<void> setEnabled(bool enabled);
}

class MethodChannelBackgroundGraceController
    implements BackgroundGraceController {
  const MethodChannelBackgroundGraceController({
    MethodChannel methodChannel = const MethodChannel(
      'me.vinch.pocketrelay/background_execution',
    ),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  @override
  Future<void> setEnabled(bool enabled) {
    return _methodChannel.invokeMethod<void>(
      'setFiniteBackgroundTaskEnabled',
      <String, Object?>{'enabled': enabled},
    );
  }
}

class BackgroundGraceHost extends StatefulWidget {
  const BackgroundGraceHost({
    super.key,
    required this.child,
    this.keepBackgroundGraceAlive = true,
    this.backgroundGraceController =
        const MethodChannelBackgroundGraceController(),
    this.supportsBackgroundGrace,
    this.appLifecycleVisibilityListenable,
    this.onWarningChanged,
  });

  final Widget child;
  final bool keepBackgroundGraceAlive;
  final BackgroundGraceController backgroundGraceController;
  final bool? supportsBackgroundGrace;
  final ValueListenable<AppLifecycleVisibility>?
  appLifecycleVisibilityListenable;
  final ValueChanged<PocketUserFacingError?>? onWarningChanged;

  @override
  State<BackgroundGraceHost> createState() => _BackgroundGraceHostState();
}

class _BackgroundGraceHostState extends State<BackgroundGraceHost>
    with
        WidgetsBindingObserver,
        AppLifecycleVisibilityObserver<BackgroundGraceHost> {
  bool _requestedBackgroundGraceEnabled = false;

  bool get _supportsBackgroundGrace {
    return widget.supportsBackgroundGrace ?? supportsFiniteBackgroundGrace();
  }

  bool get _shouldEnableBackgroundGrace {
    return _supportsBackgroundGrace &&
        widget.keepBackgroundGraceAlive &&
        _appLifecycleVisibility.isNotForegroundVisible;
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
    _syncBackgroundGrace();
  }

  @override
  void didUpdateWidget(covariant BackgroundGraceHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncAppLifecycleVisibilityObserver(
      oldWidget.appLifecycleVisibilityListenable,
    );
    if (oldWidget.backgroundGraceController !=
            widget.backgroundGraceController &&
        _requestedBackgroundGraceEnabled) {
      unawaited(_setEnabledSafely(oldWidget.backgroundGraceController, false));
      _requestedBackgroundGraceEnabled = false;
    }
    _syncBackgroundGrace();
  }

  @override
  void dispose() {
    disposeAppLifecycleVisibilityObserver();
    _setWarning(null);
    if (_requestedBackgroundGraceEnabled) {
      _requestedBackgroundGraceEnabled = false;
      unawaited(_setEnabledSafely(widget.backgroundGraceController, false));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void handleAppLifecycleVisibilityChanged() {
    _syncBackgroundGrace();
  }

  void _syncBackgroundGrace() {
    final shouldEnableBackgroundGrace = _shouldEnableBackgroundGrace;
    if (shouldEnableBackgroundGrace == _requestedBackgroundGraceEnabled) {
      if (!shouldEnableBackgroundGrace) {
        _setWarning(null);
      }
      return;
    }

    _requestedBackgroundGraceEnabled = shouldEnableBackgroundGrace;
    unawaited(
      _setEnabledSafely(
        widget.backgroundGraceController,
        shouldEnableBackgroundGrace,
      ),
    );
  }

  Future<void> _setEnabledSafely(
    BackgroundGraceController controller,
    bool enabled,
  ) async {
    try {
      await controller.setEnabled(enabled);
      _setWarning(null);
    } catch (error) {
      _setWarning(
        DeviceCapabilityErrors.backgroundGraceEnableFailed(error: error),
      );
    }
  }

  void _setWarning(PocketUserFacingError? warning) {
    widget.onWarningChanged?.call(warning);
  }
}
