import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_errors.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_guardrail_errors.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

abstract interface class ChatSessionRecoveryCoordinator {
  void startFreshConversation();
  void clearTranscript();
  void openConversationRecoveryAlternateSession();
  Future<void> selectConversationForResume(String threadId);
  Future<void> reattachConversation(String threadId);
  Future<void> retryHistoricalConversationRestore();
  Future<ChatComposerDraft?> continueFromUserMessage(String blockId);
  Future<bool> branchSelectedConversation();
}

abstract interface class ChatSessionRecoveryCoordinatorContext {
  TranscriptSessionState get sessionState;
  ChatConversationRecoveryState? get conversationRecoveryState;
  ChatHistoricalConversationRestoreState?
  get historicalConversationRestoreState;
  AgentAdapterClient get agentAdapterClient;

  void emitUserFacingError(PocketUserFacingError error);
  void applySessionState(TranscriptSessionState nextState);
  TranscriptSessionState startFreshThread({String? message});
  TranscriptSessionState clearTranscriptState();
  void invalidateHistoricalConversationRestore();
  void clearConversationRecovery();
  void clearHistoricalConversationRestoreState();
  void setSuppressTrackedThreadReuse(bool value);
  String? normalizeThreadId(String value);
  String? activeConversationThreadId();
  String? selectedConversationThreadId();
  bool hasVisibleConversationState([TranscriptSessionState? state]);
  Future<void> restoreConversationTranscript(String threadId);
  Future<void> resumeConversationThread(String threadId);
  Future<void> reattachConversationWithHistoryBaseline(String threadId);
  Future<TranscriptSessionState?> performHistoryRestoringThreadTransition({
    required Future<AgentAdapterThreadHistory> Function() operation,
    required PocketUserFacingError userFacingError,
    ChatHistoricalConversationRestoreState? loadingRestoreState,
    ChatHistoricalConversationRestoreState? emptyHistoryRestoreState,
    ChatHistoricalConversationRestoreState? failureRestoreState,
  });
}

