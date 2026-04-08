import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/errors/device_capability_errors.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
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
  final ValueChanged<PocketUserFacingError?>? onWarningChanged;

  @override
  State<TurnCompletionAlertHost> createState() =>
      _TurnCompletionAlertHostState();
}

class _TurnCompletionAlertHostState extends State<TurnCompletionAlertHost>
    with WidgetsBindingObserver {
  final Set<String> _handledAlertIds = <String>{};
  StreamSubscription<TurnCompletionAlertRequest>? _completionAlertsSubscription;
  AppLifecycleState? _appLifecycleState;
  bool _showsBackgroundAlert = false;
  bool _isRequestingNotificationPermission = false;
  bool _notificationPermissionDeniedForCurrentForegroundSession = false;
  int _notificationPermissionRequestEpoch = 0;

  bool get _supportsForegroundSignal {
    return widget.supportsForegroundSignal ??
        supportsForegroundTurnCompletionSignal();
  }

  bool get _supportsBackgroundAlerts {
    return widget.supportsBackgroundAlerts ??
        supportsBackgroundTurnCompletionAlerts();
  }

  bool get _isForeground {
    return _appLifecycleState == null ||
        _appLifecycleState == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appLifecycleState = WidgetsBinding.instance.lifecycleState;
    _subscribeToCompletionAlerts();
    _syncCompletionAlertState();
  }

  @override
  void didUpdateWidget(covariant TurnCompletionAlertHost oldWidget) {
    super.didUpdateWidget(oldWidget);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed &&
        _notificationPermissionDeniedForCurrentForegroundSession) {
      _notificationPermissionDeniedForCurrentForegroundSession = false;
    }
    _syncCompletionAlertState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_completionAlertsSubscription?.cancel() ?? Future<void>.value());
    _setWarning(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _subscribeToCompletionAlerts() {
    _completionAlertsSubscription = widget.completionAlerts.listen(
      _handleCompletionAlert,
    );
  }

  void _syncCompletionAlertState() {
    if (_showsBackgroundAlert && (_isForeground || widget.hasActiveTurn)) {
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
    if (!_handledAlertIds.add(alert.id)) {
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
