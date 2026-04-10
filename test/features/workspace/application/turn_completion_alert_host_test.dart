import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_device_continuity_warnings.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_activity_builder.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_completion_alert_host.dart';

void main() {
  testWidgets(
    'maps a live lane completion into a privacy-conscious background alert',
    (tester) async {
      final clientsById = _buildClientsById(firstConnectionId: 'conn_primary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final alertController = _FakeTurnCompletionAlertController();
      final permissionController = _FakeNotificationPermissionController();
      addTearDown(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceTurnActivityBuilder(
            workspaceController: controller,
            builder: (context, hasActiveTurn) {
              return WorkspaceTurnCompletionAlertHost(
                workspaceController: controller,
                hasActiveTurn: hasActiveTurn,
                onWarningChanged: _warningSink(
                  controller,
                  WorkspaceDeviceContinuityWarningTarget.turnCompletionAlert,
                ),
                turnCompletionAlertController: alertController,
                notificationPermissionController: permissionController,
                supportsForegroundSignal: true,
                supportsBackgroundAlerts: true,
                child: const SizedBox(),
              );
            },
          ),
        ),
      );
      await tester.pump();

      final laneBinding = controller.selectedLaneBinding!;
      expect(
        await laneBinding.sessionController.sendPrompt(
          'Notify me when this finishes',
        ),
        isTrue,
      );
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      clientsById['conn_primary']!.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pump();

      expect(alertController.backgroundAlerts, hasLength(1));
      expect(alertController.backgroundAlerts.single.title, 'Turn completed');
      expect(
        alertController.backgroundAlerts.single.body,
        'Primary Box is ready to review.',
      );
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets(
    'keeps foreground notification denial latched across foreground rebuilds',
    (tester) async {
      final visibility = ValueNotifier<AppLifecycleVisibility>(
        AppLifecycleVisibility.foreground,
      );
      final completionAlerts = StreamController<TurnCompletionAlertRequest>();
      final alertController = _FakeTurnCompletionAlertController();
      final permissionController = _FakeNotificationPermissionController(
        isGrantedResult: false,
        requestPermissionResult: false,
      );
      addTearDown(() async {
        visibility.dispose();
        await completionAlerts.close();
      });

      Future<void> pumpHost({required Key childKey}) {
        return tester.pumpWidget(
          MaterialApp(
            home: TurnCompletionAlertHost(
              completionAlerts: completionAlerts.stream,
              hasActiveTurn: true,
              turnCompletionAlertController: alertController,
              notificationPermissionController: permissionController,
              supportsForegroundSignal: true,
              supportsBackgroundAlerts: true,
              requestNotificationPermissionWhileForegrounded: true,
              appLifecycleVisibilityListenable: visibility,
              child: SizedBox(key: childKey),
            ),
          ),
        );
      }

      await pumpHost(childKey: const ValueKey<String>('first'));
      await tester.pump();

      expect(permissionController.requestPermissionCalls, 1);

      await pumpHost(childKey: const ValueKey<String>('rebuilt'));
      await tester.pump();

      expect(permissionController.requestPermissionCalls, 1);

      visibility.value = AppLifecycleVisibility.background;
      await tester.pump();
      visibility.value = AppLifecycleVisibility.foreground;
      await tester.pump();

      expect(permissionController.requestPermissionCalls, 2);
    },
  );
}

WorkspaceDeviceContinuityWarningChanged _warningSink(
  ConnectionWorkspaceController controller,
  WorkspaceDeviceContinuityWarningTarget target,
) {
  return (warning) => controller.setDeviceContinuityWarning(target, warning);
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
}) {
  final resolvedRepository =
      repository ??
      MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    laneBindingFactory:
        ({required laneId, required connectionId, required connection}) {
          final appServerClient = clientsById[connectionId]!;
          return ConnectionLaneBinding(
            laneId: laneId,
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: resolvedRepository,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
  );
}

ConnectionProfile _profile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

Map<String, FakeCodexAppServerClient> _buildClientsById({
  required String firstConnectionId,
}) {
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    client.dispose();
  }
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
    this.isGrantedResult = true,
    this.requestPermissionResult = true,
  });

  final bool isGrantedResult;
  final bool requestPermissionResult;
  int isGrantedCalls = 0;
  int requestPermissionCalls = 0;

  @override
  Future<bool> isGranted() async {
    isGrantedCalls += 1;
    return isGrantedResult;
  }

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalls += 1;
    return requestPermissionResult;
  }
}
