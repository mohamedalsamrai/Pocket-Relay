import 'package:pocket_relay/src/core/errors/catalog/pocket_error_app_bootstrap.dart';
import 'package:pocket_relay/src/core/errors/catalog/pocket_error_chat_composer.dart';
import 'package:pocket_relay/src/core/errors/catalog/pocket_error_chat_session.dart';
import 'package:pocket_relay/src/core/errors/catalog/pocket_error_connection_lifecycle.dart';
import 'package:pocket_relay/src/core/errors/catalog/pocket_error_connection_settings.dart';
import 'package:pocket_relay/src/core/errors/catalog/pocket_error_device_capability.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_base.dart';

export 'package:pocket_relay/src/core/errors/pocket_error_base.dart'
    show PocketErrorDefinition, PocketErrorDomain, PocketUserFacingError;

abstract final class PocketErrorCatalog {
  static const PocketErrorDefinition connectionOpenRemoteHostProbeFailed =
      ConnectionLifecyclePocketErrorCatalog.connectionOpenRemoteHostProbeFailed;
  static const PocketErrorDefinition connectionOpenRemoteContinuityUnsupported =
      ConnectionLifecyclePocketErrorCatalog
          .connectionOpenRemoteContinuityUnsupported;
  static const PocketErrorDefinition connectionOpenRemoteServerStopped =
      ConnectionLifecyclePocketErrorCatalog.connectionOpenRemoteServerStopped;
  static const PocketErrorDefinition connectionOpenRemoteServerUnhealthy =
      ConnectionLifecyclePocketErrorCatalog.connectionOpenRemoteServerUnhealthy;
  static const PocketErrorDefinition connectionOpenRemoteAttachUnavailable =
      ConnectionLifecyclePocketErrorCatalog
          .connectionOpenRemoteAttachUnavailable;
  static const PocketErrorDefinition connectionOpenRemoteUnexpectedFailure =
      ConnectionLifecyclePocketErrorCatalog
          .connectionOpenRemoteUnexpectedFailure;
  static const PocketErrorDefinition connectionOpenLocalUnexpectedFailure =
      ConnectionLifecyclePocketErrorCatalog
          .connectionOpenLocalUnexpectedFailure;
  static const PocketErrorDefinition connectionStartServerHostProbeFailed =
      ConnectionLifecyclePocketErrorCatalog
          .connectionStartServerHostProbeFailed;
  static const PocketErrorDefinition
  connectionStartServerContinuityUnsupported =
      ConnectionLifecyclePocketErrorCatalog
          .connectionStartServerContinuityUnsupported;
  static const PocketErrorDefinition connectionStartServerStillStopped =
      ConnectionLifecyclePocketErrorCatalog.connectionStartServerStillStopped;
  static const PocketErrorDefinition connectionStartServerUnhealthy =
      ConnectionLifecyclePocketErrorCatalog.connectionStartServerUnhealthy;
  static const PocketErrorDefinition connectionStartServerUnexpectedFailure =
      ConnectionLifecyclePocketErrorCatalog
          .connectionStartServerUnexpectedFailure;
  static const PocketErrorDefinition connectionStopServerHostProbeFailed =
      ConnectionLifecyclePocketErrorCatalog.connectionStopServerHostProbeFailed;
  static const PocketErrorDefinition connectionStopServerContinuityUnsupported =
      ConnectionLifecyclePocketErrorCatalog
          .connectionStopServerContinuityUnsupported;
  static const PocketErrorDefinition connectionStopServerStillRunning =
      ConnectionLifecyclePocketErrorCatalog.connectionStopServerStillRunning;
  static const PocketErrorDefinition connectionStopServerStillUnhealthy =
      ConnectionLifecyclePocketErrorCatalog.connectionStopServerStillUnhealthy;
  static const PocketErrorDefinition connectionStopServerUnexpectedFailure =
      ConnectionLifecyclePocketErrorCatalog
          .connectionStopServerUnexpectedFailure;
  static const PocketErrorDefinition connectionRestartServerHostProbeFailed =
      ConnectionLifecyclePocketErrorCatalog
          .connectionRestartServerHostProbeFailed;
  static const PocketErrorDefinition
  connectionRestartServerContinuityUnsupported =
      ConnectionLifecyclePocketErrorCatalog
          .connectionRestartServerContinuityUnsupported;
  static const PocketErrorDefinition connectionRestartServerStopped =
      ConnectionLifecyclePocketErrorCatalog.connectionRestartServerStopped;
  static const PocketErrorDefinition connectionRestartServerUnhealthy =
      ConnectionLifecyclePocketErrorCatalog.connectionRestartServerUnhealthy;
  static const PocketErrorDefinition connectionRestartServerUnexpectedFailure =
      ConnectionLifecyclePocketErrorCatalog
          .connectionRestartServerUnexpectedFailure;
  static const PocketErrorDefinition connectionTransportLost =
      ConnectionLifecyclePocketErrorCatalog.connectionTransportLost;
  static const PocketErrorDefinition connectionTransportUnavailable =
      ConnectionLifecyclePocketErrorCatalog.connectionTransportUnavailable;
  static const PocketErrorDefinition connectionReconnectContinuityUnsupported =
      ConnectionLifecyclePocketErrorCatalog
          .connectionReconnectContinuityUnsupported;
  static const PocketErrorDefinition connectionReconnectHostProbeFailed =
      ConnectionLifecyclePocketErrorCatalog.connectionReconnectHostProbeFailed;
  static const PocketErrorDefinition connectionReconnectServerStopped =
      ConnectionLifecyclePocketErrorCatalog.connectionReconnectServerStopped;
  static const PocketErrorDefinition connectionReconnectServerUnhealthy =
      ConnectionLifecyclePocketErrorCatalog.connectionReconnectServerUnhealthy;
  static const PocketErrorDefinition connectionLiveReattachFallbackRestore =
      ConnectionLifecyclePocketErrorCatalog
          .connectionLiveReattachFallbackRestore;
  static const PocketErrorDefinition connectionRuntimeProbeFailed =
      ConnectionLifecyclePocketErrorCatalog.connectionRuntimeProbeFailed;
  static const PocketErrorDefinition connectionDisconnectLaneFailed =
      ConnectionLifecyclePocketErrorCatalog.connectionDisconnectLaneFailed;
  static const PocketErrorDefinition connectionHistoryLoadFailed =
      ConnectionLifecyclePocketErrorCatalog.connectionHistoryLoadFailed;
  static const PocketErrorDefinition connectionHistoryHostKeyUnpinned =
      ConnectionLifecyclePocketErrorCatalog.connectionHistoryHostKeyUnpinned;
  static const PocketErrorDefinition connectionHistoryServerStopped =
      ConnectionLifecyclePocketErrorCatalog.connectionHistoryServerStopped;
  static const PocketErrorDefinition connectionHistoryServerUnhealthy =
      ConnectionLifecyclePocketErrorCatalog.connectionHistoryServerUnhealthy;
  static const PocketErrorDefinition connectionHistorySessionUnavailable =
      ConnectionLifecyclePocketErrorCatalog.connectionHistorySessionUnavailable;

