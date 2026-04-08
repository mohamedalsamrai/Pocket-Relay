import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

import 'live_lane_notice_contract.dart';

class LiveLaneNoticeProjector {
  const LiveLaneNoticeProjector();

  static const Duration finishedWhileAwayVisibilityDuration = Duration(
    seconds: 6,
  );

  LiveLaneNoticeContract? project({
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceRecoveryDiagnostics? recoveryDiagnostics,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required ConnectionWorkspaceTurnLivenessAssessment? turnLivenessAssessment,
    required PocketUserFacingError? recoveryLoadWarning,
    required ConnectionWorkspaceDeviceContinuityWarnings deviceContinuityWarnings,
    required ChatHistoricalConversationRestoreState?
    historicalConversationRestoreState,
    required ChatConversationRecoveryState? conversationRecoveryState,
  }) {
    final entries = <LiveLaneNoticeEntryContract>[];
    final LiveLaneNoticeEntryContract? primaryEntry = _primaryEntryFor(
      liveReattachPhase: liveReattachPhase,
      transportRecoveryPhase: transportRecoveryPhase,
      recoveryDiagnostics: recoveryDiagnostics,
      remoteRuntime: remoteRuntime,
      turnLivenessAssessment: turnLivenessAssessment,
      historicalConversationRestoreState: historicalConversationRestoreState,
      conversationRecoveryState: conversationRecoveryState,
    );
    if (primaryEntry != null) {
      entries.add(primaryEntry);
    }
    if (recoveryLoadWarning case final warning?) {
      entries.add(
        _warningEntry(
          warning,
          key:
              'recovery_load_warning|${warning.definition.code}|'
              '${warning.inlineMessage}',
          icon: Icons.history_toggle_off_rounded,
        ),
      );
    }
    for (final warning in deviceContinuityWarnings.activeWarnings) {
      entries.add(
        _warningEntry(
          warning,
          key:
              'device_continuity_warning|${warning.definition.code}|'
              '${warning.inlineMessage}',
          icon: Icons.phone_android_rounded,
        ),
      );
    }
    if (entries.isEmpty) {
      return null;
    }

    return LiveLaneNoticeContract(entries: entries);
  }

  LiveLaneNoticeEntryContract? _primaryEntryFor({
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceRecoveryDiagnostics? recoveryDiagnostics,
    required ConnectionRemoteRuntimeState? remoteRuntime,
    required ConnectionWorkspaceTurnLivenessAssessment? turnLivenessAssessment,
    required ChatHistoricalConversationRestoreState?
    historicalConversationRestoreState,
    required ChatConversationRecoveryState? conversationRecoveryState,
  }) {
    final historyRestoreIsLoading =
        historicalConversationRestoreState?.phase ==
        ChatHistoricalConversationRestorePhase.loading;
    if ((transportRecoveryPhase == null &&
            liveReattachPhase == null &&
            turnLivenessAssessment == null) ||
        historyRestoreIsLoading ||
        conversationRecoveryState != null) {
      return null;
    }

    final isRecoveryStillInFlight = switch (
      liveReattachPhase ?? transportRecoveryPhase
    ) {
      ConnectionWorkspaceLiveReattachPhase.transportLost ||
      ConnectionWorkspaceLiveReattachPhase.reconnecting ||
      ConnectionWorkspaceTransportRecoveryPhase.lost ||
      ConnectionWorkspaceTransportRecoveryPhase.reconnecting => true,
      _ => false,
    };
    final showsTransportUnavailableNotice =
        liveReattachPhase ==
            ConnectionWorkspaceLiveReattachPhase.ownerMissing ||
        liveReattachPhase ==
            ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy ||
        transportRecoveryPhase ==
            ConnectionWorkspaceTransportRecoveryPhase.unavailable;
    final shouldUseTurnLivenessAssessmentNotice =
        !isRecoveryStillInFlight &&
        !showsTransportUnavailableNotice &&
        turnLivenessAssessment != null;
    if (shouldUseTurnLivenessAssessmentNotice) {
      return _turnLivenessEntry(turnLivenessAssessment);
    }

    if (liveReattachPhase ==
        ConnectionWorkspaceLiveReattachPhase.liveReattached) {
      return null;
    }

    if (liveReattachPhase ==
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore) {
      final fallbackError = ConnectionLifecycleErrors.liveReattachFallbackNotice(
        reattachFailureDetail: recoveryDiagnostics?.lastLiveReattachFailureDetail,
      );
      return LiveLaneNoticeEntryContract(
        key:
            'fallback_restore|'
            '${recoveryDiagnostics?.lastLiveReattachFailureDetail ?? ''}',
        title: fallbackError.title,
        message: fallbackError.bodyWithCode,
        isLoading: true,
        tone: LiveLaneNoticeTone.informational,
        icon: Icons.portable_wifi_off_rounded,
      );
    }

    final transportLostError = ConnectionLifecycleErrors.transportLostNotice();
    final unavailableError =
        ConnectionLifecycleErrors.transportUnavailableNotice(
          remoteRuntime,
          recoveryFailureDetail: recoveryDiagnostics?.lastTransportFailureDetail,
        );

    return switch (liveReattachPhase ?? transportRecoveryPhase) {
      ConnectionWorkspaceLiveReattachPhase.transportLost ||
      ConnectionWorkspaceTransportRecoveryPhase.lost => LiveLaneNoticeEntryContract(
        key: 'transport_lost',
        title: transportLostError.title,
        message: transportLostError.bodyWithCode,
        isLoading: false,
        tone: LiveLaneNoticeTone.warning,
        icon: Icons.portable_wifi_off_rounded,
      ),
      ConnectionWorkspaceLiveReattachPhase.reconnecting ||
      ConnectionWorkspaceTransportRecoveryPhase.reconnecting => LiveLaneNoticeEntryContract(
        key: 'transport_reconnecting',
        title: ConnectionWorkspaceCopy.reconnectingNoticeTitle,
        message: ConnectionWorkspaceCopy.reconnectingNoticeMessage,
        isLoading: true,
        tone: LiveLaneNoticeTone.informational,
        icon: Icons.portable_wifi_off_rounded,
      ),
      ConnectionWorkspaceLiveReattachPhase.ownerMissing ||
      ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy ||
      ConnectionWorkspaceTransportRecoveryPhase.unavailable => LiveLaneNoticeEntryContract(
        key:
            'transport_unavailable|'
            '${recoveryDiagnostics?.lastTransportFailureDetail ?? ''}|'
            '${remoteRuntime?.server.status.name ?? ''}',
        title: unavailableError.title,
        message: unavailableError.bodyWithCode,
        isLoading: false,
        tone: LiveLaneNoticeTone.warning,
        icon: Icons.portable_wifi_off_rounded,
      ),
      _ => null,
    };
  }

