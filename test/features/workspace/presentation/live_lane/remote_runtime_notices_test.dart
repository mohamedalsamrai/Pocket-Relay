import '../support/workspace_surface_test_support.dart';

void _expectInformationalNotice(WidgetTester tester, String title) {
  final theme = Theme.of(tester.element(find.text(title)));
  final decoration = _noticeDecorationFor(tester, title);

  expect(
    decoration.color,
    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.94),
  );
  expect(
    (decoration.border! as Border).top.color,
    theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
  );
}

void _expectWarningNotice(WidgetTester tester, String title) {
  final theme = Theme.of(tester.element(find.text(title)));
  final decoration = _noticeDecorationFor(tester, title);

  expect(
    decoration.color,
    theme.colorScheme.secondaryContainer.withValues(alpha: 0.94),
  );
  expect(
    (decoration.border! as Border).top.color,
    theme.colorScheme.secondary.withValues(alpha: 0.22),
  );
}

BoxDecoration _noticeDecorationFor(WidgetTester tester, String title) {
  final noticeDecoratedBox = find
      .ancestor(
        of: find.text(title),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) {
            return false;
          }
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.borderRadius == BorderRadius.circular(20);
        }),
      )
      .evaluate()
      .map((element) => element.widget)
      .whereType<DecoratedBox>()
      .first;

  return noticeDecoratedBox.decoration as BoxDecoration;
}

void main() {
  testWidgets(
    'live lane shows remote-session-unavailable notice when transport reconnect fails',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pump();

      expect(find.text('Remote session unavailable'), findsOneWidget);
      _expectWarningNotice(tester, 'Remote session unavailable');
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
    'live lane shows same-live-turn notice when reconnect proves the turn is still active',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = _savedConversationThread(
        threadId: 'thread_saved',
      );
      client.resumeThreadReplayEventsByThreadId['thread_saved'] =
          const <CodexAppServerEvent>[
            CodexAppServerNotificationEvent(
              method: 'turn/started',
              params: <String, Object?>{
                'threadId': 'thread_saved',
                'turn': <String, Object?>{
                  'id': 'turn_live',
                  'status': 'running',
                  'model': 'gpt-5.4',
                  'effort': 'high',
                },
              },
            ),
          ];
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.selectedLaneBinding!.sessionController
          .selectConversationForResume('thread_saved');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Same live turn is still running'), findsOneWidget);
      _expectInformationalNotice(tester, 'Same live turn is still running');
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.activeTurnReattached,
          threadId: 'thread_saved',
          turnId: 'turn_live',
        ),
      );
    },
  );

  testWidgets(
    'live lane treats inProgress history status as the same live turn after reconnect',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] =
          _conversationThreadWithStatus(
            threadId: 'thread_saved',
            turnId: 'turn_live',
            status: 'inProgress',
          );
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.selectedLaneBinding!.sessionController
          .selectConversationForResume('thread_saved');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Same live turn is still running'), findsOneWidget);
      _expectInformationalNotice(tester, 'Same live turn is still running');
      expect(
        controller.state.turnLivenessAssessmentFor('conn_primary'),
        const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.threadHistoryRunningTurn,
          threadId: 'thread_saved',
          turnId: 'turn_live',
        ),
      );
    },
  );

  testWidgets(
    'live lane auto-dismisses a finished-while-away notice after recovery restores a completed turn from history',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = _savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.selectedLaneBinding!.sessionController
          .selectConversationForResume('thread_saved');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.startSessionError = const CodexAppServerException('resume failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Turn finished while you were away'), findsOneWidget);
      _expectInformationalNotice(tester, 'Turn finished while you were away');
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
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = _savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.selectedLaneBinding!.sessionController
          .selectConversationForResume('thread_saved');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

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
    'live lane keeps the finished-while-away notice visible while the lane is hidden offscreen',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = _savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.selectedLaneBinding!.sessionController
          .selectConversationForResume('thread_saved');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

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

  testWidgets(
    'live lane clears stale reconnecting chrome once real lane activity resumes after an out-of-band reconnect',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] = _savedConversationThread(
        threadId: 'thread_saved',
      );
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
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

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

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

  testWidgets(
    'live lane shows a continuity-lost notice when live reattach fails and history cannot prove the turn finished',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_123'] =
          const CodexAppServerThreadHistory(
            id: 'thread_123',
            sourceKind: 'app-server',
          );
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryPersistenceDebounceDuration: Duration.zero,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
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

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

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
      _expectWarningNotice(tester, 'Live turn continuity was lost');
    },
  );

  testWidgets(
    'live lane shows an unverifiable-liveness notice when reconnect succeeds without enough upstream evidence',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      client.threadHistoriesById['thread_saved'] =
          _inconclusiveConversationThread(threadId: 'thread_saved');
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.selectedLaneBinding!.sessionController
          .selectConversationForResume('thread_saved');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(
        find.text('Live turn status could not be verified'),
        findsOneWidget,
      );
      _expectWarningNotice(tester, 'Live turn status could not be verified');
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
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.tmuxMissing,
            },
            detail: 'tmux is not installed on this host.',
          ),
        ),
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      _expectWarningNotice(tester, 'Remote continuity unavailable');
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
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        remoteAppServerHostProbe: const ThrowingRemoteHostProbe(
          'ssh probe failed',
        ),
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      _expectWarningNotice(tester, 'Remote continuity unavailable');
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

  testWidgets(
    'live lane shows remote-server-stopped notice when transport reconnect cannot attach to the managed owner',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

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
      _expectWarningNotice(tester, 'Remote server stopped');
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
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

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
      _expectWarningNotice(tester, 'Remote server unhealthy');
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

CodexAppServerThreadHistory _savedConversationThread({
  required String threadId,
}) {
  return _conversationThreadWithStatus(
    threadId: threadId,
    turnId: 'turn_saved',
    status: 'completed',
  );
}

CodexAppServerThreadHistory _inconclusiveConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_unknown',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_unknown',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory _conversationThreadWithStatus({
  required String threadId,
  required String turnId,
  required String status,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: turnId,
        status: status,
        items: const <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': turnId,
          'status': status,
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}