  static const PocketErrorDefinition chatSessionSendConversationChanged =
      ChatSessionPocketErrorCatalog.sendConversationChanged;
  static const PocketErrorDefinition chatSessionSendConversationUnavailable =
      ChatSessionPocketErrorCatalog.sendConversationUnavailable;
  static const PocketErrorDefinition chatSessionSendFailed =
      ChatSessionPocketErrorCatalog.sendFailed;
  static const PocketErrorDefinition chatSessionImageSupportCheckFailed =
      ChatSessionPocketErrorCatalog.imageSupportCheckFailed;
  static const PocketErrorDefinition chatSessionConversationLoadFailed =
      ChatSessionPocketErrorCatalog.conversationLoadFailed;
  static const PocketErrorDefinition chatSessionContinueFromPromptFailed =
      ChatSessionPocketErrorCatalog.continueFromPromptFailed;
  static const PocketErrorDefinition chatSessionBranchConversationFailed =
      ChatSessionPocketErrorCatalog.branchConversationFailed;
  static const PocketErrorDefinition chatSessionStopTurnFailed =
      ChatSessionPocketErrorCatalog.stopTurnFailed;
  static const PocketErrorDefinition chatSessionSubmitUserInputFailed =
      ChatSessionPocketErrorCatalog.submitUserInputFailed;
  static const PocketErrorDefinition chatSessionApproveRequestFailed =
      ChatSessionPocketErrorCatalog.approveRequestFailed;
  static const PocketErrorDefinition chatSessionDenyRequestFailed =
      ChatSessionPocketErrorCatalog.denyRequestFailed;
  static const PocketErrorDefinition chatSessionRejectUnsupportedRequestFailed =
      ChatSessionPocketErrorCatalog.rejectUnsupportedRequestFailed;
  static const PocketErrorDefinition chatSessionUserInputRequestUnavailable =
      ChatSessionPocketErrorCatalog.userInputRequestUnavailable;
  static const PocketErrorDefinition chatSessionApprovalRequestUnavailable =
      ChatSessionPocketErrorCatalog.approvalRequestUnavailable;
  static const PocketErrorDefinition
  chatSessionHostFingerprintPromptUnavailable =
      ChatSessionPocketErrorCatalog.hostFingerprintPromptUnavailable;
  static const PocketErrorDefinition chatSessionHostFingerprintConflict =
      ChatSessionPocketErrorCatalog.hostFingerprintConflict;
  static const PocketErrorDefinition chatSessionHostFingerprintSaveFailed =
      ChatSessionPocketErrorCatalog.hostFingerprintSaveFailed;
  static const PocketErrorDefinition chatSessionRemoteConfigurationRequired =
      ChatSessionPocketErrorCatalog.remoteConfigurationRequired;
  static const PocketErrorDefinition chatSessionLocalConfigurationRequired =
      ChatSessionPocketErrorCatalog.localConfigurationRequired;
  static const PocketErrorDefinition chatSessionLocalModeUnsupported =
      ChatSessionPocketErrorCatalog.localModeUnsupported;
  static const PocketErrorDefinition chatSessionSshPasswordRequired =
      ChatSessionPocketErrorCatalog.sshPasswordRequired;
  static const PocketErrorDefinition chatSessionPrivateKeyRequired =
      ChatSessionPocketErrorCatalog.privateKeyRequired;
  static const PocketErrorDefinition chatSessionImageInputUnsupported =
      ChatSessionPocketErrorCatalog.imageInputUnsupported;
  static const PocketErrorDefinition chatSessionLiveTurnSteeringUnsupported =
      ChatSessionPocketErrorCatalog.liveTurnSteeringUnsupported;
  static const PocketErrorDefinition chatSessionFreshConversationBlocked =
      ChatSessionPocketErrorCatalog.freshConversationBlocked;
  static const PocketErrorDefinition chatSessionClearTranscriptBlocked =
      ChatSessionPocketErrorCatalog.clearTranscriptBlocked;
  static const PocketErrorDefinition chatSessionAlternateSessionUnavailable =
      ChatSessionPocketErrorCatalog.alternateSessionUnavailable;
  static const PocketErrorDefinition
  chatSessionContinueBlockedByTranscriptRestore =
      ChatSessionPocketErrorCatalog.continueBlockedByTranscriptRestore;
  static const PocketErrorDefinition chatSessionContinueBlockedByActiveTurn =
      ChatSessionPocketErrorCatalog.continueBlockedByActiveTurn;
  static const PocketErrorDefinition chatSessionContinueTargetUnavailable =
      ChatSessionPocketErrorCatalog.continueTargetUnavailable;
  static const PocketErrorDefinition chatSessionContinuePromptUnavailable =
      ChatSessionPocketErrorCatalog.continuePromptUnavailable;
  static const PocketErrorDefinition
  chatSessionBranchBlockedByTranscriptRestore =
      ChatSessionPocketErrorCatalog.branchBlockedByTranscriptRestore;
  static const PocketErrorDefinition chatSessionBranchBlockedByActiveTurn =
      ChatSessionPocketErrorCatalog.branchBlockedByActiveTurn;
  static const PocketErrorDefinition chatSessionBranchTargetUnavailable =
      ChatSessionPocketErrorCatalog.branchTargetUnavailable;
  static const PocketErrorDefinition chatSessionModelCatalogHydrationFailed =
      ChatSessionPocketErrorCatalog.modelCatalogHydrationFailed;
  static const PocketErrorDefinition chatSessionThreadMetadataHydrationFailed =
      ChatSessionPocketErrorCatalog.threadMetadataHydrationFailed;

