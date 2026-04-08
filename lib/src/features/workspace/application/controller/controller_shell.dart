part of '../connection_workspace_controller.dart';

extension on ConnectionWorkspaceController {
  Future<void> _initializeOnce() async {
    await _initializeWorkspaceController(this);
  }

  bool _applyState(ConnectionWorkspaceState nextState) {
    if (_isDisposed || nextState == _state) {
      return false;
    }

    _state = nextState;
    notifyListeners();
    unawaited(_enqueueRecoveryPersistence());
    return true;
  }

  bool _applyStateWithoutRecoveryPersistence(
    ConnectionWorkspaceState nextState,
  ) {
    if (_isDisposed || nextState == _state) {
      return false;
    }

    _state = nextState;
    notifyListeners();
    return true;
  }

  void _notifyListenersInternal() {
    notifyListeners();
  }

  void _notifyBindingChange() => _notifyWorkspaceBindingChange(this);

  void _registerLiveBinding(
    String connectionId,
    ConnectionLaneBinding binding,
  ) => _registerWorkspaceLiveBinding(this, connectionId, binding);

  void _unregisterLiveBinding(String connectionId) =>
      _unregisterWorkspaceLiveBinding(this, connectionId);

  void _scheduleRecoveryPersistence() =>
      _scheduleWorkspaceRecoveryPersistence(this);

  Future<void> _enqueueRecoveryPersistence({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) => _enqueueWorkspaceRecoveryPersistence(
    this,
    backgroundedAt: backgroundedAt,
    backgroundedLifecycleState: backgroundedLifecycleState,
  );

  void _clearLiveReattachPhase(String connectionId) =>
      _clearWorkspaceLiveReattachPhase(this, connectionId);

  void _setLiveReattachPhase(
    String connectionId,
    ConnectionWorkspaceLiveReattachPhase phase,
  ) => _setWorkspaceLiveReattachPhase(this, connectionId, phase);

  Future<void> _queueRecoveryPersistenceSnapshot({
    ConnectionWorkspaceRecoveryState? snapshot,
  }) => _queueWorkspaceRecoveryPersistenceSnapshot(this, snapshot: snapshot);

  bool _hasImmediateRecoveryIdentityChange(
    ConnectionWorkspaceRecoveryState? snapshot,
  ) => _hasWorkspaceImmediateRecoveryIdentityChange(this, snapshot);

  ConnectionWorkspaceRecoveryState? _selectedRecoveryStateSnapshot({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) => _selectedWorkspaceRecoveryStateSnapshot(
    this,
    backgroundedAt: backgroundedAt,
    backgroundedLifecycleState: backgroundedLifecycleState,
  );

  ConnectionWorkspaceRecoveryState? _latestUnsavedRecoveryStateSnapshot() =>
      _latestUnsavedWorkspaceRecoveryStateSnapshot(this);

  void _markTransportReconnectRequired(String connectionId) =>
      _markWorkspaceTransportReconnectRequired(this, connectionId);

  void _clearTransportReconnectRequired(String connectionId) =>
      _clearWorkspaceTransportReconnectRequired(this, connectionId);

  void _setTransportRecoveryPhase(
    String connectionId,
    ConnectionWorkspaceTransportRecoveryPhase phase,
  ) => _setWorkspaceTransportRecoveryPhase(this, connectionId, phase);

  void _recordLifecycleBackgroundSnapshot(
    String connectionId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceBackgroundLifecycleState lifecycleState,
  }) => _recordWorkspaceLifecycleBackgroundSnapshot(
    this,
    connectionId,
    occurredAt: occurredAt,
    lifecycleState: lifecycleState,
  );

  void _recordLifecycleResume(
    String connectionId, {
    required DateTime occurredAt,
  }) => _recordWorkspaceLifecycleResume(
    this,
    connectionId,
    occurredAt: occurredAt,
  );

  void _recordTransportLoss(
    String connectionId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceTransportLossReason reason,
  }) => _recordWorkspaceTransportLoss(
    this,
    connectionId,
    occurredAt: occurredAt,
    reason: reason,
  );

  void _recordFallbackTransportConnectFailure(
    String connectionId, {
    required DateTime occurredAt,
    required Object? error,
  }) => _recordWorkspaceFallbackTransportConnectFailure(
    this,
    connectionId,
    occurredAt: occurredAt,
    error: error,
  );

  void _recordLiveReattachFailure(
    String connectionId, {
    required Object? error,
  }) => _recordWorkspaceLiveReattachFailure(this, connectionId, error: error);

  void _clearTurnLivenessAssessment(String connectionId) =>
      _clearWorkspaceTurnLivenessAssessment(this, connectionId);

  void _setTurnLivenessAssessment(
    String connectionId,
    ConnectionWorkspaceTurnLivenessAssessment assessment,
  ) => _setWorkspaceTurnLivenessAssessment(this, connectionId, assessment);

  void _beginRecoveryAttempt(
    String connectionId, {
    required DateTime startedAt,
    required ConnectionWorkspaceRecoveryOrigin origin,
  }) => _beginWorkspaceRecoveryAttempt(
    this,
    connectionId,
    startedAt: startedAt,
    origin: origin,
  );

  void _completeRecoveryAttempt(
    String connectionId, {
    required DateTime completedAt,
    required ConnectionWorkspaceRecoveryOutcome outcome,
  }) => _completeWorkspaceRecoveryAttempt(
    this,
    connectionId,
    completedAt: completedAt,
    outcome: outcome,
  );

  void _completeConversationRecoveryAttempt(
    String connectionId,
    ConnectionLaneBinding binding, {
    required DateTime completedAt,
  }) => _completeWorkspaceConversationRecoveryAttempt(
    this,
    connectionId,
    binding,
    completedAt: completedAt,
  );

  void _updateRecoveryDiagnostics(
    String connectionId,
    ConnectionWorkspaceRecoveryDiagnostics Function(
      ConnectionWorkspaceRecoveryDiagnostics current,
    )
    update, {
    bool enqueueRecoveryPersistence = false,
  }) => _updateWorkspaceRecoveryDiagnostics(
    this,
    connectionId,
    update,
    enqueueRecoveryPersistence: enqueueRecoveryPersistence,
  );
}
