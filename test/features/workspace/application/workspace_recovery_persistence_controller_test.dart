import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_recovery_persistence_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

void main() {
  test(
    'debounced schedule persists the latest selected snapshot once',
    () async {
      final recoveryStore = _RecordingRecoveryStore();
      var draftText = 'First draft';
      final controller = WorkspaceRecoveryPersistenceController(
        recoveryStore: recoveryStore,
        debounceDuration: Duration.zero,
        now: () => DateTime(2026, 4, 9, 12),
        buildSnapshot:
            ({
              DateTime? backgroundedAt,
              ConnectionWorkspaceBackgroundLifecycleState?
              backgroundedLifecycleState,
            }) => ConnectionWorkspaceRecoveryState(
              connectionId: 'conn_primary',
              selectedThreadId: 'thread_saved',
              draftText: draftText,
              backgroundedAt: backgroundedAt,
              backgroundedLifecycleState: backgroundedLifecycleState,
            ),
        updateDiagnostics: (_, _) {},
      );

      controller.schedule();
      draftText = 'Latest draft';
      controller.schedule();
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.savedStates, hasLength(1));
      expect(recoveryStore.savedStates.single?.connectionId, 'conn_primary');
      expect(
        recoveryStore.savedStates.single?.selectedThreadId,
        'thread_saved',
      );
      expect(recoveryStore.savedStates.single?.draftText, 'Latest draft');

      await controller.dispose();
    },
  );

  test(
    'failed save records diagnostics and keeps the latest unsaved snapshot',
    () async {
      final persistedState = const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        selectedThreadId: 'thread_stale',
        draftText: '',
      );
      final nextState = const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        selectedThreadId: 'thread_saved',
        draftText: '',
      );
      final recoveryStore = _RecordingRecoveryStore(
        initialState: persistedState,
        saveError: StateError('secure storage write failed'),
      );
      final diagnosticsUpdates = <ConnectionWorkspaceRecoveryDiagnostics>[];
      final controller = WorkspaceRecoveryPersistenceController(
        recoveryStore: recoveryStore,
        debounceDuration: Duration.zero,
        now: () => DateTime.utc(2026, 4, 9, 12),
        buildSnapshot: ({backgroundedAt, backgroundedLifecycleState}) =>
            nextState,
        updateDiagnostics: (_, update) {
          diagnosticsUpdates.add(
            update(const ConnectionWorkspaceRecoveryDiagnostics()),
          );
        },
      )..seedPersistedSnapshot(persistedState);

      await controller.queueSnapshot(snapshot: nextState);

      expect(recoveryStore.savedStates, <ConnectionWorkspaceRecoveryState?>[
        nextState,
      ]);
      expect(await recoveryStore.load(), persistedState);
      expect(controller.latestUnsavedSnapshot, nextState);
      expect(diagnosticsUpdates, hasLength(1));
      expect(
        diagnosticsUpdates.single.lastRecoveryPersistenceFailureAt,
        DateTime.utc(2026, 4, 9, 12),
      );
      expect(
        diagnosticsUpdates.single.lastRecoveryPersistenceFailureDetail,
        'secure storage write failed',
      );

      recoveryStore.saveError = null;
      await controller.dispose();
    },
  );

  test(
    'flush after dispose does not build or queue another snapshot',
    () async {
      final recoveryStore = _RecordingRecoveryStore();
      const snapshot = ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        selectedThreadId: 'thread_saved',
        draftText: '',
      );
      var buildCalls = 0;
      final controller = WorkspaceRecoveryPersistenceController(
        recoveryStore: recoveryStore,
        debounceDuration: Duration.zero,
        now: () => DateTime.utc(2026, 4, 9, 12),
        buildSnapshot: ({backgroundedAt, backgroundedLifecycleState}) {
          buildCalls += 1;
          return snapshot;
        },
        updateDiagnostics: (_, _) {},
      );

      await controller.dispose();
      await controller.flush();

      expect(buildCalls, 1);
      expect(recoveryStore.savedStates, <ConnectionWorkspaceRecoveryState?>[
        snapshot,
      ]);
    },
  );
}

final class _RecordingRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  _RecordingRecoveryStore({
    ConnectionWorkspaceRecoveryState? initialState,
    this.saveError,
  }) : _state = initialState;

  final List<ConnectionWorkspaceRecoveryState?> savedStates =
      <ConnectionWorkspaceRecoveryState?>[];
  Object? saveError;
  ConnectionWorkspaceRecoveryState? _state;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async => _state;

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    savedStates.add(state);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    _state = state;
  }
}