  static const PocketErrorDefinition chatComposerImageAttachmentEmpty =
      ChatComposerPocketErrorCatalog.imageAttachmentEmpty;
  static const PocketErrorDefinition chatComposerImageAttachmentTooLarge =
      ChatComposerPocketErrorCatalog.imageAttachmentTooLarge;
  static const PocketErrorDefinition
  chatComposerImageAttachmentUnsupportedType =
      ChatComposerPocketErrorCatalog.imageAttachmentUnsupportedType;
  static const PocketErrorDefinition chatComposerImageAttachmentDecodeFailed =
      ChatComposerPocketErrorCatalog.imageAttachmentDecodeFailed;
  static const PocketErrorDefinition
  chatComposerImageAttachmentTooLargeForRemote =
      ChatComposerPocketErrorCatalog.imageAttachmentTooLargeForRemote;
  static const PocketErrorDefinition
  chatComposerImageAttachmentUnexpectedFailure =
      ChatComposerPocketErrorCatalog.imageAttachmentUnexpectedFailure;

  static const PocketErrorDefinition chatSessionImageAttachmentEmpty =
      chatComposerImageAttachmentEmpty;
  static const PocketErrorDefinition chatSessionImageAttachmentTooLarge =
      chatComposerImageAttachmentTooLarge;
  static const PocketErrorDefinition chatSessionImageAttachmentUnsupportedType =
      chatComposerImageAttachmentUnsupportedType;
  static const PocketErrorDefinition chatSessionImageAttachmentDecodeFailed =
      chatComposerImageAttachmentDecodeFailed;
  static const PocketErrorDefinition
  chatSessionImageAttachmentTooLargeForRemote =
      chatComposerImageAttachmentTooLargeForRemote;
  static const PocketErrorDefinition
  chatSessionImageAttachmentUnexpectedFailure =
      chatComposerImageAttachmentUnexpectedFailure;

