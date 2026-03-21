import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

class PocketRelayAppDependencies {
  const PocketRelayAppDependencies({
    this.connectionRepository,
    this.connectionConversationStateStore,
    this.conversationHistoryRepository,
    this.appServerClient,
    this.displayWakeLockController,
    this.platformPolicy,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final CodexConnectionRepository? connectionRepository;
  final CodexConnectionConversationStateStore? connectionConversationStateStore;
  final CodexWorkspaceConversationHistoryRepository?
  conversationHistoryRepository;
  final CodexAppServerClient? appServerClient;
  final DisplayWakeLockController? displayWakeLockController;
  final PocketPlatformPolicy? platformPolicy;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  PocketPlatformPolicy get resolvedPlatformPolicy {
    return platformPolicy ?? PocketPlatformPolicy.resolve();
  }

  PocketRelayWorkspaceBootstrap createWorkspaceBootstrap({
    CodexConnectionRepository? ownedConnectionRepository,
    CodexConnectionConversationStateStore? ownedConversationStateStore,
  }) {
    final resolvedConnectionRepository =
        connectionRepository ??
        (ownedConnectionRepository ?? SecureCodexConnectionRepository());
    final resolvedConversationStateStore =
        connectionConversationStateStore ??
        (ownedConversationStateStore ??
            SecureCodexConnectionConversationStateStore());
    final resolvedPlatformPolicy = this.resolvedPlatformPolicy;
    var usedInjectedAppServerClient = false;

    final workspaceController = ConnectionWorkspaceController(
      connectionRepository: resolvedConnectionRepository,
      connectionConversationStateStore: resolvedConversationStateStore,
      laneBindingFactory:
          ({
            required String connectionId,
            required SavedConnection connection,
          }) {
            final injectedAppServerClient = appServerClient;
            final usingInjectedClient =
                !usedInjectedAppServerClient && injectedAppServerClient != null;
            if (usingInjectedClient) {
              usedInjectedAppServerClient = true;
            }

            return ConnectionLaneBinding(
              connectionId: connectionId,
              profileStore: ConnectionScopedProfileStore(
                connectionId: connectionId,
                connectionRepository: resolvedConnectionRepository,
              ),
              conversationStateStore: ConnectionScopedConversationStateStore(
                connectionId: connectionId,
                conversationStateStore: resolvedConversationStateStore,
              ),
              appServerClient: usingInjectedClient
                  ? injectedAppServerClient
                  : CodexAppServerClient(),
              initialSavedProfile: SavedProfile(
                profile: connection.profile,
                secrets: connection.secrets,
              ),
              supportsLocalConnectionMode:
                  resolvedPlatformPolicy.supportsLocalConnectionMode,
              ownsAppServerClient: !usingInjectedClient,
            );
          },
    );

    return PocketRelayWorkspaceBootstrap(
      workspaceController: workspaceController,
      ownedConnectionRepository: connectionRepository == null
          ? resolvedConnectionRepository
          : ownedConnectionRepository,
      ownedConversationStateStore: connectionConversationStateStore == null
          ? resolvedConversationStateStore
          : ownedConversationStateStore,
    );
  }
}

class PocketRelayWorkspaceBootstrap {
  const PocketRelayWorkspaceBootstrap({
    required this.workspaceController,
    required this.ownedConnectionRepository,
    required this.ownedConversationStateStore,
  });

  final ConnectionWorkspaceController workspaceController;
  final CodexConnectionRepository? ownedConnectionRepository;
  final CodexConnectionConversationStateStore? ownedConversationStateStore;
}
