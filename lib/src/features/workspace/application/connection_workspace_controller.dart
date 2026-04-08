import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_capability_assets.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_system_templates.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_system_template.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_recovery_errors.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

import '../domain/connection_workspace_state.dart';

part 'connection_workspace_controller_lane.dart';
part 'connection_workspace_controller_remote_owner.dart';
part 'controller/app_lifecycle.dart';
part 'controller/binding_runtime.dart';
part 'controller/bootstrap.dart';
part 'controller/catalog_connections.dart';
part 'controller/catalog_systems.dart';
part 'controller/controller_shell.dart';
part 'controller/conversation_selection.dart';
part 'controller/delete_connection.dart';
part 'controller/device_continuity_warnings.dart';
part 'controller/recovery_diagnostics.dart';
part 'controller/recovery_persistence.dart';
part 'controller/reconnect.dart';
part 'controller/reconnect_transport.dart';
part 'controller/reconnect_turn_liveness.dart';
part 'controller/remote_runtime.dart';
part 'controller/state_sanitizers.dart';

typedef ConnectionLaneBindingFactory =
    ConnectionLaneBinding Function({
      required String connectionId,
      required SavedConnection connection,
    });
typedef WorkspaceNow = DateTime Function();

class ConnectionWorkspaceController extends ChangeNotifier {
  ConnectionWorkspaceController({
    required CodexConnectionRepository connectionRepository,
    required ConnectionLaneBindingFactory laneBindingFactory,
    ConnectionCapabilityAssets? connectionCapabilityAssets,
    @Deprecated('Use connectionCapabilityAssets instead.')
    ConnectionModelCatalogStore? modelCatalogStore,
    ConnectionWorkspaceRecoveryStore? recoveryStore,
    AgentAdapterRemoteRuntimeDelegateFactory? remoteRuntimeDelegateFactory,
    @Deprecated('Use remoteRuntimeDelegateFactory instead.')
    CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
        const CodexSshRemoteAppServerHostProbe(),
    @Deprecated('Use remoteRuntimeDelegateFactory instead.')
    CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
        const CodexSshRemoteAppServerOwnerInspector(),
    @Deprecated('Use remoteRuntimeDelegateFactory instead.')
    CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
        const CodexSshRemoteAppServerOwnerControl(),
    Duration recoveryPersistenceDebounceDuration = const Duration(
      milliseconds: 250,
    ),
    WorkspaceNow? now,
  }) : _connectionRepository = connectionRepository,
       _laneBindingFactory = laneBindingFactory,
       _connectionCapabilityAssets =
           connectionCapabilityAssets ??
           StoreBackedConnectionCapabilityAssets(
             connectionRepository: connectionRepository,
             modelCatalogStore: modelCatalogStore,
           ),
       _recoveryStore =
           recoveryStore ?? const NoopConnectionWorkspaceRecoveryStore(),
       _remoteRuntimeDelegateFactory =
           remoteRuntimeDelegateFactory ??
           ((kind) => createDefaultAgentAdapterRemoteRuntimeDelegate(
             kind,
             remoteHostProbe: remoteAppServerHostProbe,
             remoteOwnerInspector: remoteAppServerOwnerInspector,
             remoteOwnerControl: remoteAppServerOwnerControl,
           )),
       _recoveryPersistenceDebounceDuration =
           recoveryPersistenceDebounceDuration,
       _now = now ?? DateTime.now;

  final CodexConnectionRepository _connectionRepository;
  final ConnectionLaneBindingFactory _laneBindingFactory;
  final ConnectionCapabilityAssets _connectionCapabilityAssets;
  final ConnectionWorkspaceRecoveryStore _recoveryStore;
  final AgentAdapterRemoteRuntimeDelegateFactory _remoteRuntimeDelegateFactory;
  final Duration _recoveryPersistenceDebounceDuration;
  final WorkspaceNow _now;
  final Map<String, ConnectionLaneBinding> _liveBindingsByConnectionId =
      <String, ConnectionLaneBinding>{};
  final Map<
    String,
    ({
      ConnectionLaneBinding binding,
      VoidCallback listener,
      StreamSubscription<AgentAdapterEvent> appServerEventSubscription,
    })
  >
  _bindingRecoveryRegistrationsByConnectionId =
      <
        String,
        ({
          ConnectionLaneBinding binding,
          VoidCallback listener,
          StreamSubscription<AgentAdapterEvent> appServerEventSubscription,
        })
      >{};
  final Map<String, int> _remoteRuntimeRefreshGenerationByConnectionId =
      <String, int>{};
  final Set<String> _intentionalTransportDisconnectConnectionIds = <String>{};

  ConnectionWorkspaceState _state = const ConnectionWorkspaceState.initial();
  Future<void>? _initializationFuture;
  Future<void> _recoveryPersistence = Future<void>.value();
  Timer? _recoveryPersistenceDebounceTimer;
  ConnectionWorkspaceRecoveryState? _pendingRecoveryPersistenceState;
  ConnectionWorkspaceRecoveryState? _lastPersistedRecoveryState;
  ConnectionWorkspaceRecoveryState? _latestRecoveryPersistenceState;
  bool _isPersistingRecoveryState = false;
  bool _isDisposed = false;

  ConnectionWorkspaceState get state => _state;
  ConnectionCapabilityAssets get connectionCapabilityAssets =>
      _connectionCapabilityAssets;
  Future<void> flushRecoveryPersistence() => _enqueueRecoveryPersistence();

  @visibleForTesting
  ConnectionWorkspaceRecoveryState? get debugLatestUnsavedRecoveryState =>
      _latestUnsavedRecoveryStateSnapshot();

