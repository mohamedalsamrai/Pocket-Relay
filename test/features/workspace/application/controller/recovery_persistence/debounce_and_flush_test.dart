import '../controller_test_support.dart';

void main() {
  test(
    'selected lane draft bursts debounce into one persisted recovery snapshot',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final recoveryStore = RecordingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      recoveryStore.savedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      binding.restoreComposerDraft('D');
      binding.restoreComposerDraft('Dr');
      binding.restoreComposerDraft('Draft');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.savedStates, hasLength(1));
      expect(recoveryStore.savedStates.single?.draftText, 'Draft');
      expect(recoveryStore.savedStates.single?.connectionId, 'conn_primary');
    },
  );

  test('dispose flushes a pending debounced recovery snapshot', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final recoveryStore = RecordingConnectionWorkspaceRecoveryStore(
      initialState: const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        draftText: '',
      ),
    );
    final controller = buildWorkspaceController(
      clientsById: clientsById,
      recoveryStore: recoveryStore,
      recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
    );
    addTearDown(() async {
      await closeClients(clientsById);
    });

    await controller.initialize();
    recoveryStore.savedStates.clear();
    final binding = controller.bindingForConnectionId('conn_primary')!;

    binding.restoreComposerDraft('Pending draft');
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(recoveryStore.savedStates, isNotEmpty);
    expect(recoveryStore.savedStates.last?.connectionId, 'conn_primary');
    expect(recoveryStore.savedStates.last?.draftText, 'Pending draft');
  });

  test(
    'selected lane thread changes persist immediately without waiting for debounce',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = RecordingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
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
      recoveryStore.savedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.savedStates, isNotEmpty);
      expect(recoveryStore.savedStates.last?.connectionId, 'conn_primary');
      expect(recoveryStore.savedStates.last?.selectedThreadId, 'thread_saved');
    },
  );

  test(
    'selected lane thread reversion during an in-flight save still persists the reverted snapshot',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_a'] =
          savedConversationThread(threadId: 'thread_a');
      clientsById['conn_primary']!.threadHistoriesById['thread_b'] =
          savedConversationThread(threadId: 'thread_b');
      final recoveryStore = DelayedFirstSaveConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_a',
          draftText: '',
        ),
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
      );
      addTearDown(() async {
        if (!recoveryStore.firstSaveCompleter.isCompleted) {
          recoveryStore.firstSaveCompleter.complete();
        }
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      recoveryStore.attemptedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      await binding.sessionController.selectConversationForResume('thread_b');
      await Future<void>.delayed(Duration.zero);
      await binding.sessionController.selectConversationForResume('thread_a');
      await Future<void>.delayed(Duration.zero);

      recoveryStore.firstSaveCompleter.complete();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.attemptedStates, isNotEmpty);
      expect(recoveryStore.attemptedStates.last?.selectedThreadId, 'thread_a');
      expect((await recoveryStore.load())?.selectedThreadId, 'thread_a');
    },
  );
}
