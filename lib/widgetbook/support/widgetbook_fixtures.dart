import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_fixture_foundation.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_lane_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_request_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_ssh_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_transcript_fixtures.dart';
import 'package:pocket_relay/widgetbook/support/fixtures/widgetbook_worklog_fixtures.dart';

export 'package:pocket_relay/widgetbook/support/noop_display_wake_lock_controller.dart';

class WidgetbookFixtures {
  static DateTime get timestamp => WidgetbookFixtureFoundation.timestamp;

  static String get assistantMessageMarkdown =>
      WidgetbookFixtureFoundation.assistantMessageMarkdown;

  static String get reasoningMarkdown =>
      WidgetbookFixtureFoundation.reasoningMarkdown;

  static String get proposedPlanMarkdown =>
      WidgetbookFixtureFoundation.proposedPlanMarkdown;

  static String get longProposedPlanMarkdown =>
      WidgetbookFixtureFoundation.longProposedPlanMarkdown;

  static PocketPlatformBehavior get mobileBehavior =>
      WidgetbookFixtureFoundation.mobileBehavior;

  static PocketPlatformBehavior get desktopBehavior =>
      WidgetbookFixtureFoundation.desktopBehavior;

  static PocketPlatformPolicy get mobilePolicy =>
      WidgetbookFixtureFoundation.mobilePolicy;

  static PocketPlatformPolicy get desktopPolicy =>
      WidgetbookFixtureFoundation.desktopPolicy;

  static ConnectionProfile get remoteProfile =>
      WidgetbookFixtureFoundation.remoteProfile;

  static ConnectionProfile get localProfile =>
      WidgetbookFixtureFoundation.localProfile;

  static ConnectionSecrets get passwordSecrets =>
      WidgetbookFixtureFoundation.passwordSecrets;

  static SavedProfile get savedProfile =>
      WidgetbookFixtureFoundation.savedProfile;

  static TranscriptTextBlock assistantMessage({
    String body = WidgetbookFixtureFoundation.assistantMessageMarkdown,
    bool isRunning = false,
  }) {
    return WidgetbookTranscriptFixtures.assistantMessage(
      body: body,
      isRunning: isRunning,
    );
  }

  static TranscriptTextBlock reasoningBlock({bool isRunning = true}) {
    return WidgetbookTranscriptFixtures.reasoningBlock(isRunning: isRunning);
  }

  static TranscriptUserMessageBlock userMessage({
    TranscriptUserMessageDeliveryState deliveryState =
        TranscriptUserMessageDeliveryState.sent,
  }) {
    return WidgetbookTranscriptFixtures.userMessage(
      deliveryState: deliveryState,
    );
  }

  static TranscriptStatusBlock statusBlock() {
    return WidgetbookTranscriptFixtures.statusBlock();
  }

  static TranscriptStatusBlock contextCompactedBlock() {
    return WidgetbookTranscriptFixtures.contextCompactedBlock();
  }

  static TranscriptErrorBlock errorBlock() {
    return WidgetbookTranscriptFixtures.errorBlock();
  }

  static ChatApprovalRequestContract approvalRequest({
    bool isResolved = false,
  }) {
    return WidgetbookRequestFixtures.approvalRequest(isResolved: isResolved);
  }

  static PendingUserInputContract pendingUserInput({
    bool resolved = false,
    bool submitting = false,
  }) {
    return WidgetbookRequestFixtures.pendingUserInput(
      resolved: resolved,
      submitting: submitting,
    );
  }

  static TranscriptPlanUpdateBlock planUpdateBlock() {
    return WidgetbookTranscriptFixtures.planUpdateBlock();
  }

  static TranscriptProposedPlanBlock proposedPlanBlock({
    bool isStreaming = false,
    bool isLong = false,
  }) {
    return WidgetbookTranscriptFixtures.proposedPlanBlock(
      isStreaming: isStreaming,
      isLong: isLong,
    );
  }

  static ChatChangedFilesItemContract changedFilesItem({
    bool isRunning = false,
    String variant = 'mixed',
  }) {
    return WidgetbookWorkLogFixtures.changedFilesItem(
      isRunning: isRunning,
      variant: variant,
    );
  }

  static ChatWorkLogGroupItemContract workLogGroupItem() {
    return WidgetbookWorkLogFixtures.workLogGroupItem();
  }

  static ChatExecCommandItemContract execCommandItem({bool isRunning = true}) {
    return WidgetbookWorkLogFixtures.execCommandItem(isRunning: isRunning);
  }

  static TranscriptUsageBlock usageBlock() {
    return WidgetbookTranscriptFixtures.usageBlock();
  }

  static TranscriptTurnBoundaryBlock turnBoundaryBlock() {
    return WidgetbookTranscriptFixtures.turnBoundaryBlock();
  }

  static TranscriptSshUnpinnedHostKeyBlock sshUnpinnedHostKey({
    bool isSaved = false,
  }) {
    return WidgetbookSshFixtures.sshUnpinnedHostKey(isSaved: isSaved);
  }

  static TranscriptSshConnectFailedBlock sshConnectFailedBlock() {
    return WidgetbookSshFixtures.sshConnectFailedBlock();
  }

  static TranscriptSshHostKeyMismatchBlock sshHostKeyMismatchBlock() {
    return WidgetbookSshFixtures.sshHostKeyMismatchBlock();
  }

  static TranscriptSshAuthenticationFailedBlock sshAuthenticationFailedBlock() {
    return WidgetbookSshFixtures.sshAuthenticationFailedBlock();
  }

  static ChatTranscriptSurfaceContract denseTranscriptSurface() {
    return WidgetbookLaneFixtures.denseTranscriptSurface();
  }

  static ChatScreenContract denseTranscriptLaneScreen({
    PocketPlatformBehavior platformBehavior =
        WidgetbookFixtureFoundation.desktopBehavior,
  }) {
    return WidgetbookLaneFixtures.denseTranscriptLaneScreen(
      platformBehavior: platformBehavior,
    );
  }
}
