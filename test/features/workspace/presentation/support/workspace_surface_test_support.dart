import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_saved_connections_content.dart';

export 'dart:async';
export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/errors/device_capability_errors.dart';
export 'package:pocket_relay/src/core/errors/pocket_error.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
export 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
export 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
export 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
export 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
export 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
export 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
export 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
export 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
export 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
export '../../support/workspace_test_harness.dart';

Widget buildDormantRosterApp(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
}) {
  final resolvedSettingsOverlayDelegate =
      settingsOverlayDelegate ??
      (DeferredConnectionSettingsOverlayDelegate()..complete(null));
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ConnectionWorkspaceSavedConnectionsContent(
            workspaceController: controller,
            description: 'Saved connections test surface.',
            settingsOverlayDelegate: resolvedSettingsOverlayDelegate,
            useSafeArea: false,
          );
        },
      ),
    ),
  );
}

Widget buildLiveLaneApp(
  ConnectionWorkspaceController controller,
  ConnectionLaneBinding laneBinding, {
  required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ConnectionWorkspaceLiveLaneSurface(
        workspaceController: controller,
        laneBinding: laneBinding,
        platformPolicy: PocketPlatformPolicy.resolve(
          platform: TargetPlatform.android,
        ),
        settingsOverlayDelegate: settingsOverlayDelegate,
      ),
    ),
  );
}

Widget buildWorkspaceDrivenLiveLaneApp(
  ConnectionWorkspaceController controller, {
  required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final laneBinding = controller.selectedLaneBinding;
        if (laneBinding == null) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          body: ConnectionWorkspaceLiveLaneSurface(
            workspaceController: controller,
            laneBinding: laneBinding,
            platformPolicy: PocketPlatformPolicy.resolve(
              platform: TargetPlatform.android,
            ),
            settingsOverlayDelegate: settingsOverlayDelegate,
          ),
        );
      },
    ),
  );
}

ConnectionModelCatalog connectionModelCatalog({
  required String connectionId,
  required DateTime fetchedAt,
  required String model,
  required String displayName,
  required String description,
}) {
  return ConnectionModelCatalog(
    connectionId: connectionId,
    fetchedAt: fetchedAt,
    models: <ConnectionAvailableModel>[
      ConnectionAvailableModel(
        id: 'preset_$model',
        model: model,
        displayName: displayName,
        description: description,
        hidden: false,
        supportedReasoningEfforts:
            const <ConnectionAvailableModelReasoningEffortOption>[
              ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.medium,
                description: 'Balanced mode.',
              ),
            ],
        defaultReasoningEffort: CodexReasoningEffort.medium,
        inputModalities: const <String>['text'],
        supportsPersonality: false,
        isDefault: true,
      ),
    ],
  );
}

CodexAppServerModel backendModel({
  required String id,
  required String model,
  required String displayName,
  required String description,
  bool isDefault = false,
}) {
  return CodexAppServerModel(
    id: id,
    model: model,
    displayName: displayName,
    description: description,
    hidden: false,
    supportedReasoningEfforts: const <CodexAppServerReasoningEffortOption>[],
    defaultReasoningEffort: CodexReasoningEffort.medium,
    inputModalities: const <String>['text'],
    supportsPersonality: false,
    isDefault: isDefault,
  );
}

class DeferredConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  int launchCount = 0;
  final List<(ConnectionProfile, ConnectionSecrets)> launchedSettings =
      <(ConnectionProfile, ConnectionSecrets)>[];
  final List<ConnectionModelCatalog?> launchedModelCatalogs =
      <ConnectionModelCatalog?>[];
  final List<ConnectionRemoteRuntimeState?> launchedInitialRemoteRuntimes =
      <ConnectionRemoteRuntimeState?>[];
  final List<ConnectionSettingsModelCatalogSource?>
  launchedModelCatalogSources = <ConnectionSettingsModelCatalogSource?>[];
  final List<
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  >
  launchedRefreshCallbacks =
      <
        Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
      >[];
  final List<ConnectionSettingsRemoteRuntimeRefresher?>
  launchedRemoteRuntimeCallbacks =
      <ConnectionSettingsRemoteRuntimeRefresher?>[];
  final List<List<ConnectionSettingsSystemTemplate>> launchedSystemTemplates =
      <List<ConnectionSettingsSystemTemplate>>[];
  final List<ConnectionSettingsSystemTester?> launchedSystemTesters =
      <ConnectionSettingsSystemTester?>[];
  Completer<ConnectionSettingsSubmitPayload?> _completer =
      Completer<ConnectionSettingsSubmitPayload?>();

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
  }) {
    launchCount += 1;
    launchedSettings.add((initialProfile, initialSecrets));
    launchedModelCatalogs.add(availableModelCatalog);
    launchedInitialRemoteRuntimes.add(initialRemoteRuntime);
    launchedModelCatalogSources.add(availableModelCatalogSource);
    launchedRefreshCallbacks.add(onRefreshModelCatalog);
    launchedRemoteRuntimeCallbacks.add(onRefreshRemoteRuntime);
    launchedSystemTemplates.add(availableSystemTemplates);
    launchedSystemTesters.add(onTestSystem);
    return _completer.future;
  }

  void complete(ConnectionSettingsSubmitPayload? payload) {
    if (_completer.isCompleted) {
      _completer = Completer<ConnectionSettingsSubmitPayload?>();
      _completer.complete(payload);
      return;
    }
    _completer.complete(payload);
  }
}

class DelayedMemoryCodexConnectionRepository
    extends MemoryCodexConnectionRepository {
  DelayedMemoryCodexConnectionRepository({required super.initialConnections});

  final Map<String, int> loadConnectionCallsById = <String, int>{};
  final Map<String, Completer<void>> loadConnectionGates =
      <String, Completer<void>>{};

  @override
  Future<SavedConnection> loadConnection(String connectionId) async {
    loadConnectionCallsById[connectionId] =
        (loadConnectionCallsById[connectionId] ?? 0) + 1;
    final gate = loadConnectionGates[connectionId];
    if (gate != null) {
      await gate.future;
    }
    return super.loadConnection(connectionId);
  }
}
