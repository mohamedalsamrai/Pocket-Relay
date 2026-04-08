import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/live_lane_notice/presentation/live_lane_notice_contract.dart';
import 'package:pocket_relay/src/features/workspace/live_lane_notice/presentation/live_lane_notice_projector.dart';

void main() {
  const projector = LiveLaneNoticeProjector();

  test(
    'projector prioritizes reconnecting over turn liveness while recovery is in flight',
    () {
      final contract = projector.project(
        liveReattachPhase: ConnectionWorkspaceLiveReattachPhase.reconnecting,
        transportRecoveryPhase: null,
        recoveryDiagnostics: null,
        remoteRuntime: null,
        turnLivenessAssessment: const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.threadHistoryTerminalTurn,
          threadId: 'thread_saved',
          turnId: 'turn_done',
        ),
        recoveryLoadWarning: null,
        deviceContinuityWarnings:
            const ConnectionWorkspaceDeviceContinuityWarnings(),
        historicalConversationRestoreState: null,
        conversationRecoveryState: null,
      );

      expect(contract, isNotNull);
      expect(contract!.entries, hasLength(1));
      expect(
        contract.entries.single,
        const LiveLaneNoticeEntryContract(
          key: 'transport_reconnecting',
          title: ConnectionWorkspaceCopy.reconnectingNoticeTitle,
          message: ConnectionWorkspaceCopy.reconnectingNoticeMessage,
          isLoading: true,
          tone: LiveLaneNoticeTone.informational,
          icon: Icons.portable_wifi_off_rounded,
        ),
      );
    },
  );

  test(
    'projector marks finished-while-away as dismissible after visible dwell',
    () {
      final contract = projector.project(
        liveReattachPhase: null,
        transportRecoveryPhase: null,
        recoveryDiagnostics: null,
        remoteRuntime: null,
        turnLivenessAssessment: const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.threadHistoryTerminalTurn,
          threadId: 'thread_saved',
          turnId: 'turn_done',
        ),
        recoveryLoadWarning: null,
        deviceContinuityWarnings:
            const ConnectionWorkspaceDeviceContinuityWarnings(),
        historicalConversationRestoreState: null,
        conversationRecoveryState: null,
      );

      expect(contract, isNotNull);
      expect(contract!.entries, hasLength(1));
      expect(
        contract.dismissibleEntry?.key,
        'turn_finished_while_away|thread_saved|turn_done',
      );
      expect(
        contract.dismissibleEntry?.dismissAfterVisibleDuration,
        LiveLaneNoticeProjector.finishedWhileAwayVisibilityDuration,
      );
      expect(
        contract.dismissibleEntry?.dismissAction,
        LiveLaneNoticeDismissAction.finishedWhileAway,
      );
    },
  );

  test(
    'projector omits recovery notices while conversation recovery is active',
    () {
      final contract = projector.project(
        liveReattachPhase: ConnectionWorkspaceLiveReattachPhase.reconnecting,
        transportRecoveryPhase: null,
        recoveryDiagnostics: null,
        remoteRuntime: null,
        turnLivenessAssessment: const ConnectionWorkspaceTurnLivenessAssessment(
          status: ConnectionWorkspaceTurnLivenessStatus.stillLive,
          evidence:
              ConnectionWorkspaceTurnLivenessEvidence.activeTurnReattached,
          threadId: 'thread_saved',
          turnId: 'turn_live',
        ),
        recoveryLoadWarning: null,
        deviceContinuityWarnings:
            const ConnectionWorkspaceDeviceContinuityWarnings(),
        historicalConversationRestoreState: null,
        conversationRecoveryState: const ChatConversationRecoveryState(
          reason: ChatConversationRecoveryReason.detachedTranscript,
          expectedThreadId: 'thread_saved',
        ),
      );

      expect(contract, isNull);
    },
  );
}
