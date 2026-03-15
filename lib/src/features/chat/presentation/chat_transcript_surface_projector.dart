import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_projector.dart';

class ChatTranscriptSurfaceProjector {
  const ChatTranscriptSurfaceProjector({
    ChatTranscriptItemProjector itemProjector =
        const ChatTranscriptItemProjector(),
    ChatRequestProjector requestProjector = const ChatRequestProjector(),
  }) : _itemProjector = itemProjector,
       _requestProjector = requestProjector;

  final ChatTranscriptItemProjector _itemProjector;
  final ChatRequestProjector _requestProjector;

  ChatTranscriptSurfaceContract project({
    required ConnectionProfile profile,
    required CodexSessionState sessionState,
  }) {
    final mainItems = sessionState.transcriptBlocks
        .map(_itemProjector.project)
        .toList(growable: false);
    final pinnedItems = <ChatTranscriptItemContract>[
      if (sessionState.primaryPendingApprovalRequest case final request?)
        ChatApprovalRequestItemContract(
          request: _requestProjector.projectPendingApprovalRequest(request),
        ),
      if (sessionState.primaryPendingUserInputRequest case final request?)
        ChatUserInputRequestItemContract(
          request: _requestProjector.projectPendingUserInputRequest(request),
        ),
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