  void dismissFinishedWhileAwayNotice(String connectionId) {
    final assessment = _state.turnLivenessAssessmentFor(connectionId);
    if (assessment?.status !=
        ConnectionWorkspaceTurnLivenessStatus.finishedWhileAway) {
      return;
    }
    _clearTurnLivenessAssessment(connectionId);
  }

  AgentAdapterRemoteRuntimeDelegate createRemoteRuntimeDelegate(
    AgentAdapterKind kind,
  ) {
    return _remoteRuntimeDelegateFactory(kind);
  }

  ConnectionLaneBinding? get selectedLaneBinding {
    final selectedConnectionId = _state.selectedConnectionId;
    if (selectedConnectionId == null) {
      return null;
    }
    return _liveBindingsByConnectionId[selectedConnectionId];
  }

  ConnectionLaneBinding? bindingForConnectionId(String connectionId) {
    return _liveBindingsByConnectionId[connectionId];
  }

  Future<void> initialize() {
    return _initializationFuture ??= _initializeOnce();
  }

  Future<SavedConnection> loadSavedConnection(String connectionId) {
    return _loadWorkspaceSavedConnection(this, connectionId);
  }

  Future<String> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _createWorkspaceConnection(this, profile: profile, secrets: secrets);
  }

  Future<SavedSystem> loadSavedSystem(String systemId) {
    return _loadWorkspaceSavedSystem(this, systemId);
  }

  Future<String> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _createWorkspaceSystem(this, profile: profile, secrets: secrets);
  }

  Future<void> saveSavedSystem({
    required String systemId,
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _saveWorkspaceSavedSystem(
      this,
      systemId: systemId,
      profile: profile,
      secrets: secrets,
    );
  }

  Future<void> saveSavedConnection({
    required String connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _saveWorkspaceSavedConnection(
      this,
      connectionId: connectionId,
      profile: profile,
      secrets: secrets,
    );
  }

  Future<void> saveLiveConnectionEdits({
    required String connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) {
    return _saveWorkspaceLiveConnectionEdits(
      this,
      connectionId: connectionId,
      profile: profile,
      secrets: secrets,
    );
  }

  Future<void> reconnectConnection(String connectionId) {
    return _reconnectWorkspaceLane(this, connectionId);
  }

  Future<void> disconnectConnection(String connectionId) {
    return _disconnectWorkspaceConnection(this, connectionId);
  }

  Future<ConnectionRemoteRuntimeState> refreshRemoteRuntime({
    required String connectionId,
    ConnectionProfile? profile,
    ConnectionSecrets? secrets,
  }) {
    return _refreshWorkspaceRemoteRuntime(
      this,
      connectionId,
      profile: profile,
      secrets: secrets,
    );
  }

  Future<ConnectionRemoteRuntimeState> startRemoteServer({
    required String connectionId,
  }) {
    return _startWorkspaceRemoteServer(this, connectionId: connectionId);
  }

  Future<ConnectionRemoteRuntimeState> stopRemoteServer({
    required String connectionId,
  }) {
    return _stopWorkspaceRemoteServer(this, connectionId: connectionId);
  }

  Future<ConnectionRemoteRuntimeState> restartRemoteServer({
    required String connectionId,
  }) {
    return _restartWorkspaceRemoteServer(this, connectionId: connectionId);
  }

  Future<void> handleAppLifecycleStateChanged(AppLifecycleState state) {
    return _handleWorkspaceAppLifecycleState(this, state);
  }

  Future<void> resumeConversation({
    required String connectionId,
    required String threadId,
  }) {
    return _resumeWorkspaceConversationSelection(
      this,
      connectionId: connectionId,
      threadId: threadId,
    );
  }

  Future<void> deleteSavedConnection(String connectionId) {
    return _deleteWorkspaceSavedConnection(this, connectionId);
  }

  Future<void> deleteSavedSystem(String systemId) {
    return _deleteWorkspaceSavedSystem(this, systemId);
  }

  Future<void> instantiateConnection(String connectionId) {
    return _instantiateWorkspaceLiveConnection(this, connectionId);
  }

  void selectConnection(String connectionId) {
    _selectWorkspaceConnection(this, connectionId);
  }

  void showSavedConnections() {
    _showWorkspaceSavedConnections(this);
  }

  void showSavedSystems() {
    _showWorkspaceSavedSystems(this);
  }

  void setForegroundServiceWarning(PocketUserFacingError? warning) {
    _setWorkspaceForegroundServiceWarning(this, warning);
  }

  void setBackgroundGraceWarning(PocketUserFacingError? warning) {
    _setWorkspaceBackgroundGraceWarning(this, warning);
  }

  void setWakeLockWarning(PocketUserFacingError? warning) {
    _setWorkspaceWakeLockWarning(this, warning);
  }

  void setTurnCompletionAlertWarning(PocketUserFacingError? warning) {
    _setWorkspaceTurnCompletionAlertWarning(this, warning);
  }

  void terminateConnection(String connectionId) {
    _terminateWorkspaceConnection(this, connectionId);
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    final finalRecoveryPersistence = _enqueueRecoveryPersistence();
    _isDisposed = true;
    _recoveryPersistenceDebounceTimer?.cancel();
    unawaited(finalRecoveryPersistence);

    final liveBindingEntries = _liveBindingsByConnectionId.entries.toList();
    _liveBindingsByConnectionId.clear();
    for (final entry in liveBindingEntries) {
      _unregisterLiveBinding(entry.key);
      entry.value.dispose();
    }
    super.dispose();
  }
}
