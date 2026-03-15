import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

class ChatTranscriptSurfaceProjector {
  const ChatTranscriptSurfaceProjector();

  ChatTranscriptSurfaceContract project({
    required ConnectionProfile profile,
    required CodexSessionState sessionState,
  }) {
    final mainItems = sessionState.transcriptBlocks
        .map((block) => ChatTranscriptItemContract(block: block))
        .toList(growable: false);
    final pinnedItems = <ChatTranscriptItemContract>[
      if (sessionState.primaryPendingApprovalBlock case final block?)
        ChatTranscriptItemContract(block: block),
      if (sessionState.primaryPendingUserInputBlock case final block?)
        ChatTranscriptItemContract(block: block),
    ];
    final hasVisibleConversation =
        mainItems.isNotEmpty || pinnedItems.isNotEmpty;

    return ChatTranscriptSurfaceContract(
      isConfigured: profile.isReady,
      mainItems: mainItems,
      pinnedItems: pinnedItems,
      emptyState: hasVisibleConversation
          ? null
          : ChatEmptyStateContract(isConfigured: profile.isReady),
    );
  }
}
