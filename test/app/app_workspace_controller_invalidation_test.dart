import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/app/pocket_relay_app.dart';
import 'package:pocket_relay/src/app/pocket_relay_dependencies.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/device/turn_completion_alert_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/agent_adapter_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_continuity_host.dart';

import '../support/builders/app_test_harness.dart';
import '../support/fakes/fake_app_remote_runtime_delegate.dart';

void main() {
  registerAppTestStorageLifecycle();

  test('requiresWorkspaceControllerRebuild tracks controller inputs only', () {
    final clients = <FakeAgentAdapterClient>[];
    addTearDown(() async {
      for (final client in clients) {
        await client.close();
      }
    });

    FakeAgentAdapterClient createClient() {
      final client = FakeAgentAdapterClient();
      clients.add(client);
      return client;
    }

    final base = _TestAppDependencySet.base(
      createClient: createClient,
      trackClient: clients.add,
    );

    expect(
      base
          .copyWith(connectionRepository: MemoryCodexConnectionRepository())
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isTrue,
    );
    expect(
      base
          .copyWith(modelCatalogStore: MemoryConnectionModelCatalogStore())
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isTrue,
    );
    expect(
      base
          .copyWith(recoveryStore: MemoryConnectionWorkspaceRecoveryStore())
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isTrue,
    );
    expect(
      base
          .copyWith(agentAdapterClient: createClient())
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isTrue,
    );
    expect(
      base
          .copyWith(
            agentAdapterRemoteRuntimeDelegateFactory:
                _alternateRemoteRuntimeDelegateFactory,
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isTrue,
    );
    expect(
      base
          .copyWith(
            platformPolicy: PocketPlatformPolicy.resolve(
              platform: TargetPlatform.macOS,
            ),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isTrue,
    );

    expect(
      base
          .copyWith(
            conversationHistoryRepository: _FakeConversationHistoryRepository(),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isFalse,
    );
    expect(
      base
          .copyWith(
            settingsOverlayDelegate: const _NoopSettingsOverlayDelegate(),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isFalse,
    );
    expect(
      base
          .copyWith(
            backgroundGraceController: const _NoopBackgroundGraceController(),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isFalse,
    );
    expect(
      base
          .copyWith(
            foregroundServiceController:
                const _NoopForegroundServiceController(),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isFalse,
    );
    expect(
      base
          .copyWith(
            notificationPermissionController:
                const _GrantedNotificationPermissionController(),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isFalse,
    );
    expect(
      base
          .copyWith(
            displayWakeLockController: const _NoopDisplayWakeLockController(),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isFalse,
    );
    expect(
      base
          .copyWith(
            turnCompletionAlertController:
                const _NoopTurnCompletionAlertController(),
          )
          .dependencies
          .requiresWorkspaceControllerRebuild(base.dependencies),
      isFalse,
    );
  });

  for (final scenario in _controllerRebuildScenarios) {
    testWidgets(
      'recreates the workspace controller when ${scenario.description} changes',
      (tester) async {
        final base = _createTestDependencySet();

        await tester.pumpWidget(base.app);
        await tester.pumpAndSettle();

        final initialController = _workspaceController(tester);

        await tester.pumpWidget(scenario.mutate(base).app);
        await tester.pumpAndSettle();

        expect(_workspaceController(tester), isNot(same(initialController)));
      },
    );
  }

  testWidgets(
    'keeps the workspace controller when only shell and wrapper dependencies change',
    (tester) async {
      final base = _createTestDependencySet();

      await tester.pumpWidget(base.app);
      await tester.pumpAndSettle();

      final initialController = _workspaceController(tester);

      await tester.pumpWidget(
        base
            .copyWith(
              conversationHistoryRepository:
                  _FakeConversationHistoryRepository(),
              settingsOverlayDelegate: const _NoopSettingsOverlayDelegate(),
              backgroundGraceController: const _NoopBackgroundGraceController(),
              foregroundServiceController:
                  const _NoopForegroundServiceController(),
              notificationPermissionController:
                  const _GrantedNotificationPermissionController(),
              displayWakeLockController: const _NoopDisplayWakeLockController(),
              turnCompletionAlertController:
                  const _NoopTurnCompletionAlertController(),
            )
            .app,
      );
      await tester.pumpAndSettle();

      expect(_workspaceController(tester), same(initialController));
    },
  );
}

ConnectionWorkspaceController _workspaceController(WidgetTester tester) {
  return tester
      .widget<WorkspaceContinuityHost>(find.byType(WorkspaceContinuityHost))
      .workspaceController;
}

_TestAppDependencySet _createTestDependencySet() {
  final clients = <FakeAgentAdapterClient>[];
  addTearDown(() async {
    for (final client in clients) {
      await client.close();
    }
  });

  FakeAgentAdapterClient createClient() {
    final client = FakeAgentAdapterClient();
    clients.add(client);
    return client;
  }

  return _TestAppDependencySet.base(
    createClient: createClient,
    trackClient: clients.add,
  );
}

typedef _TestDependencyMutation =
    _TestAppDependencySet Function(_TestAppDependencySet base);

final List<({String description, _TestDependencyMutation mutate})>
_controllerRebuildScenarios =
    <({String description, _TestDependencyMutation mutate})>[
      (
        description: 'the connection repository',
        mutate: (base) => base.copyWith(
          connectionRepository: MemoryCodexConnectionRepository(),
        ),
      ),
      (
        description: 'the model catalog store',
        mutate: (base) => base.copyWith(
          modelCatalogStore: MemoryConnectionModelCatalogStore(),
        ),
      ),
      (
        description: 'the recovery store',
        mutate: (base) => base.copyWith(
          recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
        ),
      ),
      (
        description: 'the injected agent adapter client',
        mutate: (base) =>
            base.copyWith(agentAdapterClient: _trackedClient(base)),
      ),
      (
        description: 'the remote runtime delegate factory',
        mutate: (base) => base.copyWith(
          agentAdapterRemoteRuntimeDelegateFactory:
              _alternateRemoteRuntimeDelegateFactory,
        ),
      ),
      (
        description: 'the platform policy',
        mutate: (base) => base.copyWith(
          platformPolicy: PocketPlatformPolicy.resolve(
            platform: TargetPlatform.macOS,
          ),
        ),
      ),
    ];

FakeAgentAdapterClient _trackedClient(_TestAppDependencySet base) {
  final client = FakeAgentAdapterClient();
  base.trackClient(client);
  return client;
}

final class _TestAppDependencySet {
  _TestAppDependencySet({
    required this.connectionRepository,
    required this.modelCatalogStore,
    required this.conversationHistoryRepository,
    required this.recoveryStore,
    required this.agentAdapterClient,
    required this.agentAdapterRemoteRuntimeDelegateFactory,
    required this.backgroundGraceController,
    required this.foregroundServiceController,
    required this.notificationPermissionController,
    required this.displayWakeLockController,
    required this.turnCompletionAlertController,
    required this.platformPolicy,
    required this.settingsOverlayDelegate,
    required void Function(FakeAgentAdapterClient client) trackClient,
  }) : _trackClient = trackClient;

  factory _TestAppDependencySet.base({
    required FakeAgentAdapterClient Function() createClient,
    required void Function(FakeAgentAdapterClient client) trackClient,
  }) {
    final platformPolicy = PocketPlatformPolicy.resolve(
      platform: TargetPlatform.iOS,
    );
    return _TestAppDependencySet(
      connectionRepository: MemoryCodexConnectionRepository(),
      modelCatalogStore: MemoryConnectionModelCatalogStore(),
      conversationHistoryRepository: null,
      recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
      agentAdapterClient: createClient(),
      agentAdapterRemoteRuntimeDelegateFactory:
          fakeAppRemoteRuntimeDelegateFactory,
      backgroundGraceController: const _NoopBackgroundGraceController(),
      foregroundServiceController: const _NoopForegroundServiceController(),
      notificationPermissionController:
          const _GrantedNotificationPermissionController(),
      displayWakeLockController: const _NoopDisplayWakeLockController(),
      turnCompletionAlertController: const _NoopTurnCompletionAlertController(),
      platformPolicy: platformPolicy,
      settingsOverlayDelegate: const _StableSettingsOverlayDelegate('base'),
      trackClient: trackClient,
    );
  }

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
  final void Function(FakeAgentAdapterClient client) _trackClient;

  PocketRelayApp get app {
    return PocketRelayApp(
      connectionRepository: connectionRepository,
      modelCatalogStore: modelCatalogStore,
      conversationHistoryRepository: conversationHistoryRepository,
      recoveryStore: recoveryStore,
      agentAdapterClient: agentAdapterClient,
      agentAdapterRemoteRuntimeDelegateFactory:
          agentAdapterRemoteRuntimeDelegateFactory,
      backgroundGraceController: backgroundGraceController,
      foregroundServiceController: foregroundServiceController,
      notificationPermissionController: notificationPermissionController,
      displayWakeLockController: displayWakeLockController,
      turnCompletionAlertController: turnCompletionAlertController,
      platformPolicy: platformPolicy,
      settingsOverlayDelegate: settingsOverlayDelegate,
    );
  }

  PocketRelayAppDependencies get dependencies {
    return PocketRelayAppDependencies(
      connectionRepository: connectionRepository,
      modelCatalogStore: modelCatalogStore,
      conversationHistoryRepository: conversationHistoryRepository,
      recoveryStore: recoveryStore,
      agentAdapterClient: agentAdapterClient,
      agentAdapterRemoteRuntimeDelegateFactory:
          agentAdapterRemoteRuntimeDelegateFactory,
      backgroundGraceController: backgroundGraceController,
      foregroundServiceController: foregroundServiceController,
      notificationPermissionController: notificationPermissionController,
      displayWakeLockController: displayWakeLockController,
      turnCompletionAlertController: turnCompletionAlertController,
      platformPolicy: platformPolicy,
      settingsOverlayDelegate: settingsOverlayDelegate,
    );
  }

  void trackClient(FakeAgentAdapterClient client) {
    _trackClient(client);
  }

  _TestAppDependencySet copyWith({
    Object? connectionRepository = _unset,
    Object? modelCatalogStore = _unset,
    Object? conversationHistoryRepository = _unset,
    Object? recoveryStore = _unset,
    Object? agentAdapterClient = _unset,
    Object? agentAdapterRemoteRuntimeDelegateFactory = _unset,
    Object? backgroundGraceController = _unset,
    Object? foregroundServiceController = _unset,
    Object? notificationPermissionController = _unset,
    Object? displayWakeLockController = _unset,
    Object? turnCompletionAlertController = _unset,
    Object? platformPolicy = _unset,
    Object? settingsOverlayDelegate = _unset,
  }) {
    return _TestAppDependencySet(
      connectionRepository: identical(connectionRepository, _unset)
          ? this.connectionRepository
          : connectionRepository as CodexConnectionRepository?,
      modelCatalogStore: identical(modelCatalogStore, _unset)
          ? this.modelCatalogStore
          : modelCatalogStore as ConnectionModelCatalogStore?,
      conversationHistoryRepository:
          identical(conversationHistoryRepository, _unset)
          ? this.conversationHistoryRepository
          : conversationHistoryRepository
                as WorkspaceConversationHistoryRepository?,
      recoveryStore: identical(recoveryStore, _unset)
          ? this.recoveryStore
          : recoveryStore as ConnectionWorkspaceRecoveryStore?,
      agentAdapterClient: identical(agentAdapterClient, _unset)
          ? this.agentAdapterClient
          : agentAdapterClient as AgentAdapterClient?,
      agentAdapterRemoteRuntimeDelegateFactory:
          identical(agentAdapterRemoteRuntimeDelegateFactory, _unset)
          ? this.agentAdapterRemoteRuntimeDelegateFactory
          : agentAdapterRemoteRuntimeDelegateFactory
                as AgentAdapterRemoteRuntimeDelegateFactory?,
      backgroundGraceController: identical(backgroundGraceController, _unset)
          ? this.backgroundGraceController
          : backgroundGraceController as BackgroundGraceController?,
      foregroundServiceController:
          identical(foregroundServiceController, _unset)
          ? this.foregroundServiceController
          : foregroundServiceController as ForegroundServiceController?,
      notificationPermissionController:
          identical(notificationPermissionController, _unset)
          ? this.notificationPermissionController
          : notificationPermissionController
                as NotificationPermissionController?,
      displayWakeLockController: identical(displayWakeLockController, _unset)
          ? this.displayWakeLockController
          : displayWakeLockController as DisplayWakeLockController?,
      turnCompletionAlertController:
          identical(turnCompletionAlertController, _unset)
          ? this.turnCompletionAlertController
          : turnCompletionAlertController as TurnCompletionAlertController?,
      platformPolicy: identical(platformPolicy, _unset)
          ? this.platformPolicy
          : platformPolicy as PocketPlatformPolicy?,
      settingsOverlayDelegate: identical(settingsOverlayDelegate, _unset)
          ? this.settingsOverlayDelegate
          : settingsOverlayDelegate as ConnectionSettingsOverlayDelegate,
      trackClient: _trackClient,
    );
  }
}

const Object _unset = Object();

AgentAdapterRemoteRuntimeDelegate _alternateRemoteRuntimeDelegateFactory(
  AgentAdapterKind kind,
) {
  return const FakeAppRemoteRuntimeDelegate(
    notRunningDetail: 'Alternate remote runtime policy.',
  );
}

final class _FakeConversationHistoryRepository
    implements WorkspaceConversationHistoryRepository {
  @override
  Future<List<WorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    return const <WorkspaceConversationSummary>[];
  }
}

class _StableSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  const _StableSettingsOverlayDelegate(this.id);

  final String id;

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    ConnectionRemoteRuntimeState? initialRemoteRuntime,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    List<ConnectionSettingsSystemTemplate> availableSystemTemplates =
        const <ConnectionSettingsSystemTemplate>[],
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
    ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
    ConnectionSettingsSystemTester? onTestSystem,
  }) async {
    return null;
  }
}

final class _NoopSettingsOverlayDelegate
    extends _StableSettingsOverlayDelegate {
  const _NoopSettingsOverlayDelegate() : super('noop');
}

final class _NoopBackgroundGraceController
    implements BackgroundGraceController {
  const _NoopBackgroundGraceController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

final class _NoopForegroundServiceController
    implements ForegroundServiceController {
  const _NoopForegroundServiceController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

final class _GrantedNotificationPermissionController
    implements NotificationPermissionController {
  const _GrantedNotificationPermissionController();

  @override
  Future<bool> isGranted() async => true;

  @override
  Future<bool> requestPermission() async => true;
}

final class _NoopDisplayWakeLockController
    implements DisplayWakeLockController {
  const _NoopDisplayWakeLockController();

  @override
  Future<void> setEnabled(bool enabled) async {}
}

final class _NoopTurnCompletionAlertController
    implements TurnCompletionAlertController {
  const _NoopTurnCompletionAlertController();

  @override
  Future<void> clearBackgroundAlert() async {}

  @override
  Future<void> emitForegroundSignal() async {}

  @override
  Future<void> showBackgroundAlert({
    required String title,
    String? body,
  }) async {}
}