class DefaultChatSessionRecoveryCoordinator
    implements ChatSessionRecoveryCoordinator {
  const DefaultChatSessionRecoveryCoordinator({required this.context});

  final ChatSessionRecoveryCoordinatorContext context;

  @override
  void startFreshConversation() {
    if (context.sessionState.activeTurn != null ||
        context.sessionState.isBusy) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.freshConversationBlockedByActiveTurn(),
      );
      return;
    }

    _resetConversationState(
      nextState: context.startFreshThread(
        message: 'The next prompt will start a fresh Codex thread.',
      ),
    );
  }

  @override
  void clearTranscript() {
    if (context.sessionState.activeTurn != null ||
        context.sessionState.isBusy) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.clearTranscriptBlockedByActiveTurn(),
      );
      return;
    }

    _resetConversationState(nextState: context.clearTranscriptState());
  }

  @override
  void openConversationRecoveryAlternateSession() {
    final alternateThreadId = context
        .conversationRecoveryState
        ?.alternateThreadId
        ?.trim();
    if (alternateThreadId == null || alternateThreadId.isEmpty) {
      return;
    }

    final timeline = context.sessionState.timelineForThread(alternateThreadId);
    if (timeline == null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.alternateSessionUnavailable(),
      );
      return;
    }

    final nextRegistry = <String, TranscriptThreadRegistryEntry>{
      for (final entry in context.sessionState.threadRegistry.entries)
        entry.key: entry.value.copyWith(
          isPrimary: entry.key == alternateThreadId,
        ),
    };

    context.invalidateHistoricalConversationRestore();
    context.setSuppressTrackedThreadReuse(false);
    context.clearConversationRecovery();
    context.clearHistoricalConversationRestoreState();
    context.applySessionState(
      context.sessionState.copyWith(
        rootThreadId: alternateThreadId,
        selectedThreadId: alternateThreadId,
        threadRegistry: nextRegistry,
      ),
    );
  }

  @override
  Future<void> selectConversationForResume(String threadId) async {
    final normalizedThreadId = context.normalizeThreadId(threadId);
    if (normalizedThreadId == null) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'Thread id must not be empty.',
      );
    }

    context.setSuppressTrackedThreadReuse(false);
    await context.restoreConversationTranscript(normalizedThreadId);
  }

  @override
  Future<void> reattachConversation(String threadId) async {
    final normalizedThreadId = context.normalizeThreadId(threadId);
    if (normalizedThreadId == null) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'Thread id must not be empty.',
      );
    }

    context.invalidateHistoricalConversationRestore();
    context.clearHistoricalConversationRestoreState();
    if (!context.hasVisibleConversationState()) {
      await context.reattachConversationWithHistoryBaseline(normalizedThreadId);
      return;
    }

    await context.resumeConversationThread(normalizedThreadId);
  }

  @override
  Future<void> retryHistoricalConversationRestore() async {
    final threadId = context.historicalConversationRestoreState?.threadId
        .trim();
    if (threadId == null || threadId.isEmpty) {
      return;
    }

    await context.restoreConversationTranscript(threadId);
  }

  @override
  Future<ChatComposerDraft?> continueFromUserMessage(String blockId) async {
    final normalizedBlockId = blockId.trim();
    if (normalizedBlockId.isEmpty) {
      return null;
    }
    if (context.historicalConversationRestoreState != null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.continueBlockedByTranscriptRestore(),
      );
      return null;
    }
    if (context.sessionState.activeTurn != null ||
        context.sessionState.isBusy) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.continueBlockedByActiveTurn(),
      );
      return null;
    }

    final targetThreadId = context.activeConversationThreadId();
    if (targetThreadId == null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.continueTargetUnavailable(),
      );
      return null;
    }

    final timeline = context.sessionState.timelineForThread(targetThreadId);
    final transcriptBlocks =
        timeline?.transcriptBlocks ?? context.sessionState.transcriptBlocks;
    final userMessages = transcriptBlocks
        .whereType<TranscriptUserMessageBlock>()
        .toList(growable: false);
    final targetIndex = userMessages.indexWhere(
      (block) => block.id == normalizedBlockId,
    );
    if (targetIndex < 0) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.continuePromptUnavailable(),
      );
      return null;
    }

    final targetBlock = userMessages[targetIndex];
    final numTurns = userMessages.length - targetIndex;
    if (numTurns < 1) {
      return null;
    }

    final nextState = await context.performHistoryRestoringThreadTransition(
      operation: () => context.agentAdapterClient.rollbackThread(
        threadId: targetThreadId,
        numTurns: numTurns,
      ),
      userFacingError: ChatSessionErrors.continueFromPromptFailed(),
      loadingRestoreState: ChatHistoricalConversationRestoreState(
        threadId: targetThreadId,
        phase: ChatHistoricalConversationRestorePhase.loading,
      ),
    );
    if (nextState == null) {
      return null;
    }

    return targetBlock.draft;
  }

  @override
  Future<bool> branchSelectedConversation() async {
    if (context.historicalConversationRestoreState != null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.branchBlockedByTranscriptRestore(),
      );
      return false;
    }
    if (context.sessionState.activeTurn != null ||
        context.sessionState.isBusy) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.branchBlockedByActiveTurn(),
      );
      return false;
    }

    final targetThreadId = context.selectedConversationThreadId();
    if (targetThreadId == null) {
      context.emitUserFacingError(
        ChatSessionGuardrailErrors.branchTargetUnavailable(),
      );
      return false;
    }

    final nextState = await context.performHistoryRestoringThreadTransition(
      operation: () async {
        final forkedSession = await context.agentAdapterClient.forkThread(
          threadId: targetThreadId,
          persistExtendedHistory: true,
        );
        return context.agentAdapterClient.readThreadWithTurns(
          threadId: forkedSession.threadId,
        );
      },
      userFacingError: ChatSessionErrors.branchConversationFailed(),
      loadingRestoreState: ChatHistoricalConversationRestoreState(
        threadId: targetThreadId,
        phase: ChatHistoricalConversationRestorePhase.loading,
      ),
    );
    return nextState != null;
  }

  void _resetConversationState({required TranscriptSessionState nextState}) {
    context.invalidateHistoricalConversationRestore();
    context.clearConversationRecovery();
    context.clearHistoricalConversationRestoreState();
    context.setSuppressTrackedThreadReuse(true);
    context.applySessionState(nextState);
  }
}
