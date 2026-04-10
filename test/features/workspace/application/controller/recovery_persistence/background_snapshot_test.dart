import '../controller_test_support.dart';

void main() {
  test(
    'inactive without pause snapshots recovery state but does not reconnect the selected lane',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore();
      final snapshotTime = DateTime(2026, 3, 22, 14, 5);
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Keep me');

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      final backgroundedRecoveryState = await recoveryStore.load();
      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      final recoveryState = await recoveryStore.load();
      expect(nextBinding, same(firstBinding));
      expect(clientsById['conn_primary']!.disconnectCalls, 0);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(backgroundedRecoveryState, isNotNull);
      expect(backgroundedRecoveryState!.draftText, 'Keep me');
      expect(backgroundedRecoveryState.backgroundedAt, snapshotTime);
      expect(
        backgroundedRecoveryState.backgroundedLifecycleState,
        ConnectionWorkspaceBackgroundLifecycleState.inactive,
      );
      expect(recoveryState, isNotNull);
      expect(recoveryState!.backgroundedAt, isNull);
      expect(recoveryState.backgroundedLifecycleState, isNull);
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnostics, isNotNull);
      expect(diagnostics!.lastResumedAt, snapshotTime);
      expect(diagnostics.lastBackgroundedAt, snapshotTime);
    },
  );

  test('non-selected lane changes do not persist recovery snapshots', () async {
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
    await controller.instantiateConnection('conn_secondary');
    controller.selectConnection('conn_primary');
    recoveryStore.savedStates.clear();

    controller
        .bindingForConnectionId('conn_secondary')!
        .restoreComposerDraft('Ignored draft');
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(recoveryStore.savedStates, isEmpty);
    expect(await recoveryStore.load(), recoveryStore.initialState);
  });
}
