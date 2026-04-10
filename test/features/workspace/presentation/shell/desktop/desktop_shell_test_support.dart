import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';

import '../../../support/workspace_test_harness.dart'
    hide buildWorkspaceController;
import '../../../support/workspace_test_harness.dart' as workspace_test_harness;
import '../../../../../support/fakes/connection_settings_overlay_delegate.dart';

export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/errors/pocket_error.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
export 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
export 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
export 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
export 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
export 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
export 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
export 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
export '../../../support/workspace_test_harness.dart';
export '../../../../../support/fakes/connection_settings_overlay_delegate.dart';

Widget buildShell(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
  CodexWorkspaceConversationHistoryRepository? conversationHistoryRepository,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: ConnectionWorkspaceDesktopShell(
      workspaceController: controller,
      platformPolicy: PocketPlatformPolicy.resolve(
        platform: TargetPlatform.macOS,
      ),
      conversationHistoryRepository: conversationHistoryRepository,
      settingsOverlayDelegate:
          settingsOverlayDelegate ?? FakeConnectionSettingsOverlayDelegate(),
    ),
  );
}

Future<void> openLaneConversationHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conversation history'));
  await tester.pumpAndSettle();
}

ConnectionWorkspaceController buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  CodexConnectionRepository? repository,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const StaticRemoteOwnerInspector(
        CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.stopped,
          sessionName: 'pocket-relay-conn_primary',
        ),
      ),
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const StaticRemoteOwnerControl(
        CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.stopped,
          sessionName: 'pocket-relay-conn_primary',
        ),
      ),
}) {
  return workspace_test_harness.buildWorkspaceController(
    clientsById: clientsById,
    repository: repository,
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
  );
}

final class FailingLoadConnectionRepository
    implements CodexConnectionRepository {
  FailingLoadConnectionRepository({
    required this.delegate,
    required this.failingConnectionId,
    required this.error,
  });

  final CodexConnectionRepository delegate;
  final String failingConnectionId;
  final Object error;

  @override
  Future<ConnectionCatalogState> loadCatalog() => delegate.loadCatalog();

  @override
  Future<WorkspaceCatalogState> loadWorkspaceCatalog() =>
      delegate.loadWorkspaceCatalog();

  @override
  Future<SystemCatalogState> loadSystemCatalog() =>
      delegate.loadSystemCatalog();

  @override
  Future<SavedConnection> loadConnection(String connectionId) {
    if (connectionId == failingConnectionId) {
      throw error;
    }
    return delegate.loadConnection(connectionId);
  }

  @override
  Future<SavedWorkspace> loadWorkspace(String workspaceId) =>
      delegate.loadWorkspace(workspaceId);

  @override
  Future<SavedSystem> loadSystem(String systemId) =>
      delegate.loadSystem(systemId);

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) => delegate.createConnection(profile: profile, secrets: secrets);

  @override
  Future<SavedWorkspace> createWorkspace({required WorkspaceProfile profile}) =>
      delegate.createWorkspace(profile: profile);

  @override
  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) => delegate.createSystem(profile: profile, secrets: secrets);

  @override
  Future<void> saveConnection(SavedConnection connection) =>
      delegate.saveConnection(connection);

  @override
  Future<void> saveWorkspace(SavedWorkspace workspace) =>
      delegate.saveWorkspace(workspace);

  @override
  Future<void> saveSystem(SavedSystem system) => delegate.saveSystem(system);

  @override
  Future<void> deleteConnection(String connectionId) =>
      delegate.deleteConnection(connectionId);

  @override
  Future<void> deleteWorkspace(String workspaceId) =>
      delegate.deleteWorkspace(workspaceId);

  @override
  Future<void> deleteSystem(String systemId) => delegate.deleteSystem(systemId);
}

class FakeCodexWorkspaceConversationHistoryRepository
    implements CodexWorkspaceConversationHistoryRepository {
  FakeCodexWorkspaceConversationHistoryRepository({
    this.conversations = const <CodexWorkspaceConversationSummary>[],
    this.error,
  });

  final List<CodexWorkspaceConversationSummary> conversations;
  final Object? error;
  final List<(ConnectionProfile, ConnectionSecrets, String?)> loadCalls =
      <(ConnectionProfile, ConnectionSecrets, String?)>[];

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    loadCalls.add((profile, secrets, ownerId));
    if (error != null) {
      throw error!;
    }
    return conversations;
  }
}
