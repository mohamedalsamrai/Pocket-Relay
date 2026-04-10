import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

typedef WorkspaceRecoveryPersistenceSnapshotBuilder =
    ConnectionWorkspaceRecoveryState? Function({
      DateTime? backgroundedAt,
      ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
    });

typedef WorkspaceRecoveryPersistenceDiagnosticsUpdater =
    void Function(
      String laneId,
      ConnectionWorkspaceRecoveryDiagnostics Function(
        ConnectionWorkspaceRecoveryDiagnostics current,
      )
      update,
    );

typedef WorkspaceRecoveryPersistenceNow = DateTime Function();
typedef WorkspaceRecoveryPersistenceCurrentLaneId = String? Function();

class WorkspaceRecoveryPersistenceController {
  WorkspaceRecoveryPersistenceController({
    required ConnectionWorkspaceRecoveryStore recoveryStore,
    required Duration debounceDuration,
    required WorkspaceRecoveryPersistenceNow now,
    required WorkspaceRecoveryPersistenceCurrentLaneId currentLaneId,
    required WorkspaceRecoveryPersistenceSnapshotBuilder buildSnapshot,
    required WorkspaceRecoveryPersistenceDiagnosticsUpdater updateDiagnostics,
  }) : _recoveryStore = recoveryStore,
       _debounceDuration = debounceDuration,
       _now = now,
       _currentLaneId = currentLaneId,
       _buildSnapshot = buildSnapshot,
       _updateDiagnostics = updateDiagnostics;

  final ConnectionWorkspaceRecoveryStore _recoveryStore;
  final Duration _debounceDuration;
  final WorkspaceRecoveryPersistenceNow _now;
  final WorkspaceRecoveryPersistenceCurrentLaneId _currentLaneId;
  final WorkspaceRecoveryPersistenceSnapshotBuilder _buildSnapshot;
  final WorkspaceRecoveryPersistenceDiagnosticsUpdater _updateDiagnostics;

  Future<void> _recoveryPersistence = Future<void>.value();
  Timer? _debounceTimer;
  ConnectionWorkspaceRecoveryState? _pendingPersistenceState;
  String? _pendingPersistenceLaneId;
  ConnectionWorkspaceRecoveryState? _lastPersistedState;
  ConnectionWorkspaceRecoveryState? _latestPersistenceState;
  bool _isPersisting = false;
  bool _isDisposed = false;

  Future<ConnectionWorkspaceRecoveryState?> loadPersistedSnapshot() {
    return _recoveryStore.load();
  }

  void seedPersistedSnapshot(ConnectionWorkspaceRecoveryState? snapshot) {
    _lastPersistedState = snapshot;
    _latestPersistenceState = snapshot;
  }

  void schedule() {
    if (_isDisposed) {
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _debounceTimer = null;
      unawaited(
        queueSnapshot(snapshot: _buildSnapshot(), laneId: _currentLaneId()),
      );
    });
  }

  Future<void> flush({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) {
    if (_isDisposed) {
      return _recoveryPersistence;
    }
    _debounceTimer?.cancel();
    _debounceTimer = null;
    return queueSnapshot(
      snapshot: _buildSnapshot(
        backgroundedAt: backgroundedAt,
        backgroundedLifecycleState: backgroundedLifecycleState,
      ),
      laneId: _currentLaneId(),
    );
  }

  Future<void> queueSnapshot({
    ConnectionWorkspaceRecoveryState? snapshot,
    String? laneId,
  }) {
    if (_isDisposed) {
      return _recoveryPersistence;
    }

    final resolvedLaneId = laneId ?? _currentLaneId();
    final hasUnsavedRecoverySnapshot =
        _latestPersistenceState != _lastPersistedState;
    if ((snapshot == _lastPersistedState && !hasUnsavedRecoverySnapshot) ||
        snapshot == _pendingPersistenceState) {
      _pendingPersistenceLaneId = resolvedLaneId;
      return _recoveryPersistence;
    }

    _latestPersistenceState = snapshot;
    _pendingPersistenceState = snapshot;
    _pendingPersistenceLaneId = resolvedLaneId;
    if (_isPersisting) {
      return _recoveryPersistence;
    }

    _isPersisting = true;
    _recoveryPersistence = _drainQueue();
    return _recoveryPersistence;
  }

  bool hasImmediateIdentityChange(ConnectionWorkspaceRecoveryState? snapshot) {
    final referenceSnapshot = latestSnapshot;
    return referenceSnapshot?.connectionId != snapshot?.connectionId ||
        referenceSnapshot?.selectedThreadId != snapshot?.selectedThreadId;
  }

  ConnectionWorkspaceRecoveryState? get latestSnapshot =>
      latestUnsavedSnapshot ?? _lastPersistedState;

  ConnectionWorkspaceRecoveryState? get latestUnsavedSnapshot {
    final pendingSnapshot = _pendingPersistenceState;
    if (pendingSnapshot != null) {
      return pendingSnapshot;
    }

    final latestSnapshot = _latestPersistenceState;
    if (latestSnapshot != _lastPersistedState) {
      return latestSnapshot;
    }

    return null;
  }

  Future<void> dispose() {
    if (_isDisposed) {
      return _recoveryPersistence;
    }
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final finalRecoveryPersistence = queueSnapshot(
      snapshot: _buildSnapshot(),
      laneId: _currentLaneId(),
    );
    _isDisposed = true;
    return finalRecoveryPersistence;
  }

  Future<void> _drainQueue() async {
    try {
      while (true) {
        final snapshot = _pendingPersistenceState;
        final laneId = _pendingPersistenceLaneId;
        _pendingPersistenceState = null;
        _pendingPersistenceLaneId = null;
        if (snapshot == null) {
          break;
        }
        if (snapshot == _lastPersistedState) {
          if (_pendingPersistenceState == null) {
            break;
          }
          continue;
        }
        try {
          await _recoveryStore.save(snapshot);
          _lastPersistedState = snapshot;
          if (laneId != null) {
            _updateDiagnostics(
              laneId,
              (current) => current.copyWith(
                clearLastRecoveryPersistenceFailureAt: true,
                clearLastRecoveryPersistenceFailureDetail: true,
              ),
            );
          }
        } catch (error, stackTrace) {
          if (laneId != null) {
            _updateDiagnostics(
              laneId,
              (current) => current.copyWith(
                lastRecoveryPersistenceFailureAt: _now().toUtc(),
                lastRecoveryPersistenceFailureDetail:
                    PocketErrorDetailFormatter.normalize(error),
              ),
            );
          }
          assert(() {
            debugPrint('Failed to save workspace recovery state: $error');
            debugPrintStack(stackTrace: stackTrace);
            return true;
          }());
        }
        if (_pendingPersistenceState == null) {
          break;
        }
      }
    } finally {
      _isPersisting = false;
      if (_pendingPersistenceState != null && !_isDisposed) {
        _isPersisting = true;
        _recoveryPersistence = _drainQueue();
      }
    }
  }
}
