import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';

void main() {
  testWidgets('emits a foreground signal when a turn completes while resumed', (
    tester,
  ) async {
    final completionAlerts = StreamController<TurnCompletionAlertRequest>();
    final controller = _FakeTurnCompletionAlertController();
    final permissionController = _FakeNotificationPermissionController();
    addTearDown(completionAlerts.close);

    await tester.pumpWidget(
      MaterialApp(
        home: TurnCompletionAlertHost(
          completionAlerts: completionAlerts.stream,
          hasActiveTurn: false,
          turnCompletionAlertController: controller,
          notificationPermissionController: permissionController,
          supportsForegroundSignal: true,
          supportsBackgroundAlerts: true,
          child: const SizedBox(),
        ),
      ),
    );

    completionAlerts.add(
      const TurnCompletionAlertRequest(
        id: 'conn_primary:turn_1',
        title: 'Turn completed',
      ),
    );
    await tester.pump();

    expect(controller.foregroundSignals, 1);
    expect(controller.backgroundAlerts, isEmpty);
  });

  testWidgets(
    'posts one background alert and ignores duplicate turn completions',
    (tester) async {
      final completionAlerts = StreamController<TurnCompletionAlertRequest>();
      final controller = _FakeTurnCompletionAlertController();
      final permissionController = _FakeNotificationPermissionController();
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      addTearDown(completionAlerts.close);

      await tester.pumpWidget(
        MaterialApp(
          home: TurnCompletionAlertHost(
            completionAlerts: completionAlerts.stream,
            hasActiveTurn: false,
            turnCompletionAlertController: controller,
            notificationPermissionController: permissionController,
            supportsForegroundSignal: true,
            supportsBackgroundAlerts: true,
            child: const SizedBox(),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      const request = TurnCompletionAlertRequest(
        id: 'conn_primary:turn_1',
        title: 'Turn completed',
        body: 'Primary Box is ready to review.',
      );
      completionAlerts
        ..add(request)
        ..add(request);
      await tester.pump();

      expect(controller.foregroundSignals, 0);
      expect(controller.backgroundAlerts, hasLength(1));
      expect(controller.backgroundAlerts.single.title, 'Turn completed');
      expect(
        controller.backgroundAlerts.single.body,
        'Primary Box is ready to review.',
      );
    },
  );

  testWidgets(
    'requests notification permission while a foreground turn is active',
    (tester) async {
      final completionAlerts = StreamController<TurnCompletionAlertRequest>();
      final controller = _FakeTurnCompletionAlertController();
      final permissionController = _FakeNotificationPermissionController(
        isGrantedValue: false,
        requestPermissionValue: true,
      );
      addTearDown(completionAlerts.close);

      await tester.pumpWidget(
        MaterialApp(
          home: TurnCompletionAlertHost(
            completionAlerts: completionAlerts.stream,
            hasActiveTurn: false,
            turnCompletionAlertController: controller,
            notificationPermissionController: permissionController,
            supportsForegroundSignal: true,
            supportsBackgroundAlerts: true,
            requestNotificationPermissionWhileForegrounded: true,
            child: const SizedBox(),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TurnCompletionAlertHost(
            completionAlerts: completionAlerts.stream,
            hasActiveTurn: true,
            turnCompletionAlertController: controller,
            notificationPermissionController: permissionController,
            supportsForegroundSignal: true,
            supportsBackgroundAlerts: true,
            requestNotificationPermissionWhileForegrounded: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      expect(permissionController.requestCalls, 1);
    },
  );

  testWidgets(
    'clears a stale background alert when the app returns to the foreground',
    (tester) async {
      final completionAlerts = StreamController<TurnCompletionAlertRequest>();
      final controller = _FakeTurnCompletionAlertController();
      final permissionController = _FakeNotificationPermissionController();
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      addTearDown(completionAlerts.close);

      await tester.pumpWidget(
        MaterialApp(
          home: TurnCompletionAlertHost(
            completionAlerts: completionAlerts.stream,
            hasActiveTurn: false,
            turnCompletionAlertController: controller,
            notificationPermissionController: permissionController,
            supportsForegroundSignal: true,
            supportsBackgroundAlerts: true,
            child: const SizedBox(),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      completionAlerts.add(
        const TurnCompletionAlertRequest(
          id: 'conn_primary:turn_1',
          title: 'Turn completed',
        ),
      );
      await tester.pump();
      expect(controller.backgroundAlerts, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controller.clearCalls, 1);
    },
  );

  testWidgets(
    'keeps a background alert while another turn is still active in the background',
    (tester) async {
      final completionAlerts = StreamController<TurnCompletionAlertRequest>();
      final controller = _FakeTurnCompletionAlertController();
      final permissionController = _FakeNotificationPermissionController();
      addTearDown(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      });
      addTearDown(completionAlerts.close);

      await tester.pumpWidget(
        MaterialApp(
          home: TurnCompletionAlertHost(
            completionAlerts: completionAlerts.stream,
            hasActiveTurn: false,
            turnCompletionAlertController: controller,
            notificationPermissionController: permissionController,
            supportsForegroundSignal: true,
            supportsBackgroundAlerts: true,
            child: const SizedBox(),
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      completionAlerts.add(
        const TurnCompletionAlertRequest(
          id: 'conn_primary:turn_1',
          title: 'Turn completed',
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          home: TurnCompletionAlertHost(
            completionAlerts: completionAlerts.stream,
            hasActiveTurn: true,
            turnCompletionAlertController: controller,
            notificationPermissionController: permissionController,
            supportsForegroundSignal: true,
            supportsBackgroundAlerts: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pump();

      expect(controller.backgroundAlerts, hasLength(1));
      expect(controller.clearCalls, 0);
    },
  );

  testWidgets('prunes old handled alert ids with a bounded cache', (
    tester,
  ) async {
    final completionAlerts = StreamController<TurnCompletionAlertRequest>();
    final controller = _FakeTurnCompletionAlertController();
    final permissionController = _FakeNotificationPermissionController();
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    addTearDown(completionAlerts.close);

    await tester.pumpWidget(
      MaterialApp(
        home: TurnCompletionAlertHost(
          completionAlerts: completionAlerts.stream,
          hasActiveTurn: false,
          turnCompletionAlertController: controller,
          notificationPermissionController: permissionController,
          supportsForegroundSignal: true,
          supportsBackgroundAlerts: true,
          child: const SizedBox(),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    for (var index = 0; index < 51; index++) {
      completionAlerts.add(
        TurnCompletionAlertRequest(
          id: 'conn_primary:turn_$index',
          title: 'Turn completed',
        ),
      );
    }
    await tester.pump();

    completionAlerts.add(
      const TurnCompletionAlertRequest(
        id: 'conn_primary:turn_0',
        title: 'Turn completed',
      ),
    );
    await tester.pump();

    expect(controller.backgroundAlerts, hasLength(52));
  });

  testWidgets('falls back safely when notification permission is denied', (
    tester,
  ) async {
    final completionAlerts = StreamController<TurnCompletionAlertRequest>();
    final controller = _FakeTurnCompletionAlertController();
    final permissionController = _FakeNotificationPermissionController(
      isGrantedValue: false,
    );
    PocketUserFacingError? warning;
    addTearDown(() {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    addTearDown(completionAlerts.close);

    await tester.pumpWidget(
      MaterialApp(
        home: TurnCompletionAlertHost(
          completionAlerts: completionAlerts.stream,
          hasActiveTurn: false,
          turnCompletionAlertController: controller,
          notificationPermissionController: permissionController,
          supportsForegroundSignal: true,
          supportsBackgroundAlerts: true,
          onWarningChanged: (value) => warning = value,
          child: const SizedBox(),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    completionAlerts.add(
      const TurnCompletionAlertRequest(
        id: 'conn_primary:turn_1',
        title: 'Turn completed',
      ),
    );
    await tester.pump();

    expect(controller.backgroundAlerts, isEmpty);
    expect(warning, isNull);
  });
}

class _FakeTurnCompletionAlertController
    implements TurnCompletionAlertController {
  final List<({String title, String? body})> backgroundAlerts =
      <({String title, String? body})>[];
  int foregroundSignals = 0;
  int clearCalls = 0;

  @override
  Future<void> clearBackgroundAlert() async {
    clearCalls += 1;
  }

  @override
  Future<void> emitForegroundSignal() async {
    foregroundSignals += 1;
  }

  @override
  Future<void> showBackgroundAlert({
    required String title,
    String? body,
  }) async {
    backgroundAlerts.add((title: title, body: body));
  }
}

class _FakeNotificationPermissionController
    implements NotificationPermissionController {
  _FakeNotificationPermissionController({
    this.isGrantedValue = true,
    this.requestPermissionValue = true,
  });

  bool isGrantedValue;
  bool requestPermissionValue;
  int requestCalls = 0;

  @override
  Future<bool> isGranted() async => isGrantedValue;

  @override
  Future<bool> requestPermission() async {
    requestCalls += 1;
    isGrantedValue = requestPermissionValue;
    return requestPermissionValue;
  }
}
