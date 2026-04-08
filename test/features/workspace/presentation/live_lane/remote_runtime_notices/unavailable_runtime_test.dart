import 'remote_runtime_notices_test_support.dart';

void main() {
  testWidgets(
    'live lane shows a continuity-lost notice when live reattach fails and history cannot prove the turn finished',
    (tester) async {
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_123'] =
          const CodexAppServerThreadHistory(
            id: 'thread_123',
            sourceKind: 'app-server',
          );
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      client.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{'id': 'thread_123'},
          },
        ),
      );
      client.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{
              'id': 'turn_running',
              'status': 'running',
              'model': 'gpt-5.4',
              'effort': 'high',
            },
          },
        ),
      );
      await tester.pump();
      await client.disconnect();

      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.startSessionError = const CodexAppServerException('resume failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.continuityLost,
          evidence: ConnectionWorkspaceTurnLivenessEvidence.liveReattachFailed,
          threadId: 'thread_123',
        ),
      );
      expect(find.text('Live turn continuity was lost'), findsOneWidget);
      expectWarningNotice(tester, 'Live turn continuity was lost');
      await controller.flushRecoveryPersistence();
    },
  );

  testWidgets(
    'live lane shows an unverifiable-liveness notice when reconnect succeeds without enough upstream evidence',
    (tester) async {
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] =
          inconclusiveConversationThread(threadId: 'thread_saved');
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
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

      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(
        find.text('Live turn status could not be verified'),
        findsOneWidget,
      );
      expectWarningNotice(tester, 'Live turn status could not be verified');
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.unknown,
          evidence: ConnectionWorkspaceTurnLivenessEvidence.adapterUnverifiable,
          threadId: 'thread_saved',
          turnId: 'turn_unknown',
        ),
      );
    },
  );

  testWidgets(
    'live lane shows remote-continuity-unavailable notice when the host lacks required continuity support',
    (tester) async {
      final client = FakeCodexAppServerClient();
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.tmuxMissing,
            },
            detail: 'tmux is not installed on this host.',
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await connectAndLoseTransport(client);

      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      expectWarningNotice(tester, 'Remote continuity unavailable');
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionReconnectContinuityUnsupported.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('tmux is not installed on this host.'),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
    },
  );

  testWidgets(
    'live lane shows remote-continuity-unavailable notice when host capability probing fails',
    (tester) async {
      final client = FakeCodexAppServerClient();
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        remoteAppServerHostProbe: const ThrowingRemoteHostProbe(
          'ssh probe failed',
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await connectAndLoseTransport(client);

      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      expectWarningNotice(tester, 'Remote continuity unavailable');
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionRuntimeProbeFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('ssh probe failed'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
    },
  );
}