  static const PocketErrorDefinition connectionSettingsModelCatalogUnavailable =
      ConnectionSettingsPocketErrorCatalog.modelCatalogUnavailable;
  static const PocketErrorDefinition
  connectionSettingsModelCatalogRefreshFailed =
      ConnectionSettingsPocketErrorCatalog.modelCatalogRefreshFailed;
  static const PocketErrorDefinition
  connectionSettingsModelCatalogConnectionCacheSaveFailed =
      ConnectionSettingsPocketErrorCatalog
          .modelCatalogConnectionCacheSaveFailed;
  static const PocketErrorDefinition
  connectionSettingsModelCatalogLastKnownCacheSaveFailed =
      ConnectionSettingsPocketErrorCatalog.modelCatalogLastKnownCacheSaveFailed;
  static const PocketErrorDefinition
  connectionSettingsModelCatalogCachePersistenceFailed =
      ConnectionSettingsPocketErrorCatalog.modelCatalogCachePersistenceFailed;
  static const PocketErrorDefinition
  connectionSettingsRemoteRuntimeProbeFailed =
      ConnectionSettingsPocketErrorCatalog.remoteRuntimeProbeFailed;

  static const PocketErrorDefinition appBootstrapWorkspaceInitializationFailed =
      AppBootstrapPocketErrorCatalog.workspaceInitializationFailed;
  static const PocketErrorDefinition appBootstrapRecoveryStateLoadFailed =
      AppBootstrapPocketErrorCatalog.recoveryStateLoadFailed;

