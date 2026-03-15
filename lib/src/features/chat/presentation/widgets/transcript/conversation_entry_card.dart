import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/approval_request_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/assistant_message_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/command_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/error_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/pending_user_input_request_host.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/plan_update_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/proposed_plan_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/reasoning_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/status_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/user_message_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/work_log_group_card.dart';

class ConversationEntryCard extends StatelessWidget {
  const ConversationEntryCard({
    super.key,
    required this.block,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onSubmitUserInput,
  });

  final CodexUiBlock block;
  final Future<void> Function(String requestId)? onApproveRequest;
  final Future<void> Function(String requestId)? onDenyRequest;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmitUserInput;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      final CodexUserMessageBlock userBlock => UserMessageCard(
        block: userBlock,
      ),
      final CodexTextBlock textBlock
          when textBlock.kind == CodexUiBlockKind.reasoning =>
        ReasoningCard(block: textBlock),
      final CodexTextBlock textBlock => AssistantMessageCard(block: textBlock),
      final CodexPlanUpdateBlock planUpdateBlock => PlanUpdateCard(
        block: planUpdateBlock,
      ),
      final CodexProposedPlanBlock proposedPlanBlock => ProposedPlanCard(
        block: proposedPlanBlock,
      ),
      final CodexCommandExecutionBlock commandBlock => CommandCard(
        block: commandBlock,
      ),
      final CodexWorkLogEntryBlock workLogEntryBlock => WorkLogGroupCard(
        block: CodexWorkLogGroupBlock(
          id: workLogEntryBlock.id,
          createdAt: workLogEntryBlock.createdAt,
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: workLogEntryBlock.id,
              createdAt: workLogEntryBlock.createdAt,
              entryKind: workLogEntryBlock.entryKind,
              title: workLogEntryBlock.title,
              turnId: workLogEntryBlock.turnId,
              preview: workLogEntryBlock.preview,
              isRunning: workLogEntryBlock.isRunning,
              exitCode: workLogEntryBlock.exitCode,
            ),
          ],
        ),
      ),
      final CodexWorkLogGroupBlock workLogGroupBlock => WorkLogGroupCard(
        block: workLogGroupBlock,
      ),
      final CodexChangedFilesBlock changedFilesBlock => ChangedFilesCard(
        block: changedFilesBlock,
      ),
      final CodexApprovalRequestBlock approvalBlock => ApprovalRequestCard(
        block: approvalBlock,
        onApprove: onApproveRequest,
        onDeny: onDenyRequest,
      ),
      final CodexUserInputRequestBlock userInputBlock =>
        PendingUserInputRequestHost(
          block: userInputBlock,
          onSubmit: onSubmitUserInput,
        ),
      final CodexStatusBlock statusBlock => StatusCard(block: statusBlock),
      final CodexErrorBlock errorBlock => ErrorCard(block: errorBlock),
      final CodexUsageBlock usageBlock => UsageCard(block: usageBlock),
      final CodexTurnBoundaryBlock boundaryBlock => TurnBoundaryCard(
        block: boundaryBlock,
      ),
    };
  }
}
