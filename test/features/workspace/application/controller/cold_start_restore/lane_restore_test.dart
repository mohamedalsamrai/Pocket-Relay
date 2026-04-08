import '../controller_test_support.dart';

void main() {
  test(
    'initialization keeps the first live lane empty until history is explicitly picked',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.selectedLaneBinding;
      expect(binding, isNotNull);

      await binding!.sessionController.initialize();

      expect(clientsById['conn_primary']?.connectCalls, 0);
      expect(clientsById['conn_primary']?.readThreadCalls, isEmpty);
      expect(binding.sessionController.transcriptBlocks, isEmpty);
      expect(binding.sessionController.sessionState.rootThreadId, isNull);
    },
  );

  test(
    'initialization keeps booting when local recovery load fails and records a typed warning',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: const ThrowingConnectionWorkspaceRecoveryStore(
          ConnectionWorkspaceRecoveryStoreCorruptedException(
            'Persisted workspace recovery metadata is malformed JSON.',
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.selectedLaneBinding, isNotNull);
      expect(
        controller.state.recoveryLoadWarning?.definition,
        PocketErrorCatalog.appBootstrapRecoveryStateLoadFailed,
      );
      expect(
        controller.state.recoveryLoadWarning?.inlineMessage,
        contains('malformed JSON'),
      );
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        isEmpty,
      );
      expect(clientsById['conn_primary']!.connectCalls, 0);
    },
  );
}
