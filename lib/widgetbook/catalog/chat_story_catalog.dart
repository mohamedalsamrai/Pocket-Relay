import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_request_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/assistant_message_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/error_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/plan_update_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/proposed_plan_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/reasoning_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_auth_failed_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_connect_failed_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_host_key_mismatch_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_unpinned_host_key_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/status_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/turn_boundary_marker.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/usage_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/user_input_request_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/user_message_surface.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_surface.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/work_log_group_surface.dart';
import 'package:pocket_relay/widgetbook/catalog/story_catalog_layout.dart';
import 'package:pocket_relay/widgetbook/support/widgetbook_fixtures.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookCategory buildChatWidgetbookCategory() {
  return WidgetbookCategory(
    name: 'Chat',
    children: <WidgetbookNode>[
      WidgetbookFolder(
        name: 'Transcript',
        children: <WidgetbookNode>[
          WidgetbookComponent(
            name: 'Transcript Lane',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Desktop Filled Lane',
                builder: (_) {
                  final screen = WidgetbookFixtures.denseTranscriptLaneScreen();
                  return FlutterChatScreenRenderer(
                    platformBehavior: WidgetbookFixtures.desktopBehavior,
                    screen: screen,
                    appChrome: FlutterChatAppChrome(
                      screen: screen,
                      onScreenAction: (_) {},
                    ),
                    transcriptRegion: FlutterChatTranscriptRegion(
                      screen: screen,
                      platformBehavior: WidgetbookFixtures.desktopBehavior,
                      onScreenAction: (_) {},
                      onSelectTimeline: (_) {},
                      onSelectConnectionMode: (_) {},
                      onAutoFollowEligibilityChanged: (_) {},
                      onRequestTranscriptFollow: (_) {},
                      onOpenChangedFileDiff: (_) {},
                      onApproveRequest: (_) async {},
                      onDenyRequest: (_) async {},
                      onSubmitUserInput: (_, answers) async {},
                      onSaveHostFingerprint: (_) async {},
                    ),
                    composerRegion: FlutterChatComposerRegion(
                      platformBehavior: WidgetbookFixtures.desktopBehavior,
                      conversationRecoveryNotice: null,
                      historicalConversationRestoreNotice: null,
                      composer: screen.composer,
                      onComposerDraftChanged: (_) {},
                      onSendPrompt: () async {},
                      onConversationRecoveryAction: (_) {},
                      onHistoricalConversationRestoreAction: (_) {},
                    ),
                    onStopActiveTurn: () async {},
                  );
                },
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Assistant Message',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Final',
                builder: (_) => widgetbookStoryCanvas(
                  child: AssistantMessageSurface(
                    block: WidgetbookFixtures.assistantMessage(),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Streaming',
                builder: (_) => widgetbookStoryCanvas(
                  child: AssistantMessageSurface(
                    block: WidgetbookFixtures.assistantMessage(isRunning: true),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Reasoning',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Running',
                builder: (_) => widgetbookStoryCanvas(
                  child: ReasoningSurface(
                    block: WidgetbookFixtures.reasoningBlock(isRunning: true),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Complete',
                builder: (_) => widgetbookStoryCanvas(
                  child: ReasoningSurface(
                    block: WidgetbookFixtures.reasoningBlock(isRunning: false),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'User Message',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Sent',
                builder: (_) => widgetbookStoryCanvas(
                  alignment: Alignment.centerRight,
                  child: UserMessageSurface(
                    block: WidgetbookFixtures.userMessage(),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Local Echo',
                builder: (_) => widgetbookStoryCanvas(
                  alignment: Alignment.centerRight,
                  child: UserMessageSurface(
                    block: WidgetbookFixtures.userMessage(
                      deliveryState:
                          TranscriptUserMessageDeliveryState.localEcho,
                    ),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Status',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Default',
                builder: (_) => widgetbookStoryCanvas(
                  child: StatusSurface(block: WidgetbookFixtures.statusBlock()),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Error',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Default',
                builder: (_) => widgetbookStoryCanvas(
                  child: ErrorSurface(block: WidgetbookFixtures.errorBlock()),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Approval Request',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Pending',
                builder: (_) => widgetbookStoryCanvas(
                  child: ApprovalRequestSurface(
                    request: WidgetbookFixtures.approvalRequest(),
                    onApprove: (_) async {},
                    onDeny: (_) async {},
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Resolved',
                builder: (_) => widgetbookStoryCanvas(
                  child: ApprovalRequestSurface(
                    request: WidgetbookFixtures.approvalRequest(
                      isResolved: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Plan Update',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Default',
                builder: (_) => widgetbookStoryCanvas(
                  child: PlanUpdateSurface(
                    block: WidgetbookFixtures.planUpdateBlock(),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Proposed Plan',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Final',
                builder: (_) => widgetbookStoryCanvas(
                  child: ProposedPlanSurface(
                    block: WidgetbookFixtures.proposedPlanBlock(),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Streaming Long',
                builder: (_) => widgetbookStoryCanvas(
                  child: ProposedPlanSurface(
                    block: WidgetbookFixtures.proposedPlanBlock(
                      isStreaming: true,
                      isLong: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Changed Files',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Mixed',
                builder: (_) => widgetbookStoryCanvas(
                  child: ChangedFilesSurface(
                    item: WidgetbookFixtures.changedFilesItem(),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Created',
                builder: (_) => widgetbookStoryCanvas(
                  child: ChangedFilesSurface(
                    item: WidgetbookFixtures.changedFilesItem(
                      variant: 'created',
                    ),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Deleted',
                builder: (_) => widgetbookStoryCanvas(
                  child: ChangedFilesSurface(
                    item: WidgetbookFixtures.changedFilesItem(
                      variant: 'deleted',
                    ),
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Running',
                builder: (_) => widgetbookStoryCanvas(
                  child: ChangedFilesSurface(
                    item: WidgetbookFixtures.changedFilesItem(isRunning: true),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Work Log',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Default',
                builder: (_) => widgetbookStoryCanvas(
                  child: WorkLogGroupSurface(
                    item: WidgetbookFixtures.workLogGroupItem(),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'User Input Request',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Pending',
                builder: (_) => widgetbookStoryCanvas(
                  child: UserInputRequestSurface(
                    contract: WidgetbookFixtures.pendingUserInput(),
                    onFieldChanged: (_, value) {},
                    onSubmit: () async {},
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Resolved',
                builder: (_) => widgetbookStoryCanvas(
                  child: UserInputRequestSurface(
                    contract: WidgetbookFixtures.pendingUserInput(
                      resolved: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Usage Summary',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Default',
                builder: (_) => widgetbookStoryCanvas(
                  child: UsageSurface(block: WidgetbookFixtures.usageBlock()),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'Turn Boundary',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Default',
                builder: (_) => widgetbookStoryCanvas(
                  child: TurnBoundaryMarker(
                    block: WidgetbookFixtures.turnBoundaryBlock(),
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'SSH Host Trust',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Unpinned',
                builder: (_) => widgetbookStoryCanvas(
                  child: SshUnpinnedHostKeySurface(
                    block: WidgetbookFixtures.sshUnpinnedHostKey(),
                    onSaveFingerprint: (_) async {},
                    onOpenConnectionSettings: () {},
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Saved',
                builder: (_) => widgetbookStoryCanvas(
                  child: SshUnpinnedHostKeySurface(
                    block: WidgetbookFixtures.sshUnpinnedHostKey(isSaved: true),
                    onOpenConnectionSettings: () {},
                  ),
                ),
              ),
            ],
          ),
          WidgetbookComponent(
            name: 'SSH Errors',
            useCases: <WidgetbookUseCase>[
              WidgetbookUseCase(
                name: 'Connect Failed',
                builder: (_) => widgetbookStoryCanvas(
                  child: SshConnectFailedSurface(
                    block: WidgetbookFixtures.sshConnectFailedBlock(),
                    onOpenConnectionSettings: () {},
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Host Key Mismatch',
                builder: (_) => widgetbookStoryCanvas(
                  child: SshHostKeyMismatchSurface(
                    block: WidgetbookFixtures.sshHostKeyMismatchBlock(),
                    onOpenConnectionSettings: () {},
                  ),
                ),
              ),
              WidgetbookUseCase(
                name: 'Authentication Failed',
                builder: (_) => widgetbookStoryCanvas(
                  child: SshAuthFailedSurface(
                    block: WidgetbookFixtures.sshAuthenticationFailedBlock(),
                    onOpenConnectionSettings: () {},
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Composer',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Mobile',
            builder: (_) => widgetbookStoryCanvas(
              maxWidth: 720,
              child: ChatComposer(
                platformBehavior: WidgetbookFixtures.mobileBehavior,
                contract: const ChatComposerContract(
                  draft: ChatComposerDraft(
                    text: 'Summarize the latest session output.',
                  ),
                  isSendActionEnabled: true,
                  placeholder: 'Ask Codex to continue',
                ),
                onChanged: (_) {},
                onSend: () async {},
              ),
            ),
          ),
          WidgetbookUseCase(
            name: 'Desktop',
            builder: (_) => widgetbookStoryCanvas(
              maxWidth: 920,
              child: ChatComposer(
                platformBehavior: WidgetbookFixtures.desktopBehavior,
                contract: const ChatComposerContract(
                  draft: ChatComposerDraft(
                    text:
                        'Run the failing test file and explain the regression.',
                  ),
                  isSendActionEnabled: true,
                  placeholder: 'Message Pocket Relay',
                ),
                onChanged: (_) {},
                onSend: () async {},
              ),
            ),
          ),
        ],
      ),
      WidgetbookComponent(
        name: 'Empty State',
        useCases: <WidgetbookUseCase>[
          WidgetbookUseCase(
            name: 'Mobile First Run',
            builder: (_) => widgetbookStoryFill(
              child: EmptyState(
                isConfigured: false,
                connectionMode: ConnectionMode.remote,
                platformBehavior: WidgetbookFixtures.mobileBehavior,
                onConfigure: () {},
              ),
            ),
          ),
          WidgetbookUseCase(
            name: 'Desktop Configured',
            builder: (_) => widgetbookStoryFill(
              child: EmptyState(
                isConfigured: true,
                connectionMode: ConnectionMode.local,
                platformBehavior: WidgetbookFixtures.desktopBehavior,
                onConfigure: () {},
                onSelectConnectionMode: (_) {},
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
