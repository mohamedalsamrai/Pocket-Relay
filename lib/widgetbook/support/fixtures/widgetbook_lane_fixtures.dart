import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_fixture_foundation.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_ssh_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_transcript_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_worklog_fixtures.dart';

abstract final class WidgetbookLaneFixtures {
  static ChatTranscriptSurfaceContract denseTranscriptSurface() {
    return ChatTranscriptSurfaceContract(
      isConfigured: true,
      mainItems: <ChatTranscriptItemContract>[
        ChatUserMessageItemContract(
          block: WidgetbookTranscriptFixtures.userMessage(),
        ),
        ChatReasoningItemContract(
          block: WidgetbookTranscriptFixtures.reasoningBlock(isRunning: true),
        ),
        ChatPlanUpdateItemContract(
          block: WidgetbookTranscriptFixtures.planUpdateBlock(),
        ),
        ChatWorkLogGroupItemContract(
          id: 'lane_work_log',
          entries: WidgetbookWorkLogFixtures.workLogGroupItem().entries,
        ),
        WidgetbookWorkLogFixtures.execCommandItem(),
        ChatChangedFilesItemContract(
          id: 'lane_changed_files',
          title: WidgetbookWorkLogFixtures.changedFilesItem().title,
          isRunning: false,
          headerStats: WidgetbookWorkLogFixtures.changedFilesItem().headerStats,
          rows: WidgetbookWorkLogFixtures.changedFilesItem().rows,
        ),
        ChatAssistantMessageItemContract(
          block: WidgetbookTranscriptFixtures.assistantMessage(
            body:
                'I found the regression in the preview wrappers and removed the extra story-owned framing from the lane surfaces.',
          ),
        ),
        ChatSshItemContract(
          block: WidgetbookSshFixtures.sshAuthenticationFailedBlock(),
        ),
        ChatContextCompactedItemContract(
          block: WidgetbookTranscriptFixtures.contextCompactedBlock(),
        ),
        ChatStatusItemContract(
          block: WidgetbookTranscriptFixtures.statusBlock(),
        ),
        ChatUsageItemContract(block: WidgetbookTranscriptFixtures.usageBlock()),
        ChatTurnBoundaryItemContract(
          block: WidgetbookTranscriptFixtures.turnBoundaryBlock(),
        ),
      ],
      pinnedItems: const <ChatTranscriptItemContract>[],
      pendingRequestPlacement: ChatPendingRequestPlacementContract(
        visibleApprovalRequest: null,
        visibleUserInputRequest: null,
      ),
      activePendingUserInputRequestIds: const <String>{},
    );
  }

  static ChatScreenContract denseTranscriptLaneScreen({
    PocketPlatformBehavior platformBehavior =
        WidgetbookFixtureFoundation.desktopBehavior,
  }) {
    return ChatScreenContract(
      isLoading: false,
      header: const ChatHeaderContract(
        title: 'Pocket Relay',
        subtitle: 'Developer Box · relay-dev.internal',
      ),
      actions: const <ChatScreenActionContract>[
        ChatScreenActionContract(
          id: ChatScreenActionId.openSettings,
          label: 'Connection settings',
          placement: ChatScreenActionPlacement.toolbar,
          tooltip: 'Connection settings',
          icon: ChatScreenActionIcon.settings,
        ),
        ChatScreenActionContract(
          id: ChatScreenActionId.newThread,
          label: 'New thread',
          placement: ChatScreenActionPlacement.menu,
        ),
      ],
      transcriptSurface: denseTranscriptSurface(),
      transcriptFollow: const ChatTranscriptFollowContract(
        isAutoFollowEnabled: true,
        resumeDistance: 72,
      ),
      composer: ChatComposerContract(
        draft: ChatComposerDraft(
          text: platformBehavior.usesDesktopKeyboardSubmit
              ? 'Summarize the lane and call out the highest-risk state.'
              : '',
        ),
        isSendActionEnabled: true,
        placeholder: 'Message Pocket Relay',
      ),
      connectionSettings: ChatConnectionSettingsLaunchContract(
        initialProfile: WidgetbookFixtureFoundation.remoteProfile,
        initialSecrets: WidgetbookFixtureFoundation.passwordSecrets,
      ),
    );
  }
}
