import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';

void main() {
  testWidgets('tracks keep-alive state and releases the foreground service', (
    tester,
  ) async {
    final controller = _FakeForegroundServiceController();
    final permissionController = _FakeNotificationPermissionController();

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundServiceHost(
          foregroundServiceController: controller,
          notificationPermissionController: permissionController,
          supportsForegroundService: true,
          child: const SizedBox(),
        ),
      ),
    );

    expect(controller.enabledStates, <bool>[true]);

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundServiceHost(
          foregroundServiceController: controller,
          notificationPermissionController: permissionController,
          supportsForegroundService: true,
          keepForegroundServiceRunning: false,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(controller.enabledStates, <bool>[true, false]);
  });

  testWidgets('stays inert when foreground service support is unavailable', (
    tester,
  ) async {
    final controller = _FakeForegroundServiceController();
    final permissionController = _FakeNotificationPermissionController();

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundServiceHost(
          foregroundServiceController: controller,
          notificationPermissionController: permissionController,
          supportsForegroundService: false,
          child: const SizedBox(),
        ),
      ),
    );

    expect(controller.enabledStates, isEmpty);
  });

  testWidgets('requests notification permission before enabling the service', (
    tester,
  ) async {
    final controller = _FakeForegroundServiceController();
    final permissionController = _FakeNotificationPermissionController(
      isGrantedValue: false,
      requestPermissionValue: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForegroundServiceHost(
          foregroundServiceController: controller,
          notificationPermissionController: permissionController,
          supportsForegroundService: true,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(permissionController.requestCalls, 1);
    expect(controller.enabledStates, <bool>[true]);
  });

  testWidgets(
    'does not enable the service when notification permission is denied',
    (tester) async {
      final controller = _FakeForegroundServiceController();
      final permissionController = _FakeNotificationPermissionController(
        isGrantedValue: false,
        requestPermissionValue: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ForegroundServiceHost(
            foregroundServiceController: controller,
            notificationPermissionController: permissionController,
            supportsForegroundService: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      expect(permissionController.requestCalls, 1);
      expect(controller.enabledStates, isEmpty);
    },
  );
}

class _FakeForegroundServiceController implements ForegroundServiceController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}

class _FakeNotificationPermissionController
    implements NotificationPermissionController {
  _FakeNotificationPermissionController({
    this.isGrantedValue = true,
    this.requestPermissionValue = true,
  });

  final bool isGrantedValue;
  final bool requestPermissionValue;
  int requestCalls = 0;

  @override
  Future<bool> isGranted() async => isGrantedValue;

  @override
  Future<bool> requestPermission() async {
    requestCalls += 1;
    return requestPermissionValue;
  }
}
