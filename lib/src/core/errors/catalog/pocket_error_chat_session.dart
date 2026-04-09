import 'package:pocket_relay/src/core/errors/pocket_error_base.dart';

abstract final class ChatSessionPocketErrorCatalog {
  static const PocketErrorDefinition
  sendConversationChanged = PocketErrorDefinition(
    code: 'PR-CHAT-1101',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a prompt failed because the remote session returned a different conversation thread than Pocket Relay expected.',
  );
  static const PocketErrorDefinition
  sendConversationUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1102',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a prompt failed because the target remote conversation thread was no longer available.',
  );
  static const PocketErrorDefinition sendFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1103',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a prompt or draft failed for a generic live chat-session reason outside the known conversation-recovery states.',
  );
  static const PocketErrorDefinition
  imageSupportCheckFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1104',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a draft with images failed because Pocket Relay could not connect to Codex to validate image-input support.',
  );

  static const PocketErrorDefinition
  conversationLoadFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1201',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Loading a saved conversation transcript into the active chat lane failed.',
  );
  static const PocketErrorDefinition
  continueFromPromptFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1202',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt failed because Pocket Relay could not rewind the active conversation state from Codex.',
  );
  static const PocketErrorDefinition
  branchConversationFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1203',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation failed because Pocket Relay could not fork and restore the new Codex conversation state.',
  );

  static const PocketErrorDefinition stopTurnFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1301',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Stopping the active Codex turn failed for the selected live chat lane.',
  );

  static const PocketErrorDefinition
  submitUserInputFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1401',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Submitting requested user input back to the active Codex session failed.',
  );
  static const PocketErrorDefinition approveRequestFailed =
      PocketErrorDefinition(
        code: 'PR-CHAT-1402',
        domain: PocketErrorDomain.chatSession,
        meaning: 'Approving a pending live-session request failed.',
      );
  static const PocketErrorDefinition denyRequestFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1403',
    domain: PocketErrorDomain.chatSession,
    meaning: 'Denying a pending live-session request failed.',
  );
  static const PocketErrorDefinition
  rejectUnsupportedRequestFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1404',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Rejecting an unsupported app-server request from the active live session failed.',
  );
  static const PocketErrorDefinition
  userInputRequestUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1405',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Submitting user input was blocked because the target request was no longer pending in the active chat session.',
  );
  static const PocketErrorDefinition
  approvalRequestUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1406',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Resolving an approval request was blocked because the target request was no longer pending in the active chat session.',
  );

  static const PocketErrorDefinition
  hostFingerprintPromptUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1501',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Saving an observed host fingerprint was blocked because the referenced host-key prompt was no longer available in the transcript.',
  );
  static const PocketErrorDefinition
  hostFingerprintConflict = PocketErrorDefinition(
    code: 'PR-CHAT-1502',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Saving an observed host fingerprint was blocked because the profile already stores a different pinned fingerprint.',
  );
  static const PocketErrorDefinition
  hostFingerprintSaveFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1503',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Saving an observed host fingerprint failed because Pocket Relay could not persist the updated profile.',
  );
  static const PocketErrorDefinition
  remoteConfigurationRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1504',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the remote connection profile is incomplete.',
  );
  static const PocketErrorDefinition
  localConfigurationRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1505',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the selected local agent-adapter profile is incomplete.',
  );
  static const PocketErrorDefinition
  localModeUnsupported = PocketErrorDefinition(
    code: 'PR-CHAT-1506',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because local agent-adapter mode is unavailable on the current platform.',
  );
  static const PocketErrorDefinition
  sshPasswordRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1507',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the selected remote profile requires an SSH password that is not present.',
  );
  static const PocketErrorDefinition privateKeyRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1508',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the selected remote profile requires a private key that is not present.',
  );
  static const PocketErrorDefinition
  imageInputUnsupported = PocketErrorDefinition(
    code: 'PR-CHAT-1509',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a draft was blocked because the effective model does not support image inputs.',
  );
  static const PocketErrorDefinition
  liveTurnSteeringUnsupported = PocketErrorDefinition(
    code: 'PR-CHAT-1510',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending additional user input was blocked because the current agent adapter does not support steering an already running live turn.',
  );

  static const PocketErrorDefinition
  freshConversationBlocked = PocketErrorDefinition(
    code: 'PR-CHAT-1601',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Starting a fresh conversation was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  clearTranscriptBlocked = PocketErrorDefinition(
    code: 'PR-CHAT-1602',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Clearing the transcript was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  alternateSessionUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1603',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Switching to the alternate recovered session was blocked because that local session is no longer available.',
  );
  static const PocketErrorDefinition
  continueBlockedByTranscriptRestore = PocketErrorDefinition(
    code: 'PR-CHAT-1604',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because transcript restoration is still in progress.',
  );
  static const PocketErrorDefinition
  continueBlockedByActiveTurn = PocketErrorDefinition(
    code: 'PR-CHAT-1605',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  continueTargetUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1606',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because there is no resumable active conversation target yet.',
  );
  static const PocketErrorDefinition
  continuePromptUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1607',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because the selected user prompt is no longer available in the transcript.',
  );
  static const PocketErrorDefinition
  branchBlockedByTranscriptRestore = PocketErrorDefinition(
    code: 'PR-CHAT-1608',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation was blocked because transcript restoration is still in progress.',
  );
  static const PocketErrorDefinition
  branchBlockedByActiveTurn = PocketErrorDefinition(
    code: 'PR-CHAT-1609',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  branchTargetUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1610',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation was blocked because there is no selectable conversation target yet.',
  );

  static const PocketErrorDefinition
  modelCatalogHydrationFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1801',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Refreshing the best-effort live model catalog after transport connection failed, so capability checks may remain incomplete until a later retry succeeds.',
  );
  static const PocketErrorDefinition
  threadMetadataHydrationFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1802',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Reading best-effort child-thread metadata failed, so timeline labels may remain incomplete until later runtime data fills them in.',
  );

  static const List<PocketErrorDefinition> definitions =
      <PocketErrorDefinition>[
        sendConversationChanged,
        sendConversationUnavailable,
        sendFailed,
        imageSupportCheckFailed,
        conversationLoadFailed,
        continueFromPromptFailed,
        branchConversationFailed,
        stopTurnFailed,
        submitUserInputFailed,
        approveRequestFailed,
        denyRequestFailed,
        rejectUnsupportedRequestFailed,
        userInputRequestUnavailable,
        approvalRequestUnavailable,
        hostFingerprintPromptUnavailable,
        hostFingerprintConflict,
        hostFingerprintSaveFailed,
        remoteConfigurationRequired,
        localConfigurationRequired,
        localModeUnsupported,
        sshPasswordRequired,
        privateKeyRequired,
        imageInputUnsupported,
        liveTurnSteeringUnsupported,
        freshConversationBlocked,
        clearTranscriptBlocked,
        alternateSessionUnavailable,
        continueBlockedByTranscriptRestore,
        continueBlockedByActiveTurn,
        continueTargetUnavailable,
        continuePromptUnavailable,
        branchBlockedByTranscriptRestore,
        branchBlockedByActiveTurn,
        branchTargetUnavailable,
        modelCatalogHydrationFailed,
        threadMetadataHydrationFailed,
      ];
}
