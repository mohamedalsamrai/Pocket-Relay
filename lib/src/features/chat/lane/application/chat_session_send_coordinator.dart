import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/utils/shell_utils.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_conversation_recovery_policy.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_errors.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_guardrail_errors.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';

abstract interface class ChatSessionSendCoordinator {
  Future<void> saveObservedHostFingerprint(String blockId);
  Future<bool> sendPrompt(String prompt);
  Future<bool> sendDraft(ChatComposerDraft draft);
  Future<void> stopActiveTurn();
}

abstract interface class ChatSessionSendCoordinatorContext {
  ConnectionProfile get profile;
  ConnectionSecrets get secrets;
  TranscriptSessionState get sessionState;
  ChatConversationRecoveryState? get conversationRecoveryState;
  ChatHistoricalConversationRestoreState?
  get historicalConversationRestoreState;
  ChatConversationRecoveryPolicy get conversationRecoveryPolicy;
  AgentAdapterClient get agentAdapterClient;
  bool get supportsLocalConnectionMode;

  TranscriptSshUnpinnedHostKeyBlock? findUnpinnedHostKeyBlock(String blockId);
  Future<void> persistProfile(ConnectionProfile profile);
  void updateProfile(ConnectionProfile profile);
  void emitUserFacingError(PocketUserFacingError error);
  void applySessionState(TranscriptSessionState nextState);
  TranscriptSessionState markUnpinnedHostKeySaved(String blockId);
  TranscriptSessionState addUserMessage({
    required String text,
    ChatComposerDraft? draft,
  });
  void selectTimeline(String threadId);
  String? activeConversationThreadId();
  String? trackedThreadReuseCandidate();
  void setConversationRecovery(ChatConversationRecoveryState nextState);
  bool canSendAdditionalInputToCurrentTurn();
  Future<bool> ensureImageInputsSupportedForDraft(ChatComposerDraft draft);
  Future<bool> sendPromptWithAppServer(String prompt);
  Future<bool> sendDraftWithAppServer(ChatComposerDraft draft);
  Future<void> stopAppServerTurn();
}

class DefaultChatSessionSendCoordinator implements ChatSessionSendCoordinator {
  const DefaultChatSessionSendCoordinator({required this.context});

  final ChatSessionSendCoordinatorContext context;

  @override
  Future<void> saveObservedHostFingerprint(String blockId) async {
    final block = context.findUnpinnedHostKeyBlock(blockId);
    if (block == null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.hostFingerprintPromptUnavailable(),
      );
      return;
    }
    if (block.isSaved) {
      return;
    }

    final currentFingerprint = context.profile.hostFingerprint.trim();
    if (currentFingerprint.isNotEmpty) {
      if (normalizeFingerprint(currentFingerprint) ==
          normalizeFingerprint(block.fingerprint)) {
        context.applySessionState(context.markUnpinnedHostKeySaved(blockId));
        return;
      }

      context.emitUserFacingError(
        ChatSessionGuardrailErrors.hostFingerprintConflict(),
      );
      return;
    }

    final nextProfile = context.profile.copyWith(
      hostFingerprint: block.fingerprint,
    );

    try {
      await context.persistProfile(nextProfile);
    } catch (error) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.hostFingerprintSaveFailed(error: error),
      );
      return;
    }

    context.updateProfile(nextProfile);
    context.applySessionState(context.markUnpinnedHostKeySaved(blockId));
  }

  @override
  Future<bool> sendPrompt(String prompt) async {
    final normalizedPrompt = prompt.trim();
    if (normalizedPrompt.isEmpty ||
        context.conversationRecoveryState != null ||
        context.historicalConversationRestoreState != null) {
      return false;
    }

    final validationError = _validateProfileForSend();
    if (validationError != null) {
      context.emitUserFacingError(validationError);
      return false;
    }

    final rootThreadId = context.sessionState.rootThreadId;
    if (rootThreadId != null &&
        context.sessionState.currentThreadId != rootThreadId) {
      context.selectTimeline(rootThreadId);
    }

    final recoveryState = context.conversationRecoveryPolicy
        .preflightRecoveryState(
          sessionState: context.sessionState,
          activeThreadId: context.activeConversationThreadId(),
          trackedThreadId: context.trackedThreadReuseCandidate(),
        );
    if (recoveryState != null) {
      context.setConversationRecovery(recoveryState);
      return false;
    }
    if (!context.canSendAdditionalInputToCurrentTurn()) {
      return false;
    }

    context.applySessionState(context.addUserMessage(text: normalizedPrompt));
    return context.sendPromptWithAppServer(normalizedPrompt);
  }

  @override
  Future<bool> sendDraft(ChatComposerDraft draft) async {
    final normalizedDraft = draft.normalized();
    if (normalizedDraft.isEmpty ||
        context.conversationRecoveryState != null ||
        context.historicalConversationRestoreState != null) {
      return false;
    }

    final validationError = _validateProfileForSend();
    if (validationError != null) {
      context.emitUserFacingError(validationError);
      return false;
    }
    if (!await context.ensureImageInputsSupportedForDraft(normalizedDraft)) {
      return false;
    }

    final rootThreadId = context.sessionState.rootThreadId;
    if (rootThreadId != null &&
        context.sessionState.currentThreadId != rootThreadId) {
      context.selectTimeline(rootThreadId);
    }

    final recoveryState = context.conversationRecoveryPolicy
        .preflightRecoveryState(
          sessionState: context.sessionState,
          activeThreadId: context.activeConversationThreadId(),
          trackedThreadId: context.trackedThreadReuseCandidate(),
        );
    if (recoveryState != null) {
      context.setConversationRecovery(recoveryState);
      return false;
    }
    if (!context.canSendAdditionalInputToCurrentTurn()) {
      return false;
    }

    context.applySessionState(
      context.addUserMessage(
        text: normalizedDraft.text,
        draft: normalizedDraft,
      ),
    );
    return context.sendDraftWithAppServer(normalizedDraft);
  }

  @override
  Future<void> stopActiveTurn() {
    return context.stopAppServerTurn();
  }

  PocketUserFacingError? _validateProfileForSend() {
    if (!context.profile.isReady) {
      return switch (context.profile.connectionMode) {
        ConnectionMode.remote =>
          ChatSessionGuardrailErrors.remoteConnectionDetailsRequired(),
        ConnectionMode.local =>
          ChatSessionGuardrailErrors.localConfigurationRequired(),
      };
    }
    if (context.profile.connectionMode == ConnectionMode.local) {
      if (!context.supportsLocalConnectionMode) {
        return ChatSessionGuardrailErrors.localModeUnsupported();
      }
      return null;
    }
    if (context.profile.authMode == AuthMode.password &&
        !context.secrets.hasPassword) {
      return ChatSessionGuardrailErrors.sshPasswordRequired();
    }
    if (context.profile.authMode == AuthMode.privateKey &&
        !context.secrets.hasPrivateKey) {
      return ChatSessionGuardrailErrors.privateKeyRequired();
    }
    return null;
  }
}
