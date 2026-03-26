import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';

part 'host/host_models.dart';
part 'host/model_catalog_refresh.dart';
part 'host/remote_runtime_refresh.dart';
part 'host/remote_server_actions.dart';
part 'host/state_updates.dart';

typedef ConnectionSettingsHostBuilder =
    Widget Function(
      BuildContext context,
      ConnectionSettingsHostViewModel viewModel,
      ConnectionSettingsHostActions actions,
    );

typedef ConnectionSettingsRemoteRuntimeRefresher =
    Future<ConnectionRemoteRuntimeState> Function(
      ConnectionSettingsSubmitPayload payload,
    );

typedef ConnectionSettingsRemoteServerActionRunner =
    Future<ConnectionRemoteRuntimeState> Function();

class ConnectionSettingsHost extends StatefulWidget {
  const ConnectionSettingsHost({
    super.key,
    required this.initialProfile,
    required this.initialSecrets,
    this.initialRemoteRuntime,
    this.availableModelCatalog,
    this.availableModelCatalogSource,
    this.onRefreshModelCatalog,
    this.onRefreshRemoteRuntime,
    this.onStartRemoteServer,
    this.onStopRemoteServer,
    this.onRestartRemoteServer,
    required this.onCancel,
    required this.onSubmit,
    required this.builder,
    required this.platformBehavior,
  });

  final ConnectionProfile initialProfile;
  final ConnectionSecrets initialSecrets;
  final ConnectionRemoteRuntimeState? initialRemoteRuntime;
  final ConnectionModelCatalog? availableModelCatalog;
  final ConnectionSettingsModelCatalogSource? availableModelCatalogSource;
  final Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  onRefreshModelCatalog;
  final ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime;
  final ConnectionSettingsRemoteServerActionRunner? onStartRemoteServer;
  final ConnectionSettingsRemoteServerActionRunner? onStopRemoteServer;
  final ConnectionSettingsRemoteServerActionRunner? onRestartRemoteServer;
  final VoidCallback onCancel;
  final ValueChanged<ConnectionSettingsSubmitPayload> onSubmit;
  final ConnectionSettingsHostBuilder builder;
  final PocketPlatformBehavior platformBehavior;

  @override
  State<ConnectionSettingsHost> createState() => _ConnectionSettingsHostState();
}

class _ConnectionSettingsHostState extends State<ConnectionSettingsHost> {
  final _presenter = const ConnectionSettingsPresenter();
  late final Map<ConnectionSettingsFieldId, TextEditingController> _controllers;
  late ConnectionSettingsFormState _formState;
  ConnectionModelCatalog? _availableModelCatalog;
  ConnectionSettingsModelCatalogSource? _availableModelCatalogSource;
  bool _didModelCatalogRefreshFail = false;
  bool _isRefreshingModelCatalog = false;
  ConnectionRemoteRuntimeState? _remoteRuntime;
  ConnectionSettingsRemoteServerActionId? _activeRemoteServerAction;
  Timer? _remoteRuntimeRefreshDebounce;
  int _remoteRuntimeRefreshToken = 0;

  @override
  void initState() {
    super.initState();
    _formState = ConnectionSettingsFormState.initial(
      profile: widget.initialProfile,
      secrets: widget.initialSecrets,
    );
    _remoteRuntime = widget.initialRemoteRuntime;
    _availableModelCatalog = widget.availableModelCatalog;
    _availableModelCatalogSource = widget.availableModelCatalogSource;
    final draft = _formState.draft;
    _controllers = <ConnectionSettingsFieldId, TextEditingController>{
      for (final fieldId in ConnectionSettingsFieldId.values)
        fieldId: TextEditingController(text: draft.valueForField(fieldId)),
    };
    _scheduleRemoteRuntimeRefresh(immediate: true);
  }

  @override
  void dispose() {
    _remoteRuntimeRefreshDebounce?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contract = _buildContract();
    return widget.builder(
      context,
      ConnectionSettingsHostViewModel(
        contract: contract,
        fieldControllers: _controllers,
      ),
      ConnectionSettingsHostActions(
        onFieldChanged: _updateField,
        onModelChanged: _updateModel,
        onConnectionModeChanged: _updateConnectionMode,
        onAuthModeChanged: _updateAuthMode,
        onReasoningEffortChanged: _updateReasoningEffort,
        onRefreshModelCatalog: _refreshModelCatalog,
        onRemoteServerAction: _runRemoteServerAction,
        onToggleChanged: _updateToggle,
        onCancel: widget.onCancel,
        onSave: _save,
      ),
    );
  }

  ConnectionSettingsContract _buildContract([
    ConnectionSettingsFormState? formState,
  ]) => _buildConnectionSettingsHostContract(this, formState: formState);

  void _updateField(ConnectionSettingsFieldId fieldId, String value) =>
      _updateConnectionSettingsField(this, fieldId, value);

  void _updateConnectionMode(ConnectionMode connectionMode) =>
      _updateConnectionSettingsConnectionMode(this, connectionMode);

  void _updateAuthMode(AuthMode authMode) =>
      _updateConnectionSettingsAuthMode(this, authMode);

  void _updateToggle(ConnectionSettingsToggleId toggleId, bool value) =>
      _updateConnectionSettingsToggle(this, toggleId, value);

  void _updateReasoningEffort(CodexReasoningEffort? reasoningEffort) =>
      _updateConnectionSettingsReasoningEffort(this, reasoningEffort);

  void _updateModel(String? modelId) =>
      _updateConnectionSettingsModel(this, modelId);

  bool _shouldRefreshRemoteRuntimeForField(ConnectionSettingsFieldId fieldId) =>
      _shouldRefreshConnectionSettingsRemoteRuntimeForField(fieldId);

  void _scheduleRemoteRuntimeRefresh({bool immediate = false}) =>
      _scheduleConnectionSettingsRemoteRuntimeRefresh(
        this,
        immediate: immediate,
      );

  Future<void> _refreshModelCatalog() =>
      _refreshConnectionSettingsModelCatalog(this);

  Future<void> _runRemoteServerAction(
    ConnectionSettingsRemoteServerActionId actionId,
  ) => _runConnectionSettingsRemoteServerAction(this, actionId);

  Future<ConnectionRemoteRuntimeState> _remoteRuntimeAfterServerActionFailure({
    required Object error,
    required ConnectionRemoteRuntimeState fallbackRuntime,
  }) => _connectionSettingsRemoteRuntimeAfterServerActionFailure(
    this,
    error: error,
    fallbackRuntime: fallbackRuntime,
  );

  void _setStateInternal(VoidCallback fn) {
    setState(fn);
  }

  void _save() => _saveConnectionSettingsHost(this);
}
