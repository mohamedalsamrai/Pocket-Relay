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

  void _registerLiveBinding(String laneId, ConnectionLaneBinding binding) =>
      _registerWorkspaceLiveBinding(this, laneId, binding);

  void _unregisterLiveBinding(String laneId) =>
      _unregisterWorkspaceLiveBinding(this, laneId);

  void _scheduleRecoveryPersistence() =>
      _recoveryPersistenceController.schedule();

  Future<void> _enqueueRecoveryPersistence({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) => _recoveryPersistenceController.flush(
    backgroundedAt: backgroundedAt,
    backgroundedLifecycleState: backgroundedLifecycleState,
  );

  void _clearLiveReattachPhase(String laneId) =>
      _clearWorkspaceLiveReattachPhase(this, laneId);

  void _setLiveReattachPhase(
    String laneId,
    ConnectionWorkspaceLiveReattachPhase phase,
  ) => _setWorkspaceLiveReattachPhase(this, laneId, phase);

  Future<void> _queueRecoveryPersistenceSnapshot({
    ConnectionWorkspaceRecoveryState? snapshot,
    String? laneId,
  }) => _recoveryPersistenceController.queueSnapshot(
    snapshot: snapshot,
    laneId: laneId,
  );

  bool _hasImmediateRecoveryIdentityChange(
    ConnectionWorkspaceRecoveryState? snapshot,
  ) => _recoveryPersistenceController.hasImmediateIdentityChange(snapshot);

  ConnectionWorkspaceRecoveryState? _selectedRecoveryStateSnapshot({
    DateTime? backgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
  }) => _selectedWorkspaceRecoveryStateSnapshot(
    this,
    backgroundedAt: backgroundedAt,
    backgroundedLifecycleState: backgroundedLifecycleState,
  );

  ConnectionWorkspaceRecoveryState? _latestUnsavedRecoveryStateSnapshot() =>
      _recoveryPersistenceController.latestUnsavedSnapshot;

  void _markTransportReconnectRequired(String laneId) =>
      _markWorkspaceTransportReconnectRequired(this, laneId);

  void _clearTransportReconnectRequired(String laneId) =>
      _clearWorkspaceTransportReconnectRequired(this, laneId);

  void _setTransportRecoveryPhase(
    String laneId,
    ConnectionWorkspaceTransportRecoveryPhase phase,
  ) => _setWorkspaceTransportRecoveryPhase(this, laneId, phase);

  void _recordLifecycleBackgroundSnapshot(
    String laneId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceBackgroundLifecycleState lifecycleState,
  }) => _recordWorkspaceLifecycleBackgroundSnapshot(
    this,
    laneId,
    occurredAt: occurredAt,
    lifecycleState: lifecycleState,
  );

  void _recordLifecycleResume(String laneId, {required DateTime occurredAt}) =>
      _recordWorkspaceLifecycleResume(this, laneId, occurredAt: occurredAt);

  void _recordTransportLoss(
    String laneId, {
    required DateTime occurredAt,
    required ConnectionWorkspaceTransportLossReason reason,
  }) => _recordWorkspaceTransportLoss(
    this,
    laneId,
    occurredAt: occurredAt,
    reason: reason,
  );

  void _recordFallbackTransportConnectFailure(
    String laneId, {
    required DateTime occurredAt,
    required Object? error,
  }) => _recordWorkspaceFallbackTransportConnectFailure(
    this,
    laneId,
    occurredAt: occurredAt,
    error: error,
  );

  void _recordLiveReattachFailure(String laneId, {required Object? error}) =>
      _recordWorkspaceLiveReattachFailure(this, laneId, error: error);

  void _clearTurnLivenessAssessment(String laneId) =>
      _clearWorkspaceTurnLivenessAssessment(this, laneId);

  void _setTurnLivenessAssessment(
    String laneId,
    ConnectionWorkspaceTurnLivenessAssessment assessment,
  ) => _setWorkspaceTurnLivenessAssessment(this, laneId, assessment);

  void _beginRecoveryAttempt(
    String laneId, {
    required DateTime startedAt,
    required ConnectionWorkspaceRecoveryOrigin origin,
  }) => _beginWorkspaceRecoveryAttempt(
    this,
    laneId,
    startedAt: startedAt,
    origin: origin,
  );

  void _completeRecoveryAttempt(
    String laneId, {
    required DateTime completedAt,
    required ConnectionWorkspaceRecoveryOutcome outcome,
  }) => _completeWorkspaceRecoveryAttempt(
    this,
    laneId,
    completedAt: completedAt,
    outcome: outcome,
  );

  void _completeConversationRecoveryAttempt(
    String laneId,
    ConnectionLaneBinding binding, {
    required DateTime completedAt,
  }) => _completeWorkspaceConversationRecoveryAttempt(
    this,
    laneId,
    binding,
    completedAt: completedAt,
  );

  void _updateRecoveryDiagnostics(
    String laneId,
    ConnectionWorkspaceRecoveryDiagnostics Function(
      ConnectionWorkspaceRecoveryDiagnostics current,
    )
    update, {
    bool enqueueRecoveryPersistence = false,
  }) => _updateWorkspaceRecoveryDiagnostics(
    this,
    laneId,
    update,
    enqueueRecoveryPersistence: enqueueRecoveryPersistence,
  );
}
