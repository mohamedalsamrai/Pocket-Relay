import 'mobile_shell_test_support.dart';

void main() {
  testWidgets('swiping past the live lane reveals the dormant roster', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workspaces'), findsWidgets);
    expect(
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_primary');
  });

  testWidgets('overflow menu opens the dormant roster page', (tester) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workspaces'));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(
      find.byKey(const ValueKey('saved_connections_page')),
      findsOneWidget,
    );
  });

  testWidgets('swiping again after workspaces reveals the systems page', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(controller.state.isShowingSavedSystems, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(find.byKey(const ValueKey('saved_systems_page')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_system')), findsOneWidget);
    expect(find.text('Systems'), findsWidgets);
  });

  testWidgets('systems page shows fingerprint trust state only once', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final repository = MemoryCodexConnectionRepository(
      initialConnections: <SavedConnection>[
        SavedConnection(
          id: 'conn_primary',
          profile: workspaceProfile(
            'Primary Box',
            'primary.local',
          ).copyWith(hostFingerprint: 'SHA256:primary'),
          secrets: const ConnectionSecrets(password: 'secret-1'),
        ),
        SavedConnection(
          id: 'conn_secondary',
          profile: workspaceProfile('Secondary Box', 'secondary.local'),
          secrets: const ConnectionSecrets(password: 'secret-2'),
        ),
      ],
      initialSystems: <SavedSystem>[
        const SavedSystem(
          id: 'system_primary',
          profile: SystemProfile(
            label: 'Primary Build Box',
            host: 'primary.local',
            port: 22,
            username: 'vince',
            authMode: AuthMode.password,
            hostFingerprint: 'SHA256:primary',
          ),
          secrets: ConnectionSecrets(password: 'secret-1'),
        ),
      ],
    );
    final controller = buildWorkspaceController(
      clientsById: clientsById,
      repository: repository,
    );
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Primary Build Box'), findsOneWidget);
    expect(
      find.text('vince@primary.local · Password sign-in · Fingerprint saved'),
      findsOneWidget,
    );
    expect(find.text('Fingerprint saved'), findsNothing);
  });

  testWidgets('systems rows span the full content width', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    final systemIds = controller.state.systemCatalog.orderedSystemIds;
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    final expectedWidth = 430.0 - 32.0;
    final firstWidth = tester
        .getSize(
          find.byKey(ValueKey<String>('saved_system_${systemIds.first}')),
        )
        .width;
    final secondWidth = tester
        .getSize(find.byKey(ValueKey<String>('saved_system_${systemIds.last}')))
        .width;

    expect(firstWidth, moreOrLessEquals(expectedWidth, epsilon: 0.1));
    expect(secondWidth, moreOrLessEquals(expectedWidth, epsilon: 0.1));
  });

  testWidgets(
    'system compatibility moves from workspace rows to the systems page',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: MemoryCodexConnectionRepository(
          initialConnections: <SavedConnection>[
            SavedConnection(
              id: 'conn_primary',
              profile: workspaceProfile('Primary Box', 'primary.local'),
              secrets: const ConnectionSecrets(password: 'secret-1'),
            ),
            SavedConnection(
              id: 'conn_secondary',
              profile: workspaceProfile('Secondary Box', 'secondary.local'),
              secrets: const ConnectionSecrets(password: 'secret-2'),
            ),
          ],
        ),
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.remoteContinuityUnsupported,
            },
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final systemId = controller.state.systemCatalog.orderedSystemIds.first;
      await tester.pumpWidget(buildShell(controller));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('workspace_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      final workspaceRow = find.byKey(
        const ValueKey('saved_connection_conn_primary'),
      );
      expect(
        find.descendant(
          of: workspaceRow,
          matching: find.textContaining('System:'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: workspaceRow,
          matching: find.text('System unsupported'),
        ),
        findsNothing,
      );

      await tester.drag(
        find.byKey(const ValueKey('workspace_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(ValueKey<String>('saved_system_$systemId')),
          matching: find.text('System unsupported'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'system deletion failures show a friendly message on the systems page',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final systemId = controller.state.systemCatalog.orderedSystemIds.first;
      await tester.pumpWidget(buildShell(controller));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('workspace_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('workspace_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ValueKey<String>('delete_system_$systemId')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not delete system. Cannot delete a system that is still used by a workspace.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Bad state:'), findsNothing);
    },
  );
}
