import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_snackbar.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_capability_assets.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_errors.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/domain/workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/live_lane_notice/presentation/live_lane_notice_host.dart';
import 'package:pocket_relay/src/features/workspace/live_lane_notice/presentation/live_lane_notice_projector.dart';

import 'workspace_conversation_history_sheet.dart';

part 'workspace_live_lane_surface_binding.dart';
part 'workspace_live_lane_surface_connectivity.dart';
part 'workspace_live_lane_surface_menu.dart';
part 'workspace_live_lane_surface_settings.dart';
part 'workspace_live_lane_surface_status.dart';

class ConnectionWorkspaceLiveLaneSurface extends StatefulWidget {
  const ConnectionWorkspaceLiveLaneSurface({
    super.key,
    required this.workspaceController,
    required this.laneBinding,
    required this.platformPolicy,
    this.conversationHistoryRepository,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionLaneBinding laneBinding;
  final PocketPlatformPolicy platformPolicy;
  final WorkspaceConversationHistoryRepository? conversationHistoryRepository;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  State<ConnectionWorkspaceLiveLaneSurface> createState() =>
      _ConnectionWorkspaceLiveLaneSurfaceState();
}

class _ConnectionWorkspaceLiveLaneSurfaceState
    extends State<ConnectionWorkspaceLiveLaneSurface> {
  static const LiveLaneNoticeProjector _liveLaneNoticeProjector =
      LiveLaneNoticeProjector();
  bool _isOpeningConnectionSettings = false;
  bool _isRestartingLane = false;
  bool _isRefreshingLaneRemoteRuntime = false;
  bool _isConnectingLaneTransport = false;
  bool _isDisconnectingLaneTransport = false;
  ConnectionSettingsRemoteServerActionId? _activeLaneRemoteServerAction;
  StreamSubscription<AgentAdapterEvent>? _laneAgentAdapterEventSubscription;

  @override
  void initState() {
    super.initState();
    _attachLaneBindingListeners(widget.laneBinding);
  }

  @override
  void didUpdateWidget(covariant ConnectionWorkspaceLiveLaneSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.laneBinding == widget.laneBinding) {
      return;
    }

    _detachLaneBindingListeners(oldWidget.laneBinding);
    _resetLaneViewFlags();
    _attachLaneBindingListeners(widget.laneBinding);
  }

  @override
  void dispose() {
    _detachLaneBindingListeners(widget.laneBinding);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = widget.workspaceController.state;
    final reconnectRequirement = workspaceState.reconnectRequirementFor(
      widget.laneBinding.connectionId,
    );
    final transportRecoveryPhase = workspaceState.transportRecoveryPhaseFor(
      widget.laneBinding.connectionId,
    );
    final liveReattachPhase = workspaceState.liveReattachPhaseFor(
      widget.laneBinding.connectionId,
    );
    final recoveryDiagnostics = workspaceState.recoveryDiagnosticsFor(
      widget.laneBinding.connectionId,
    );
    final turnLivenessAssessment = workspaceState.turnLivenessAssessmentFor(
      widget.laneBinding.connectionId,
    );
    final recoveryLoadWarning = workspaceState.recoveryLoadWarning;
    final deviceContinuityWarnings = workspaceState.deviceContinuityWarnings;
    final remoteRuntime = workspaceState.remoteRuntimeFor(
      widget.laneBinding.connectionId,
    );
    final laneNoticeContract = _liveLaneNoticeProjector.project(
      liveReattachPhase: liveReattachPhase,
      transportRecoveryPhase: transportRecoveryPhase,
      recoveryDiagnostics: recoveryDiagnostics,
      remoteRuntime: remoteRuntime,
      turnLivenessAssessment: turnLivenessAssessment,
      recoveryLoadWarning: recoveryLoadWarning,
      deviceContinuityWarnings: deviceContinuityWarnings,
      historicalConversationRestoreState: widget
          .laneBinding
          .sessionController
          .historicalConversationRestoreState,
      conversationRecoveryState:
          widget.laneBinding.sessionController.conversationRecoveryState,
    );
    final profile = widget.laneBinding.sessionController.profile;
    final sessionState = widget.laneBinding.sessionController.sessionState;
    final isLaneBusy = sessionState.isBusy;
    final showsEmptyState =
        sessionState.transcriptBlocks.isEmpty &&
        sessionState.pendingApprovalRequests.isEmpty &&
        sessionState.pendingUserInputRequests.isEmpty;
    final isTransportReconnectInProgress =
        transportRecoveryPhase ==
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting;
    final isRestartInProgress =
        _isRestartingLane || isTransportReconnectInProgress;
    final laneNotice = laneNoticeContract == null
        ? null
        : LiveLaneNoticeHost(
            workspaceController: widget.workspaceController,
            connectionId: widget.laneBinding.connectionId,
            isVisible:
                workspaceState.isShowingLiveLane &&
                workspaceState.selectedConnectionId ==
                    widget.laneBinding.connectionId,
            contract: laneNoticeContract,
          );
    final emptyStateContent = _buildLaneEmptyStateContent(
      profile: profile,
      reconnectRequirement: reconnectRequirement,
      transportRecoveryPhase: transportRecoveryPhase,
      liveReattachPhase: liveReattachPhase,
      remoteRuntime: remoteRuntime,
      isLaneBusy: isLaneBusy,
      isRestartInProgress: isRestartInProgress,
      recoveryNotice: laneNotice,
    );
    final chatRoot = ChatRootAdapter(
      laneBinding: widget.laneBinding,
      platformPolicy: widget.platformPolicy,
      onConnectionSettingsRequested: _handleConnectionSettingsRequested,
      supplementalMenuActions: _supplementalMenuActionsFor(
        profile: profile,
        isLaneBusy: isLaneBusy,
      ),
      supplementalStatusRegion: showsEmptyState && emptyStateContent != null
          ? null
          : _buildLaneConnectionStrip(
              context,
              profile: profile,
              reconnectRequirement: reconnectRequirement,
              transportRecoveryPhase: transportRecoveryPhase,
              liveReattachPhase: liveReattachPhase,
              remoteRuntime: remoteRuntime,
              isLaneBusy: isLaneBusy,
              isRestartInProgress: isRestartInProgress,
              recoveryNotice: laneNotice,
            ),
      supplementalEmptyStateContent: emptyStateContent,
      flattenSupplementalEmptyStateDetails: true,
    );
    return chatRoot;
  }
}
