import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';

abstract final class WidgetbookFixtureFoundation {
  static final DateTime timestamp = DateTime.utc(2026, 3, 21, 10, 30);

  static const String assistantMessageMarkdown =
      'I checked the session and found two concrete follow-ups.\n\n'
      '- The SSH trust prompt is still blocking the first connection.\n'
      '- One command failed because the saved workspace path is missing.\n'
      '- The next step is to confirm the host key, then retry the launch.';

  static const String reasoningMarkdown =
      'Comparing the latest runtime events before choosing the next action.\n\n'
      '1. Check whether the failure is trust-related or authentication-related.\n'
      '2. Keep the blocked action visible while the user decides.\n'
      '3. Do not hide the consequence behind secondary detail.';

  static const String proposedPlanMarkdown =
      '# Connection Recovery Plan\n\n'
      '## Summary\n\n'
      'Recover the current session and keep the user-facing consequences visible.\n\n'
      '## Scope\n\n'
      '1. Re-check the saved connection settings and workspace path.\n'
      '2. Surface the SSH trust and auth states as distinct blockers.\n'
      '3. Retry the remote launch only after the blocking state is resolved.\n\n'
      '## Acceptance Criteria\n\n'
      '- The blocking state is obvious before any action is taken.\n'
      '- The user can see what host, path, and account are affected.\n'
      '- Long content still supports truncation and expansion.';

  static const String longProposedPlanMarkdown =
      '# Remote Session Recovery\n\n'
      '## Summary\n\n'
      'Recover a failing remote session without hiding the evidence that explains the failure.\n\n'
      '## Workstreams\n\n'
      '1. Transport\n'
      '- Re-check the saved host, port, and account details.\n'
      '- Verify whether the host key is already pinned or still pending trust.\n\n'
      '2. Transcript\n'
      '- Keep approval and input-required states visually distinct.\n'
      '- Keep file changes and command activity readable in dense turns.\n'
      '- Preserve SSH trust and failure context while recovery actions are available.\n\n'
      '3. Reliability\n'
      '- Keep long content expandable without losing the initial summary.\n'
      '- Avoid duplicate status signals for the same runtime meaning.\n'
      '- Keep action-required states visually consistent.\n\n'
      '## Notes\n\n'
      'This plan focuses on the runtime surfaces the user actually sees while the connection is blocked or recovering.';

  static const PocketPlatformBehavior mobileBehavior = PocketPlatformBehavior(
    experience: PocketPlatformExperience.mobile,
    supportsLocalConnectionMode: false,
    supportsWakeLock: true,
    supportsFiniteBackgroundGrace: false,
    supportsActiveTurnForegroundService: false,
    supportsForegroundTurnCompletionSignal: true,
    supportsBackgroundTurnCompletionAlerts: true,
    usesDesktopKeyboardSubmit: false,
    supportsCollapsibleDesktopSidebar: false,
  );

  static const PocketPlatformBehavior desktopBehavior = PocketPlatformBehavior(
    experience: PocketPlatformExperience.desktop,
    supportsLocalConnectionMode: true,
    supportsWakeLock: false,
    supportsFiniteBackgroundGrace: false,
    supportsActiveTurnForegroundService: false,
    supportsForegroundTurnCompletionSignal: false,
    supportsBackgroundTurnCompletionAlerts: false,
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
        reasoningEffort: AgentAdapterReasoningEffort.high,
      );

  static final ConnectionProfile localProfile = ConnectionProfile.defaults()
      .copyWith(
        label: 'Local Workspace',
        workspaceDir: '/Users/vince/Projects/Pocket-Relay',
        connectionMode: ConnectionMode.local,
        model: 'gpt-5.4',
        reasoningEffort: AgentAdapterReasoningEffort.medium,
      );

  static const ConnectionSecrets passwordSecrets = ConnectionSecrets(
    password: 'secret-password',
  );

  static final SavedProfile savedProfile = SavedProfile(
    profile: remoteProfile,
    secrets: passwordSecrets,
  );
}
