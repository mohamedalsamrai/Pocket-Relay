import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_fixture_foundation.dart';

abstract final class WidgetbookTranscriptFixtures {
  static TranscriptTextBlock assistantMessage({
    String body = WidgetbookFixtureFoundation.assistantMessageMarkdown,
    bool isRunning = false,
  }) {
    return TranscriptTextBlock(
      id: 'assistant_message',
      kind: TranscriptUiBlockKind.assistantMessage,
      createdAt: WidgetbookFixtureFoundation.timestamp,
      title: 'Assistant',
      body: body,
      isRunning: isRunning,
    );
  }

  static TranscriptTextBlock reasoningBlock({bool isRunning = true}) {
    return TranscriptTextBlock(
      id: 'reasoning_message',
      kind: TranscriptUiBlockKind.reasoning,
      createdAt: WidgetbookFixtureFoundation.timestamp,
      title: 'Reasoning',
      body: WidgetbookFixtureFoundation.reasoningMarkdown,
      isRunning: isRunning,
    );
  }

  static TranscriptUserMessageBlock userMessage({
    TranscriptUserMessageDeliveryState deliveryState =
        TranscriptUserMessageDeliveryState.sent,
  }) {
    return TranscriptUserMessageBlock(
      id: 'user_message',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      text:
          'Open the Widgetbook implementation plan and start the first slice.',
      deliveryState: deliveryState,
    );
  }

  static TranscriptStatusBlock statusBlock() {
    return TranscriptStatusBlock(
      id: 'status_message',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      title: 'Session attached',
      body:
          'Pocket Relay is connected to the remote session and ready to continue.',
    );
  }

  static TranscriptStatusBlock contextCompactedBlock() {
    return TranscriptStatusBlock(
      id: 'status_compaction',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      title: 'Context compacted',
      body: 'Older transcript context was compacted upstream.',
      statusKind: TranscriptStatusBlockKind.compaction,
    );
  }

  static TranscriptErrorBlock errorBlock() {
    return TranscriptErrorBlock(
      id: 'error_message',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      title: 'Remote launch failed',
      body: 'The remote workspace could not be opened with the saved settings.',
    );
  }

  static TranscriptPlanUpdateBlock planUpdateBlock() {
    return TranscriptPlanUpdateBlock(
      id: 'plan_update',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      explanation:
          'Updated the recovery steps after the remote launch failed a second time.',
      steps: <TranscriptRuntimePlanStep>[
        TranscriptRuntimePlanStep(
          step: 'Confirm the saved host fingerprint',
          status: TranscriptRuntimePlanStepStatus.completed,
        ),
        TranscriptRuntimePlanStep(
          step: 'Review the saved workspace path',
          status: TranscriptRuntimePlanStepStatus.inProgress,
        ),
        TranscriptRuntimePlanStep(
          step: 'Retry the remote launch',
          status: TranscriptRuntimePlanStepStatus.pending,
        ),
      ],
    );
  }

  static TranscriptProposedPlanBlock proposedPlanBlock({
    bool isStreaming = false,
    bool isLong = false,
  }) {
    return TranscriptProposedPlanBlock(
      id: isLong ? 'proposed_plan_long' : 'proposed_plan',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      title: 'Proposed plan',
      markdown: isLong
          ? WidgetbookFixtureFoundation.longProposedPlanMarkdown
          : WidgetbookFixtureFoundation.proposedPlanMarkdown,
      isStreaming: isStreaming,
    );
  }

  static TranscriptUsageBlock usageBlock() {
    return TranscriptUsageBlock(
      id: 'usage_block',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      title: 'Usage',
      body:
          'Last: input 2.1k, cached 0.8k, output 0.9k, reasoning 0.3k, total 4.1k\n'
          'Total: input 18.4k, cached 6.1k, output 8.2k, reasoning 1.4k, total 34.1k\n'
          'Context window: 34.1k / 200k',
    );
  }

  static TranscriptTurnBoundaryBlock turnBoundaryBlock() {
    return TranscriptTurnBoundaryBlock(
      id: 'turn_boundary',
      createdAt: WidgetbookFixtureFoundation.timestamp,
      label: 'turn completed',
      elapsed: const Duration(minutes: 2, seconds: 18),
      usage: usageBlock(),
    );
  }
}
