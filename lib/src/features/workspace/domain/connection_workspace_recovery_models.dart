part of 'connection_workspace_state.dart';

enum ConnectionWorkspaceViewport { liveLane, savedConnections, savedSystems }

enum ConnectionWorkspaceBackgroundLifecycleState { inactive, hidden, paused }

@immutable
class ConnectionWorkspaceRecoveryState {
  const ConnectionWorkspaceRecoveryState({
    required this.connectionId,
    required this.draftText,
    this.selectedThreadId,
    this.backgroundedAt,
    this.backgroundedLifecycleState,
  });

  final String connectionId;
  final String draftText;
  final String? selectedThreadId;
  final DateTime? backgroundedAt;
  final ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'connectionId': connectionId,
      'draftText': draftText,
      'selectedThreadId': selectedThreadId,
      'backgroundedAt': backgroundedAt?.toIso8601String(),
      'backgroundedLifecycleState': backgroundedLifecycleState?.name,
    };
  }

  factory ConnectionWorkspaceRecoveryState.fromJson(Map<String, dynamic> json) {
    return ConnectionWorkspaceRecoveryState(
      connectionId: _normalizedRecoveryString(json['connectionId']) ?? '',
      draftText: json['draftText'] as String? ?? '',
      selectedThreadId: _normalizedRecoveryString(json['selectedThreadId']),
      backgroundedAt: _parseRecoveryDateTime(json['backgroundedAt']),
      backgroundedLifecycleState: _parseBackgroundLifecycleState(
        json['backgroundedLifecycleState'],
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceRecoveryState &&
        other.connectionId == connectionId &&
        other.draftText == draftText &&
        other.selectedThreadId == selectedThreadId &&
        other.backgroundedAt == backgroundedAt &&
        other.backgroundedLifecycleState == backgroundedLifecycleState;
  }

  @override
  int get hashCode => Object.hash(
    connectionId,
    draftText,
    selectedThreadId,
    backgroundedAt,
    backgroundedLifecycleState,
  );
}

enum ConnectionWorkspaceReconnectRequirement {
  savedSettings,
  transport,
  transportWithSavedSettings,
}

enum ConnectionWorkspaceRecoveryOrigin {
  foregroundResume,
  coldStart,
  manualReconnect,
}

enum ConnectionWorkspaceTransportLossReason {
  disconnected,
  appServerExitGraceful,
  appServerExitError,
  connectFailed,
  sshConnectFailed,
  sshHostKeyMismatch,
  sshAuthenticationFailed,
}

enum ConnectionWorkspaceRecoveryOutcome {
  transportRestored,
  transportUnavailable,
  liveReattached,
  livenessUnknown,
  continuityLost,
  conversationRestored,
  conversationUnavailable,
  conversationRestoreFailed,
}

enum ConnectionWorkspaceTransportRecoveryPhase {
  lost,
  reconnecting,
  unavailable,
}

enum ConnectionWorkspaceLiveReattachPhase {
  transportLost,
  reconnecting,
  ownerMissing,
  ownerUnhealthy,
  liveReattached,
  fallbackRestore,
}

enum ConnectionWorkspaceTurnLivenessStatus {
  stillLive,
  finishedWhileAway,
  continuityLost,
  unknown,
}

enum ConnectionWorkspaceTurnLivenessEvidence {
  activeTurnReattached,
  pendingTurnRequestReattached,
  threadHistoryRunningTurn,
  threadHistoryTerminalTurn,
  liveReattachFailed,
  ownerUnavailable,
  transportUnavailable,
  adapterUnverifiable,
}

DateTime? _parseRecoveryDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String? _normalizedRecoveryString(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalizedValue = value.trim();
  return normalizedValue.isEmpty ? null : normalizedValue;
}

ConnectionWorkspaceBackgroundLifecycleState? _parseBackgroundLifecycleState(
  Object? value,
) {
  final normalizedValue = _normalizedRecoveryString(value);
  if (normalizedValue == null) {
    return null;
  }

  for (final lifecycleState
      in ConnectionWorkspaceBackgroundLifecycleState.values) {
    if (lifecycleState.name == normalizedValue) {
      return lifecycleState;
    }
  }
  return null;
}

@immutable
class ConnectionWorkspaceTurnLivenessAssessment {
  const ConnectionWorkspaceTurnLivenessAssessment({
    required this.status,
    required this.evidence,
    this.threadId,
    this.turnId,
  });

  final ConnectionWorkspaceTurnLivenessStatus status;
  final ConnectionWorkspaceTurnLivenessEvidence evidence;
  final String? threadId;
  final String? turnId;

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceTurnLivenessAssessment &&
        other.status == status &&
        other.evidence == evidence &&
        other.threadId == threadId &&
        other.turnId == turnId;
  }

  @override
  int get hashCode => Object.hash(status, evidence, threadId, turnId);
}

