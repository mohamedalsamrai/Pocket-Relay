import '../controller_test_support.dart';

void main() {
  test(
    'failed recovery persistence keeps the latest selected thread as unsaved state',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = ToggleableFailingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_stale',
          draftText: '',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      recoveryStore.saveError = StateError('secure storage write failed');

      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.debugLatestUnsavedRecoveryState?.selectedThreadId,
        'thread_saved',
      );
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_stale');
    },
  );

  test(
    'selected lane recovery persistence failures are recorded in recovery diagnostics',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final snapshotTime = DateTime(2026, 3, 27, 14, 10);
      final recoveryStore = ToggleableFailingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
        saveError: StateError('secure storage write failed'),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      binding.restoreComposerDraft('Draft that should persist');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.attemptedStates, hasLength(1));
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnostics, isNotNull);
      expect(
        diagnostics!.lastRecoveryPersistenceFailureAt,
        snapshotTime.toUtc(),
      );
      expect(
        diagnostics.lastRecoveryPersistenceFailureDetail,
        'secure storage write failed',
      );
      expect(await recoveryStore.load(), recoveryStore.initialState);
    },
  );

  test(
    'selected lane recovery persistence clears stale failure detail after a later successful save',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final snapshotTime = DateTime(2026, 3, 27, 14, 20);
      final recoveryStore = ToggleableFailingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
        saveError: StateError('secure storage write failed'),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      binding.restoreComposerDraft('Failed draft');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      final diagnosticsAfterFailure = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(
        diagnosticsAfterFailure?.lastRecoveryPersistenceFailureDetail,
        'secure storage write failed',
      );

      recoveryStore.saveError = null;
      binding.restoreComposerDraft('Recovered draft');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.attemptedStates, hasLength(2));
      final diagnosticsAfterSuccess = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnosticsAfterSuccess, isNotNull);
      expect(diagnosticsAfterSuccess!.lastRecoveryPersistenceFailureAt, isNull);
      expect(
        diagnosticsAfterSuccess.lastRecoveryPersistenceFailureDetail,
        isNull,
      );
      expect(
        await recoveryStore.load(),
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: 'Recovered draft',
        ),
      );
    },
  );
}
