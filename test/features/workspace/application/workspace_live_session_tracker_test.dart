import 'package:pocket_relay/src/features/workspace/application/workspace_live_session_tracker.dart';

import 'controller/controller_test_support.dart';

void main() {
  test(
    'live session tracker follows workspace lanes and session changes',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile(
              'Primary Box',
              'primary.local',
            ).copyWith(workspaceDir: '/workspace'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile(
              'Secondary Box',
              'secondary.local',
            ).copyWith(workspaceDir: '/workspace'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      WorkspaceLiveSessionTracker? tracker;
      addTearDown(() async {
        tracker?.dispose();
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      tracker = WorkspaceLiveSessionTracker(controller);
      var notificationCount = 0;
      tracker.addListener(() {
        notificationCount += 1;
      });

      expect(
        tracker.sessionControllersByLaneId.keys,
        controller.state.liveLaneIds,
      );

      final notificationsBeforePrompt = notificationCount;
      final primaryBinding = controller.bindingForConnectionId('conn_primary')!;
      expect(
        await primaryBinding.sessionController.sendPrompt('Keep tracking'),
        isTrue,
      );

      expect(notificationCount, greaterThan(notificationsBeforePrompt));

      clientsById['conn_primary']!.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );

      await controller.instantiateConnection('conn_secondary');

      expect(
        tracker.sessionControllersByLaneId.keys,
        controller.state.liveLaneIds,
      );

      controller.terminateConnection('conn_secondary');

      expect(
        tracker.sessionControllersByLaneId.keys,
        controller.state.liveLaneIds,
      );
    },
  );
}