@immutable
class ConnectionWorkspaceRecoveryDiagnostics {
  const ConnectionWorkspaceRecoveryDiagnostics({
    this.lastBackgroundedAt,
    this.lastBackgroundedLifecycleState,
    this.lastResumedAt,
    this.lastRecoveryOrigin,
    this.lastRecoveryStartedAt,
    this.lastRecoveryCompletedAt,
    this.lastTransportLossAt,
    this.lastTransportLossReason,
    this.lastTransportFailureDetail,
    this.lastLiveReattachFailureDetail,
    this.lastRecoveryPersistenceFailureAt,
    this.lastRecoveryPersistenceFailureDetail,
    this.lastRecoveryOutcome,
    this.lastTurnLivenessAssessment,
  });

  final DateTime? lastBackgroundedAt;
  final ConnectionWorkspaceBackgroundLifecycleState?
  lastBackgroundedLifecycleState;
  final DateTime? lastResumedAt;
  final ConnectionWorkspaceRecoveryOrigin? lastRecoveryOrigin;
  final DateTime? lastRecoveryStartedAt;
  final DateTime? lastRecoveryCompletedAt;
  final DateTime? lastTransportLossAt;
  final ConnectionWorkspaceTransportLossReason? lastTransportLossReason;
  final String? lastTransportFailureDetail;
  final String? lastLiveReattachFailureDetail;
  final DateTime? lastRecoveryPersistenceFailureAt;
  final String? lastRecoveryPersistenceFailureDetail;
  final ConnectionWorkspaceRecoveryOutcome? lastRecoveryOutcome;
  final ConnectionWorkspaceTurnLivenessAssessment? lastTurnLivenessAssessment;

  ConnectionWorkspaceRecoveryDiagnostics copyWith({
    DateTime? lastBackgroundedAt,
    ConnectionWorkspaceBackgroundLifecycleState? lastBackgroundedLifecycleState,
    DateTime? lastResumedAt,
    ConnectionWorkspaceRecoveryOrigin? lastRecoveryOrigin,
    DateTime? lastRecoveryStartedAt,
    DateTime? lastRecoveryCompletedAt,
    DateTime? lastTransportLossAt,
    ConnectionWorkspaceTransportLossReason? lastTransportLossReason,
    String? lastTransportFailureDetail,
    String? lastLiveReattachFailureDetail,
    DateTime? lastRecoveryPersistenceFailureAt,
    String? lastRecoveryPersistenceFailureDetail,
    ConnectionWorkspaceRecoveryOutcome? lastRecoveryOutcome,
    ConnectionWorkspaceTurnLivenessAssessment? lastTurnLivenessAssessment,
    bool clearLastBackgroundedAt = false,
    bool clearLastBackgroundedLifecycleState = false,
    bool clearLastResumedAt = false,
    bool clearLastRecoveryOrigin = false,
    bool clearLastRecoveryStartedAt = false,
    bool clearLastRecoveryCompletedAt = false,
    bool clearLastTransportLossAt = false,
    bool clearLastTransportLossReason = false,
    bool clearLastTransportFailureDetail = false,
    bool clearLastLiveReattachFailureDetail = false,
    bool clearLastRecoveryPersistenceFailureAt = false,
    bool clearLastRecoveryPersistenceFailureDetail = false,
    bool clearLastRecoveryOutcome = false,
    bool clearLastTurnLivenessAssessment = false,
  }) {
    return ConnectionWorkspaceRecoveryDiagnostics(
      lastBackgroundedAt: clearLastBackgroundedAt
          ? null
          : (lastBackgroundedAt ?? this.lastBackgroundedAt),
      lastBackgroundedLifecycleState: clearLastBackgroundedLifecycleState
          ? null
          : (lastBackgroundedLifecycleState ??
                this.lastBackgroundedLifecycleState),
      lastResumedAt: clearLastResumedAt
          ? null
          : (lastResumedAt ?? this.lastResumedAt),
      lastRecoveryOrigin: clearLastRecoveryOrigin
          ? null
          : (lastRecoveryOrigin ?? this.lastRecoveryOrigin),
      lastRecoveryStartedAt: clearLastRecoveryStartedAt
          ? null
          : (lastRecoveryStartedAt ?? this.lastRecoveryStartedAt),
      lastRecoveryCompletedAt: clearLastRecoveryCompletedAt
          ? null
          : (lastRecoveryCompletedAt ?? this.lastRecoveryCompletedAt),
      lastTransportLossAt: clearLastTransportLossAt
          ? null
          : (lastTransportLossAt ?? this.lastTransportLossAt),
      lastTransportLossReason: clearLastTransportLossReason
          ? null
          : (lastTransportLossReason ?? this.lastTransportLossReason),
      lastTransportFailureDetail: clearLastTransportFailureDetail
          ? null
          : (lastTransportFailureDetail ?? this.lastTransportFailureDetail),
      lastLiveReattachFailureDetail: clearLastLiveReattachFailureDetail
          ? null
          : (lastLiveReattachFailureDetail ??
                this.lastLiveReattachFailureDetail),
      lastRecoveryPersistenceFailureAt: clearLastRecoveryPersistenceFailureAt
          ? null
          : (lastRecoveryPersistenceFailureAt ??
                this.lastRecoveryPersistenceFailureAt),
      lastRecoveryPersistenceFailureDetail:
          clearLastRecoveryPersistenceFailureDetail
          ? null
          : (lastRecoveryPersistenceFailureDetail ??
                this.lastRecoveryPersistenceFailureDetail),
      lastRecoveryOutcome: clearLastRecoveryOutcome
          ? null
          : (lastRecoveryOutcome ?? this.lastRecoveryOutcome),
      lastTurnLivenessAssessment: clearLastTurnLivenessAssessment
          ? null
          : (lastTurnLivenessAssessment ?? this.lastTurnLivenessAssessment),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceRecoveryDiagnostics &&
        other.lastBackgroundedAt == lastBackgroundedAt &&
        other.lastBackgroundedLifecycleState ==
            lastBackgroundedLifecycleState &&
        other.lastResumedAt == lastResumedAt &&
        other.lastRecoveryOrigin == lastRecoveryOrigin &&
        other.lastRecoveryStartedAt == lastRecoveryStartedAt &&
        other.lastRecoveryCompletedAt == lastRecoveryCompletedAt &&
        other.lastTransportLossAt == lastTransportLossAt &&
        other.lastTransportLossReason == lastTransportLossReason &&
        other.lastTransportFailureDetail == lastTransportFailureDetail &&
        other.lastLiveReattachFailureDetail == lastLiveReattachFailureDetail &&
        other.lastRecoveryPersistenceFailureAt ==
            lastRecoveryPersistenceFailureAt &&
        other.lastRecoveryPersistenceFailureDetail ==
            lastRecoveryPersistenceFailureDetail &&
        other.lastRecoveryOutcome == lastRecoveryOutcome &&
        other.lastTurnLivenessAssessment == lastTurnLivenessAssessment;
  }

  @override
  int get hashCode => Object.hash(
    lastBackgroundedAt,
    lastBackgroundedLifecycleState,
    lastResumedAt,
    lastRecoveryOrigin,
    lastRecoveryStartedAt,
    lastRecoveryCompletedAt,
    lastTransportLossAt,
    lastTransportLossReason,
    lastTransportFailureDetail,
    lastLiveReattachFailureDetail,
    lastRecoveryPersistenceFailureAt,
    lastRecoveryPersistenceFailureDetail,
    lastRecoveryOutcome,
    lastTurnLivenessAssessment,
  );
}

@immutable
class ConnectionWorkspaceDeviceContinuityWarnings {
  const ConnectionWorkspaceDeviceContinuityWarnings({
    this.foregroundServiceWarning,
    this.backgroundGraceWarning,
    this.wakeLockWarning,
    this.turnCompletionAlertWarning,
  });

