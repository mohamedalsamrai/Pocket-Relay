import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class WidgetbookFixtures {
  static final DateTime timestamp = DateTime.utc(2026, 3, 21, 10, 30);

  static const String assistantMessageMarkdown =
      'Updated the workspace shell and tightened the lane selection flow.\n\n'
      '- Added deterministic fixtures for previews\n'
      '- Kept the app wiring separate from story state\n'
      '- Left transport ownership outside the visual surface';

  static const String reasoningMarkdown =
      'Comparing the new shell against the prior state.\n\n'
      '1. Verify lane selection is explicit.\n'
      '2. Keep storage and transport injected.\n'
      '3. Render only presentation-focused surfaces in isolation.';

  static const PocketPlatformBehavior mobileBehavior = PocketPlatformBehavior(
    experience: PocketPlatformExperience.mobile,
    supportsLocalConnectionMode: false,
    supportsWakeLock: true,
    usesDesktopKeyboardSubmit: false,
    supportsCollapsibleDesktopSidebar: false,
  );

  static const PocketPlatformBehavior desktopBehavior = PocketPlatformBehavior(
    experience: PocketPlatformExperience.desktop,
    supportsLocalConnectionMode: true,
    supportsWakeLock: false,
    usesDesktopKeyboardSubmit: true,
    supportsCollapsibleDesktopSidebar: true,
  );

  static const PocketPlatformPolicy mobilePolicy = PocketPlatformPolicy(
    behavior: mobileBehavior,
  );

  static const PocketPlatformPolicy desktopPolicy = PocketPlatformPolicy(
    behavior: desktopBehavior,
  );

  static final ConnectionProfile remoteProfile = ConnectionProfile.defaults()
      .copyWith(
        label: 'Developer Box',
        host: 'devbox.local',
        username: 'vince',
        workspaceDir: '/workspace/Pocket-Relay',
        model: 'gpt-5.4',
        reasoningEffort: CodexReasoningEffort.high,
      );

  static final ConnectionProfile localProfile = ConnectionProfile.defaults()
      .copyWith(
        label: 'Local Workspace',
        workspaceDir: '/Users/vince/Projects/Pocket-Relay',
        connectionMode: ConnectionMode.local,
        model: 'gpt-5.4',
        reasoningEffort: CodexReasoningEffort.medium,
      );

  static const ConnectionSecrets passwordSecrets = ConnectionSecrets(
    password: 'secret-password',
  );

  static final SavedProfile savedProfile = SavedProfile(
    profile: remoteProfile,
    secrets: passwordSecrets,
  );

  static CodexTextBlock assistantMessage({
    String body = assistantMessageMarkdown,
    bool isRunning = false,
  }) {
    return CodexTextBlock(
      id: 'assistant_message',
      kind: CodexUiBlockKind.assistantMessage,
      createdAt: timestamp,
      title: 'Assistant',
      body: body,
      isRunning: isRunning,
    );
  }

  static CodexTextBlock reasoningBlock({bool isRunning = true}) {
    return CodexTextBlock(
      id: 'reasoning_message',
      kind: CodexUiBlockKind.reasoning,
      createdAt: timestamp,
      title: 'Reasoning',
      body: reasoningMarkdown,
      isRunning: isRunning,
    );
  }

  static CodexUserMessageBlock userMessage({
    CodexUserMessageDeliveryState deliveryState =
        CodexUserMessageDeliveryState.sent,
  }) {
    return CodexUserMessageBlock(
      id: 'user_message',
      createdAt: timestamp,
      text:
          'Open the Widgetbook implementation plan and start the first slice.',
      deliveryState: deliveryState,
    );
  }

  static CodexStatusBlock statusBlock() {
    return CodexStatusBlock(
      id: 'status_message',
      createdAt: timestamp,
      title: 'Session attached',
      body: 'Pocket Relay is connected to the remote Codex session.',
    );
  }

  static CodexErrorBlock errorBlock() {
    return CodexErrorBlock(
      id: 'error_message',
      createdAt: timestamp,
      title: 'Remote launch failed',
      body:
          'The preview uses a fake client, so no real app-server process was started.',
    );
  }
}

class NoopDisplayWakeLockController implements DisplayWakeLockController {
  const NoopDisplayWakeLockController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}
