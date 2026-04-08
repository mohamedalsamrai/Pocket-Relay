import 'remote_runtime_notices_test_support.dart';

void main() {
  testWidgets(
    'live lane shows remote-session-unavailable notice when transport reconnect fails',
    (tester) async {
      final client = FakeCodexAppServerClient();
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await connectAndLoseTransport(client);
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pump();

      expect(find.text('Remote session unavailable'), findsOneWidget);
      expectWarningNotice(tester, 'Remote session unavailable');
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionTransportUnavailable.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Underlying error: connect failed'),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
    },
  );

  testWidgets(
    'live lane clears stale reconnecting chrome once real lane activity resumes after an out-of-band reconnect',
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
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      client.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{
              'id': 'thread_saved',
              'name': 'Saved conversation',
              'source': <String, Object?>{'kind': 'app-server'},
            },
          },
        ),
      );
      await tester.pump();
      await client.disconnect();

      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await tester.pump();
      await tester.pump();
      await controller.flushRecoveryPersistence();

      expect(find.text('Reconnecting to remote session'), findsNothing);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(controller.state.liveReattachPhaseFor('conn_primary'), isNull);
      await controller.flushRecoveryPersistence();
    },
  );
}
