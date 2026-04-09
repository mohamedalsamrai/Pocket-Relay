import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/platform/app_lifecycle_visibility.dart';

import 'remote_runtime_notices_test_support.dart';

void main() {
  testWidgets(
    'live lane auto-dismisses a finished-while-away notice after recovery restores a completed turn from history',
    (tester) async {
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await selectConversationAndLoseTransport(
        controller,
        client,
        'thread_saved',
      );
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.startSessionError = const CodexAppServerException('resume failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Turn finished while you were away'), findsOneWidget);
      expectInformationalNotice(tester, 'Turn finished while you were away');
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.threadHistoryTerminalTurn,
          threadId: 'thread_saved',
          turnId: 'turn_saved',
        ),
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
      );
      expect(find.text('Restored answer'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      await tester.pump();

      expect(find.text('Turn finished while you were away'), findsNothing);
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        isNull,
      );
    },
  );

  testWidgets(
    'live lane keeps the finished-while-away notice visible across background time until foreground dwell elapses',
    (tester) async {
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await selectConversationAndLoseTransport(
        controller,
        client,
        'thread_saved',
      );
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.startSessionError = const CodexAppServerException('resume failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Turn finished while you were away'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.text('Turn finished while you were away'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      await tester.pump();

      expect(find.text('Turn finished while you were away'), findsNothing);
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        isNull,
      );
    },
  );

  testWidgets(
    'live lane notice dismissal follows shared lifecycle visibility scope',
    (tester) async {
      final visibilityListenable = ValueNotifier<AppLifecycleVisibility>(
        AppLifecycleVisibility.background,
      );
      addTearDown(visibilityListenable.dispose);
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await selectConversationAndLoseTransport(
        controller,
        client,
        'thread_saved',
      );
      await pumpScopedRemoteRuntimeNoticesSurface(
        tester,
        controller,
        visibilityListenable,
      );

      client.startSessionError = const CodexAppServerException('resume failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Turn finished while you were away'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(find.text('Turn finished while you were away'), findsOneWidget);

      visibilityListenable.value = AppLifecycleVisibility.foreground;
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      await tester.pump();

      expect(find.text('Turn finished while you were away'), findsNothing);
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        isNull,
      );
    },
  );

  testWidgets(
    'live lane keeps the finished-while-away notice visible while the lane is hidden offscreen',
    (tester) async {
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await selectConversationAndLoseTransport(
        controller,
        client,
        'thread_saved',
      );
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.startSessionError = const CodexAppServerException('resume failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Turn finished while you were away'), findsOneWidget);

      controller.showSavedConnections();
      await tester.pump();
      await tester.pump(const Duration(seconds: 30));

      controller.selectConnection('conn_primary');
      await tester.pump();

      expect(find.text('Turn finished while you were away'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      await tester.pump();

      expect(find.text('Turn finished while you were away'), findsNothing);
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        isNull,
      );
    },
  );
}
