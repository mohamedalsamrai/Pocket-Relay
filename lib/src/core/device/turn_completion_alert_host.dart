import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/errors/device_capability_errors.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';

bool supportsForegroundTurnCompletionSignal([TargetPlatform? platform]) {
  return PocketPlatformBehavior.resolve(
    platform: platform,
    isWeb: kIsWeb,
  ).supportsForegroundTurnCompletionSignal;
}

bool supportsBackgroundTurnCompletionAlerts([TargetPlatform? platform]) {
  return PocketPlatformBehavior.resolve(
    platform: platform,
    isWeb: kIsWeb,
  ).supportsBackgroundTurnCompletionAlerts;
}

class TurnCompletionAlertRequest {
  const TurnCompletionAlertRequest({
    required this.id,
    required this.title,
    this.body,
  });

  final String id;
  final String title;
  final String? body;
}

abstract interface class TurnCompletionAlertController {
  Future<void> emitForegroundSignal();

  Future<void> showBackgroundAlert({required String title, String? body});

  Future<void> clearBackgroundAlert();
}

class PlatformTurnCompletionAlertController
    implements TurnCompletionAlertController {
  const PlatformTurnCompletionAlertController({
    MethodChannel methodChannel = const MethodChannel(
      'me.vinch.pocketrelay/background_execution',
    ),
  }) : _methodChannel = methodChannel;

  final MethodChannel _methodChannel;

  @override
  Future<void> emitForegroundSignal() {
    return HapticFeedback.lightImpact();
  }

  @override
  Future<void> showBackgroundAlert({required String title, String? body}) {
    return _methodChannel.invokeMethod<void>(
      'showTurnCompletionNotification',
      <String, Object?>{'title': title, 'body': body?.trim() ?? ''},
    );
  }

  @override
  Future<void> clearBackgroundAlert() {
    return _methodChannel.invokeMethod<void>('clearTurnCompletionNotification');
  }
}

class TurnCompletionAlertHost extends StatefulWidget {
  const TurnCompletionAlertHost({
    super.key,
    required this.child,
    required this.completionAlerts,
    required this.hasActiveTurn,
    this.turnCompletionAlertController =
        const PlatformTurnCompletionAlertController(),
    this.notificationPermissionController =
        const MethodChannelNotificationPermissionController(),
    this.supportsForegroundSignal,
    this.supportsBackgroundAlerts,
    this.requestNotificationPermissionWhileForegrounded = false,
    this.appLifecycleVisibilityListenable,
    this.onWarningChanged,
  });

  final Widget child;
  final Stream<TurnCompletionAlertRequest> completionAlerts;
  final bool hasActiveTurn;
  final TurnCompletionAlertController turnCompletionAlertController;
  final NotificationPermissionController notificationPermissionController;
  final bool? supportsForegroundSignal;
  final bool? supportsBackgroundAlerts;
  final bool requestNotificationPermissionWhileForegrounded;
  final ValueListenable<AppLifecycleVisibility>?
  appLifecycleVisibilityListenable;
  final ValueChanged<PocketUserFacingError?>? onWarningChanged;

  @override
  State<TurnCompletionAlertHost> createState() =>
      _TurnCompletionAlertHostState();
}