  LiveLaneNoticeEntryContract _turnLivenessEntry(
    ConnectionWorkspaceTurnLivenessAssessment assessment,
  ) {
    return switch (assessment.status) {
      ConnectionWorkspaceTurnLivenessStatus.stillLive =>
        LiveLaneNoticeEntryContract(
          key:
              'turn_still_live|${assessment.threadId ?? ''}|'
              '${assessment.turnId ?? ''}',
          title: ConnectionWorkspaceCopy.turnStillLiveNoticeTitle,
          message: ConnectionWorkspaceCopy.turnStillLiveNoticeMessage,
          isLoading: false,
          tone: LiveLaneNoticeTone.informational,
          icon: Icons.link_rounded,
        ),
      ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway =>
        LiveLaneNoticeEntryContract(
          key:
              'turn_finished_while_away|${assessment.threadId ?? ''}|'
              '${assessment.turnId ?? ''}',
          title: ConnectionWorkspaceCopy.turnFinishedWhileAwayNoticeTitle,
          message: ConnectionWorkspaceCopy.turnFinishedWhileAwayNoticeMessage,
          isLoading: false,
          tone: LiveLaneNoticeTone.informational,
          icon: Icons.history_rounded,
          dismissAfterVisibleDuration: finishedWhileAwayVisibilityDuration,
        ),
      ConnectionWorkspaceTurnLivenessStatus.continuityLost =>
        LiveLaneNoticeEntryContract(
          key:
              'turn_continuity_lost|${assessment.threadId ?? ''}|'
              '${assessment.turnId ?? ''}',
          title: ConnectionWorkspaceCopy.turnContinuityLostNoticeTitle,
          message: ConnectionWorkspaceCopy.turnContinuityLostNoticeMessage,
          isLoading: false,
          tone: LiveLaneNoticeTone.warning,
          icon: Icons.warning_amber_rounded,
        ),
      ConnectionWorkspaceTurnLivenessStatus.unknown =>
        LiveLaneNoticeEntryContract(
          key:
              'turn_unknown|${assessment.threadId ?? ''}|'
              '${assessment.turnId ?? ''}',
          title: ConnectionWorkspaceCopy.turnLivenessUnknownNoticeTitle,
          message: ConnectionWorkspaceCopy.turnLivenessUnknownNoticeMessage,
          isLoading: false,
          tone: LiveLaneNoticeTone.warning,
          icon: Icons.help_outline_rounded,
        ),
    };
  }

  LiveLaneNoticeEntryContract _warningEntry(
    PocketUserFacingError warning, {
    required String key,
    required IconData icon,
  }) {
    return LiveLaneNoticeEntryContract(
      key: key,
      title: warning.title,
      message: warning.bodyWithCode,
      isLoading: false,
      tone: LiveLaneNoticeTone.warning,
      icon: icon,
    );
  }
}
