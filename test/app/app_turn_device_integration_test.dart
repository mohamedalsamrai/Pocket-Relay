import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';

import '../support/builders/app_test_harness.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'keeps the display awake only while a turn is actively ticking',
    (tester) async {
      final controller = FakeDisplayWakeLockController();
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(
          displayWakeLockController: controller,
          agentAdapterClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.enabledStates, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Keep the screen awake while this runs',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(controller.enabledStates, <bool>[true]);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.enabledStates, <bool>[true, false]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'requests permission on iPhone and posts a background completion alert',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      final permissionController = _FakeNotificationPermissionController(
        isGrantedValue: false,
        requestPermissionValue: true,
      );
      final alertController = _FakeTurnCompletionAlertController();
      addTearDown(() async {
        await _restoreForegroundLifecycle(tester);
      });
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(
          notificationPermissionController: permissionController,
          turnCompletionAlertController: alertController,
          agentAdapterClient: appServerClient,
          platformPolicy: PocketPlatformPolicy.resolve(
            platform: TargetPlatform.iOS,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Tell me when this is done',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(permissionController.requestCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(alertController.backgroundAlerts, hasLength(1));
      expect(
        alertController.backgroundAlerts.single.body,
        'Dev Box is ready to review.',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'disposes the active lane when the top-level app shell unmounts',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(agentAdapterClient: appServerClient),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(appServerClient.disconnectCalls, 1);
    },
  );
}

class _FakeTurnCompletionAlertController
    implements TurnCompletionAlertController {
  final List<({String title, String? body})> backgroundAlerts =
      <({String title, String? body})>[];

  @override
  Future<void> clearBackgroundAlert() async {}

  @override
  Future<void> emitForegroundSignal() async {}

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

Future<void> _restoreForegroundLifecycle(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
}