  final PocketUserFacingError? foregroundServiceWarning;
  final PocketUserFacingError? backgroundGraceWarning;
  final PocketUserFacingError? wakeLockWarning;
  final PocketUserFacingError? turnCompletionAlertWarning;

  bool get isEmpty =>
      foregroundServiceWarning == null &&
      backgroundGraceWarning == null &&
      wakeLockWarning == null &&
      turnCompletionAlertWarning == null;

  List<PocketUserFacingError> get activeWarnings => <PocketUserFacingError?>[
    foregroundServiceWarning,
    backgroundGraceWarning,
    wakeLockWarning,
    turnCompletionAlertWarning,
  ].whereType<PocketUserFacingError>().toList(growable: false);

  ConnectionWorkspaceDeviceContinuityWarnings copyWith({
    PocketUserFacingError? foregroundServiceWarning,
    PocketUserFacingError? backgroundGraceWarning,
    PocketUserFacingError? wakeLockWarning,
    PocketUserFacingError? turnCompletionAlertWarning,
    bool clearForegroundServiceWarning = false,
    bool clearBackgroundGraceWarning = false,
    bool clearWakeLockWarning = false,
    bool clearTurnCompletionAlertWarning = false,
  }) {
    return ConnectionWorkspaceDeviceContinuityWarnings(
      foregroundServiceWarning: clearForegroundServiceWarning
          ? null
          : (foregroundServiceWarning ?? this.foregroundServiceWarning),
      backgroundGraceWarning: clearBackgroundGraceWarning
          ? null
          : (backgroundGraceWarning ?? this.backgroundGraceWarning),
      wakeLockWarning: clearWakeLockWarning
          ? null
          : (wakeLockWarning ?? this.wakeLockWarning),
      turnCompletionAlertWarning: clearTurnCompletionAlertWarning
          ? null
          : (turnCompletionAlertWarning ?? this.turnCompletionAlertWarning),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceDeviceContinuityWarnings &&
        other.foregroundServiceWarning == foregroundServiceWarning &&
        other.backgroundGraceWarning == backgroundGraceWarning &&
        other.wakeLockWarning == wakeLockWarning &&
        other.turnCompletionAlertWarning == turnCompletionAlertWarning;
  }

  @override
  int get hashCode => Object.hash(
    foregroundServiceWarning,
    backgroundGraceWarning,
    wakeLockWarning,
    turnCompletionAlertWarning,
  );
}
