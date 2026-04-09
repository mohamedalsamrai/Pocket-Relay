import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart';

final class PocketRelayWorkspaceControllerDependencies {
  const PocketRelayWorkspaceControllerDependencies({
    required this.connectionRepository,
    required this.modelCatalogStore,
    required this.recoveryStore,
    required this.agentAdapterClient,
    required this.agentAdapterRemoteRuntimeDelegateFactory,
    required this.platformPolicy,
  });

  final CodexConnectionRepository? connectionRepository;
  final ConnectionModelCatalogStore? modelCatalogStore;
  final ConnectionWorkspaceRecoveryStore? recoveryStore;
  final AgentAdapterClient? agentAdapterClient;
  final AgentAdapterRemoteRuntimeDelegateFactory?
  agentAdapterRemoteRuntimeDelegateFactory;
  final PocketPlatformPolicy? platformPolicy;

  PocketPlatformPolicy get resolvedPlatformPolicy {
    return platformPolicy ?? PocketPlatformPolicy.resolve();
  }

  bool requiresRebuildFrom(
    PocketRelayWorkspaceControllerDependencies oldDependencies,
  ) {
    return this != oldDependencies;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PocketRelayWorkspaceControllerDependencies &&
            other.connectionRepository == connectionRepository &&
            other.modelCatalogStore == modelCatalogStore &&
            other.recoveryStore == recoveryStore &&
            other.agentAdapterClient == agentAdapterClient &&
            other.agentAdapterRemoteRuntimeDelegateFactory ==
                agentAdapterRemoteRuntimeDelegateFactory &&
            other.platformPolicy == platformPolicy;
  }

  @override
  int get hashCode => Object.hash(
    connectionRepository,
    modelCatalogStore,
    recoveryStore,
    agentAdapterClient,
    agentAdapterRemoteRuntimeDelegateFactory,
    platformPolicy,
  );
}

class PocketRelayAppDependencies {
  const PocketRelayAppDependencies({
    this.connectionRepository,
    this.modelCatalogStore,
    this.conversationHistoryRepository,
    this.recoveryStore,
    this.agentAdapterClient,
    this.agentAdapterRemoteRuntimeDelegateFactory,
    this.backgroundGraceController,
    this.foregroundServiceController,
    this.notificationPermissionController,
    this.displayWakeLockController,
    this.turnCompletionAlertController,
    this.platformPolicy,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final CodexConnectionRepository? connectionRepository;
  final ConnectionModelCatalogStore? modelCatalogStore;
  final WorkspaceConversationHistoryRepository? conversationHistoryRepository;
  final ConnectionWorkspaceRecoveryStore? recoveryStore;
  final AgentAdapterClient? agentAdapterClient;
  final AgentAdapterRemoteRuntimeDelegateFactory?
  agentAdapterRemoteRuntimeDelegateFactory;
  final BackgroundGraceController? backgroundGraceController;
  final ForegroundServiceController? foregroundServiceController;
  final NotificationPermissionController? notificationPermissionController;
  final DisplayWakeLockController? displayWakeLockController;
  final TurnCompletionAlertController? turnCompletionAlertController;
  final PocketPlatformPolicy? platformPolicy;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  PocketPlatformPolicy get resolvedPlatformPolicy {
    return platformPolicy ?? PocketPlatformPolicy.resolve();
  }

  PocketRelayWorkspaceControllerDependencies
  get workspaceControllerDependencies {
    return PocketRelayWorkspaceControllerDependencies(
      connectionRepository: connectionRepository,
      modelCatalogStore: modelCatalogStore,
      recoveryStore: recoveryStore,
      agentAdapterClient: agentAdapterClient,
      agentAdapterRemoteRuntimeDelegateFactory:
          agentAdapterRemoteRuntimeDelegateFactory,
      platformPolicy: platformPolicy,
    );
  }

  bool requiresWorkspaceControllerRebuild(
    PocketRelayAppDependencies oldDependencies,
  ) {
    return workspaceControllerDependencies.requiresRebuildFrom(
      oldDependencies.workspaceControllerDependencies,
    );
  }

  PocketRelayWorkspaceBootstrap createWorkspaceBootstrap({
    CodexConnectionRepository? ownedConnectionRepository,
  }) {
    final workspaceControllerDependencies =
        this.workspaceControllerDependencies;
    final resolvedConnectionRepository =
        workspaceControllerDependencies.connectionRepository ??
        (ownedConnectionRepository ?? SecureCodexConnectionRepository());
    final resolvedPlatformPolicy =
        workspaceControllerDependencies.resolvedPlatformPolicy;
    final resolvedRemoteRuntimeDelegateFactory =
        workspaceControllerDependencies
            .agentAdapterRemoteRuntimeDelegateFactory ??
        ((kind) => createDefaultAgentAdapterRemoteRuntimeDelegate(kind));
    var usedInjectedAgentAdapterClient = false;

    final workspaceController = ConnectionWorkspaceController(
      connectionRepository: resolvedConnectionRepository,
      modelCatalogStore:
          workspaceControllerDependencies.modelCatalogStore ??
          SecureConnectionModelCatalogStore(),
      recoveryStore:
          workspaceControllerDependencies.recoveryStore ??
          SecureConnectionWorkspaceRecoveryStore(),
      remoteRuntimeDelegateFactory: resolvedRemoteRuntimeDelegateFactory,
      laneBindingFactory:
          ({
            required String connectionId,
            required SavedConnection connection,
          }) {
            final injectedAgentAdapterClient =
                workspaceControllerDependencies.agentAdapterClient;
            final usingInjectedClient =
                !usedInjectedAgentAdapterClient &&
                injectedAgentAdapterClient != null;
            if (usingInjectedClient) {
              usedInjectedAgentAdapterClient = true;
            }

            return ConnectionLaneBinding(
              connectionId: connectionId,
              profileStore: ConnectionScopedProfileStore(
                connectionId: connectionId,
                connectionRepository: resolvedConnectionRepository,
              ),
              agentAdapterClient: usingInjectedClient
                  ? injectedAgentAdapterClient
                  : createDefaultAgentAdapterClient(
                      profile: connection.profile,
                      ownerId: connectionId,
                    ),
              runtimeEventMapper: createAgentAdapterRuntimeEventMapper(
                connection.profile.agentAdapter,
              ),
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
    );
  }
}

class PocketRelayWorkspaceBootstrap {
  const PocketRelayWorkspaceBootstrap({
    required this.workspaceController,
    required this.ownedConnectionRepository,
  });

  final ConnectionWorkspaceController workspaceController;
  final CodexConnectionRepository? ownedConnectionRepository;
}