class _TurnCompletionAlertHostState extends State<TurnCompletionAlertHost>
    with
        WidgetsBindingObserver,
        AppLifecycleVisibilityObserver<TurnCompletionAlertHost> {
  final Set<String> _handledAlertIds = <String>{};
  final Queue<String> _handledAlertIdOrder = Queue<String>();
  StreamSubscription<TurnCompletionAlertRequest>? _completionAlertsSubscription;
  bool _showsBackgroundAlert = false;
  bool _isRequestingNotificationPermission = false;
  bool _notificationPermissionDeniedForCurrentForegroundSession = false;
  int _notificationPermissionRequestEpoch = 0;

  static const int _maxHandledAlertIds = 50;

  bool get _supportsForegroundSignal {
    return widget.supportsForegroundSignal ??
        supportsForegroundTurnCompletionSignal();
  }

  bool get _supportsBackgroundAlerts {
    return widget.supportsBackgroundAlerts ??
        supportsBackgroundTurnCompletionAlerts();
  }

  bool get _isForeground {
    return _appLifecycleVisibility.isForegroundVisible;
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
    _subscribeToCompletionAlerts();
    _syncCompletionAlertState();
  }

  @override
  void didUpdateWidget(covariant TurnCompletionAlertHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncAppLifecycleVisibilityObserver(
      oldWidget.appLifecycleVisibilityListenable,
    );
    if (oldWidget.completionAlerts != widget.completionAlerts) {
      unawaited(
        _completionAlertsSubscription?.cancel() ?? Future<void>.value(),
      );
      _subscribeToCompletionAlerts();
    }
    if (oldWidget.notificationPermissionController !=
        widget.notificationPermissionController) {
      _notificationPermissionRequestEpoch += 1;
      _isRequestingNotificationPermission = false;
      _notificationPermissionDeniedForCurrentForegroundSession = false;
    }
    if (oldWidget.hasActiveTurn && !widget.hasActiveTurn) {
      _notificationPermissionDeniedForCurrentForegroundSession = false;
    }
    _syncCompletionAlertState();
  }

  @override
  void dispose() {
    disposeAppLifecycleVisibilityObserver();
    unawaited(_completionAlertsSubscription?.cancel() ?? Future<void>.value());
    _setWarning(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  bool _clearNotificationPermissionDenialOnForeground() {
    if (!_isForeground ||
        !_notificationPermissionDeniedForCurrentForegroundSession) {
      return false;
    }

    _notificationPermissionDeniedForCurrentForegroundSession = false;
    return true;
  }

  @override
  void handleAppLifecycleVisibilityChanged() {
    _clearNotificationPermissionDenialOnForeground();
    _syncCompletionAlertState();
  }

  void _subscribeToCompletionAlerts() {
    _completionAlertsSubscription = widget.completionAlerts.listen(
      _handleCompletionAlert,
    );
  }

  void _syncCompletionAlertState() {
    if (_showsBackgroundAlert && _isForeground) {
      _showsBackgroundAlert = false;
      unawaited(_clearBackgroundAlertSafely());
    }
    _syncForegroundNotificationPermission();
  }

  void _syncForegroundNotificationPermission() {
    if (!_supportsBackgroundAlerts ||
        !_isForeground ||
        !widget.hasActiveTurn ||
        !widget.requestNotificationPermissionWhileForegrounded ||
        _isRequestingNotificationPermission ||
        _notificationPermissionDeniedForCurrentForegroundSession) {
      return;
    }

    _isRequestingNotificationPermission = true;
    final requestEpoch = ++_notificationPermissionRequestEpoch;
    unawaited(_requestNotificationPermissionIfNeeded(requestEpoch));
  }

  Future<void> _handleCompletionAlert(TurnCompletionAlertRequest alert) async {
    if (!_rememberHandledAlertId(alert.id)) {
      return;
    }

    if (_isForeground) {
      if (!_supportsForegroundSignal) {
        return;
      }
      await _emitForegroundSignalSafely();
      return;
    }

    if (!_supportsBackgroundAlerts) {
      return;
    }

    final permissionGranted = await _isNotificationPermissionGrantedSafely();
    if (!permissionGranted.granted) {
      if (permissionGranted.warning == null) {
        _setWarning(null);
      }
      return;
    }

    try {
      await widget.turnCompletionAlertController.showBackgroundAlert(
        title: alert.title,
        body: alert.body,
      );
      _showsBackgroundAlert = true;
      _setWarning(null);
    } catch (error) {
      _setWarning(
        DeviceCapabilityErrors.turnCompletionAlertNotificationUpdateFailed(
          error: error,
        ),
      );
    }
  }

  bool _rememberHandledAlertId(String alertId) {
    if (_handledAlertIds.contains(alertId)) {
      return false;
    }

    _handledAlertIds.add(alertId);
    _handledAlertIdOrder.addLast(alertId);
    while (_handledAlertIdOrder.length > _maxHandledAlertIds) {
      final removedAlertId = _handledAlertIdOrder.removeFirst();
      _handledAlertIds.remove(removedAlertId);
    }
    return true;
  }

  Future<void> _requestNotificationPermissionIfNeeded(int requestEpoch) async {
    try {
      var permission = await _isNotificationPermissionGrantedSafely();
      if (!permission.granted) {
        final shouldClearWarning = permission.warning != null;
        permission = await _requestNotificationPermissionSafely();
        if (shouldClearWarning && permission.warning == null) {
          _setWarning(null);
        }
      }

      if (!mounted || requestEpoch != _notificationPermissionRequestEpoch) {
        return;
      }

      if (!permission.granted) {
        if (permission.warning == null) {
          _setWarning(null);
        }
        _notificationPermissionDeniedForCurrentForegroundSession = true;
        return;
      }

      _setWarning(null);
    } finally {
      if (mounted && requestEpoch == _notificationPermissionRequestEpoch) {
        _isRequestingNotificationPermission = false;
      }
    }
  }

  Future<void> _emitForegroundSignalSafely() async {
    try {
      await widget.turnCompletionAlertController.emitForegroundSignal();
      _setWarning(null);
    } catch (error) {
      _setWarning(
        DeviceCapabilityErrors.turnCompletionAlertForegroundSignalFailed(
          error: error,
        ),
      );
    }
  }

  Future<void> _clearBackgroundAlertSafely() async {
    try {
      await widget.turnCompletionAlertController.clearBackgroundAlert();
      _setWarning(null);
    } catch (error) {
      _setWarning(
        DeviceCapabilityErrors.turnCompletionAlertNotificationUpdateFailed(
          error: error,
        ),
      );
    }
  }

  Future<({bool granted, PocketUserFacingError? warning})>
  _isNotificationPermissionGrantedSafely() async {
    try {
      return (
        granted: await widget.notificationPermissionController.isGranted(),
        warning: null,
      );
    } catch (error) {
      final warning =
          DeviceCapabilityErrors.turnCompletionAlertPermissionQueryFailed(
            error: error,
          );
      _setWarning(warning);
      return (granted: false, warning: warning);
    }
  }

  Future<({bool granted, PocketUserFacingError? warning})>
  _requestNotificationPermissionSafely() async {
    try {
      return (
        granted: await widget.notificationPermissionController
            .requestPermission(),
        warning: null,
      );
    } catch (error) {
      final warning =
          DeviceCapabilityErrors.turnCompletionAlertPermissionRequestFailed(
            error: error,
          );
      _setWarning(warning);
      return (granted: false, warning: warning);
    }
  }

  void _setWarning(PocketUserFacingError? warning) {
    widget.onWarningChanged?.call(warning);
  }
}