  static const PocketErrorDefinition
  deviceForegroundServicePermissionQueryFailed =
      DeviceCapabilityPocketErrorCatalog.foregroundServicePermissionQueryFailed;
  static const PocketErrorDefinition
  deviceForegroundServicePermissionRequestFailed =
      DeviceCapabilityPocketErrorCatalog
          .foregroundServicePermissionRequestFailed;
  static const PocketErrorDefinition deviceForegroundServiceEnableFailed =
      DeviceCapabilityPocketErrorCatalog.foregroundServiceEnableFailed;
  static const PocketErrorDefinition deviceBackgroundGraceEnableFailed =
      DeviceCapabilityPocketErrorCatalog.backgroundGraceEnableFailed;
  static const PocketErrorDefinition deviceWakeLockEnableFailed =
      DeviceCapabilityPocketErrorCatalog.wakeLockEnableFailed;
  static const PocketErrorDefinition
  deviceTurnCompletionAlertPermissionQueryFailed =
      DeviceCapabilityPocketErrorCatalog
          .turnCompletionAlertPermissionQueryFailed;
  static const PocketErrorDefinition
  deviceTurnCompletionAlertPermissionRequestFailed =
      DeviceCapabilityPocketErrorCatalog
          .turnCompletionAlertPermissionRequestFailed;
  static const PocketErrorDefinition
  deviceTurnCompletionAlertNotificationUpdateFailed =
      DeviceCapabilityPocketErrorCatalog
          .turnCompletionAlertNotificationUpdateFailed;
  static const PocketErrorDefinition
  deviceTurnCompletionAlertForegroundSignalFailed =
      DeviceCapabilityPocketErrorCatalog
          .turnCompletionAlertForegroundSignalFailed;

  static const List<PocketErrorDefinition> connectionLifecycleDefinitions =
      ConnectionLifecyclePocketErrorCatalog.definitions;
  static const List<PocketErrorDefinition> chatSessionDefinitions =
      ChatSessionPocketErrorCatalog.definitions;
  static const List<PocketErrorDefinition> chatComposerDefinitions =
      ChatComposerPocketErrorCatalog.definitions;
  static const List<PocketErrorDefinition> connectionSettingsDefinitions =
      ConnectionSettingsPocketErrorCatalog.definitions;
  static const List<PocketErrorDefinition> appBootstrapDefinitions =
      AppBootstrapPocketErrorCatalog.definitions;
  static const List<PocketErrorDefinition> deviceCapabilityDefinitions =
      DeviceCapabilityPocketErrorCatalog.definitions;

  static const List<PocketErrorDefinition> allDefinitions =
      <PocketErrorDefinition>[
        ...connectionLifecycleDefinitions,
        ...chatSessionDefinitions,
        ...chatComposerDefinitions,
        ...connectionSettingsDefinitions,
        ...appBootstrapDefinitions,
        ...deviceCapabilityDefinitions,
      ];

  static final Map<String, PocketErrorDefinition> _definitionsByCode =
      <String, PocketErrorDefinition>{
        for (final definition in allDefinitions) definition.code: definition,
      };

  static PocketErrorDefinition? lookup(String code) => _definitionsByCode[code];
}
