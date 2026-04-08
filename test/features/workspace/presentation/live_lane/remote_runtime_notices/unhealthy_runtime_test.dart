import 'remote_runtime_notices_test_support.dart';

void main() {
  testWidgets(
    'live lane shows remote-server-stopped notice when transport reconnect cannot attach to the managed owner',
    (tester) async {
      final client = FakeCodexAppServerClient();
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await connectAndLoseTransport(client);
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.connectError = const CodexRemoteAppServerAttachException(
        snapshot: CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.stopped,
          sessionName: 'pocket-relay-conn_primary',
          detail: 'Managed remote app-server is not running.',
        ),
        message: 'Managed remote app-server is not running.',
      );
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote server stopped'), findsOneWidget);
      expectWarningNotice(tester, 'Remote server stopped');
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
    'live lane shows remote-server-unhealthy notice when transport reconnect cannot attach to an unhealthy managed owner',
    (tester) async {
      final client = FakeCodexAppServerClient();
      final controller = buildSingleConnectionWorkspaceController(
        client: client,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await connectAndLoseTransport(client);
      await pumpRemoteRuntimeNoticesSurface(tester, controller);

      client.connectError = const CodexRemoteAppServerAttachException(
        snapshot: CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.unhealthy,
          sessionName: 'pocket-relay-conn_primary',
          endpoint: CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
          detail: 'readyz failed',
        ),
        message: 'readyz failed',
      );
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote server unhealthy'), findsOneWidget);
      expectWarningNotice(tester, 'Remote server unhealthy');
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionReconnectServerUnhealthy.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('readyz failed'), findsWidgets);
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
}
