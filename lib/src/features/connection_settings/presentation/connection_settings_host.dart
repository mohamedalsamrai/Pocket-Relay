import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_presenter.dart';

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
        onToggleChanged: _updateToggle,
        onCancel: widget.onCancel,
        onSave: _save,
      ),
    );
  }

  ConnectionSettingsContract _buildContract([
    ConnectionSettingsFormState? formState,
  ]) {
    return _presenter.present(
      initialProfile: widget.initialProfile,
      initialSecrets: widget.initialSecrets,
      formState: formState ?? _formState,
      remoteRuntime: _remoteRuntime,
      availableModelCatalog: _availableModelCatalog,
      availableModelCatalogSource: _availableModelCatalogSource,
      didModelCatalogRefreshFail: _didModelCatalogRefreshFail,
      supportsModelCatalogRefresh: widget.onRefreshModelCatalog != null,
      isRefreshingModelCatalog: _isRefreshingModelCatalog,
      supportsLocalConnectionMode:
          widget.platformBehavior.supportsLocalConnectionMode,
    );
  }

  void _updateField(ConnectionSettingsFieldId fieldId, String value) {
    setState(() {
      _formState = _formState.copyWith(
        draft: _formState.draft.copyWithField(fieldId, value),
      );
    });
    if (_shouldRefreshRemoteRuntimeForField(fieldId)) {
      _scheduleRemoteRuntimeRefresh();
    }
  }

  void _updateConnectionMode(ConnectionMode connectionMode) {
    setState(() {
      _formState = _formState.copyWith(
        draft: _formState.draft.copyWithConnectionMode(connectionMode),
      );
    });
    _scheduleRemoteRuntimeRefresh();
  }

  void _updateAuthMode(AuthMode authMode) {
    setState(() {
      _formState = _formState.copyWith(
        draft: _formState.draft.copyWith(authMode: authMode),
      );
    });
    _scheduleRemoteRuntimeRefresh();
  }

  void _updateToggle(ConnectionSettingsToggleId toggleId, bool value) {
    setState(() {
      _formState = _formState.copyWith(
        draft: _formState.draft.copyWithToggle(toggleId, value),
      );
    });
  }

  void _updateReasoningEffort(CodexReasoningEffort? reasoningEffort) {
    setState(() {
      _formState = _formState.copyWith(
        draft: _formState.draft.copyWith(reasoningEffort: reasoningEffort),
      );
    });
  }

  void _updateModel(String? modelId) {
    final normalizedModel = modelId?.trim() ?? '';
    final nextEffort = codexNormalizedReasoningEffortForModel(
      normalizedModel.isEmpty ? null : normalizedModel,
      _formState.draft.reasoningEffort,
      availableModelCatalog: _availableModelCatalog,
    );
    setState(() {
      _formState = _formState.copyWith(
        draft: _formState.draft.copyWith(
          model: normalizedModel,
          reasoningEffort: nextEffort,
        ),
      );
    });
  }

  bool _shouldRefreshRemoteRuntimeForField(ConnectionSettingsFieldId fieldId) {
    return switch (fieldId) {
      ConnectionSettingsFieldId.host ||
      ConnectionSettingsFieldId.port ||
      ConnectionSettingsFieldId.username ||
      ConnectionSettingsFieldId.workspaceDir ||
      ConnectionSettingsFieldId.codexPath ||
      ConnectionSettingsFieldId.hostFingerprint ||
      ConnectionSettingsFieldId.password ||
      ConnectionSettingsFieldId.privateKeyPem ||
      ConnectionSettingsFieldId.privateKeyPassphrase => true,
      _ => false,
    };
  }

  void _scheduleRemoteRuntimeRefresh({bool immediate = false}) {
    _remoteRuntimeRefreshDebounce?.cancel();
    final onRefreshRemoteRuntime = widget.onRefreshRemoteRuntime;
    if (onRefreshRemoteRuntime == null) {
      if (_remoteRuntime != widget.initialRemoteRuntime) {
        setState(() {
          _remoteRuntime = widget.initialRemoteRuntime;
        });
      }
      return;
    }

    if (_formState.draft.connectionMode != ConnectionMode.remote) {
      if (_remoteRuntime != null) {
        setState(() {
          _remoteRuntime = null;
        });
      }
      return;
    }

    final probePayload = _buildContract().saveAction.submitPayload;
    if (probePayload == null) {
      const nextRuntime = ConnectionRemoteRuntimeState.unknown();
      if (_remoteRuntime != nextRuntime) {
        setState(() {
          _remoteRuntime = nextRuntime;
        });
      }
      return;
    }

    const checkingRuntime = ConnectionRemoteRuntimeState(
      hostCapability: ConnectionRemoteHostCapabilityState.checking(),
      server: ConnectionRemoteServerState.unknown(),
    );
    if ((!immediate || _remoteRuntime == null) &&
        _remoteRuntime != checkingRuntime) {
      setState(() {
        _remoteRuntime = checkingRuntime;
      });
    }

    final refreshToken = ++_remoteRuntimeRefreshToken;
    Future<void> runProbe() async {
      try {
        final remoteRuntime = await onRefreshRemoteRuntime(probePayload);
        if (!mounted || refreshToken != _remoteRuntimeRefreshToken) {
          return;
        }
        setState(() {
          _remoteRuntime = remoteRuntime;
        });
      } catch (error) {
        if (!mounted || refreshToken != _remoteRuntimeRefreshToken) {
          return;
        }
        setState(() {
          _remoteRuntime = ConnectionRemoteRuntimeState(
            hostCapability: ConnectionRemoteHostCapabilityState.probeFailed(
              detail: '$error',
            ),
            server: const ConnectionRemoteServerState.unknown(),
          );
        });
      }
    }

    if (immediate) {
      unawaited(runProbe());
      return;
    }

    _remoteRuntimeRefreshDebounce = Timer(
      const Duration(milliseconds: 350),
      () {
        unawaited(runProbe());
      },
    );
  }

  Future<void> _refreshModelCatalog() async {
    final onRefreshModelCatalog = widget.onRefreshModelCatalog;
    if (onRefreshModelCatalog == null || _isRefreshingModelCatalog) {
      return;
    }

    setState(() {
      _isRefreshingModelCatalog = true;
      _didModelCatalogRefreshFail = false;
    });

    try {
      final refreshedCatalog = await onRefreshModelCatalog(_formState.draft);
      if (!mounted) {
        return;
      }
      if (refreshedCatalog == null) {
        setState(() {
          _didModelCatalogRefreshFail = true;
        });
        return;
      }

      final selectedModelId = _formState.draft.model.trim().isEmpty
          ? null
          : _formState.draft.model.trim();
      final nextEffort = codexNormalizedReasoningEffortForModel(
        selectedModelId,
        _formState.draft.reasoningEffort,
        availableModelCatalog: refreshedCatalog,
      );
      setState(() {
        _availableModelCatalog = refreshedCatalog;
        _availableModelCatalogSource =
            ConnectionSettingsModelCatalogSource.connectionCache;
        _didModelCatalogRefreshFail = false;
        _formState = _formState.copyWith(
          draft: _formState.draft.copyWith(reasoningEffort: nextEffort),
        );
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _didModelCatalogRefreshFail = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshingModelCatalog = false;
        });
      }
    }
  }

  void _save() {
    final nextState = _formState.revealValidationErrors();
    final contract = _buildContract(nextState);
    setState(() {
      _formState = nextState;
    });

    final payload = contract.saveAction.submitPayload;
    if (!contract.saveAction.canSubmit || payload == null) {
      return;
    }

    widget.onSubmit(payload);
  }
}

class ConnectionSettingsHostViewModel {
  const ConnectionSettingsHostViewModel({
    required this.contract,
    required this.fieldControllers,
  });

  final ConnectionSettingsContract contract;
  final Map<ConnectionSettingsFieldId, TextEditingController> fieldControllers;

  TextEditingController controllerForField(ConnectionSettingsFieldId fieldId) {
    return fieldControllers[fieldId]!;
  }

  Map<ConnectionSettingsFieldId, ConnectionSettingsTextFieldContract> fieldMap(
    Iterable<ConnectionSettingsTextFieldContract> fields,
  ) {
    return <ConnectionSettingsFieldId, ConnectionSettingsTextFieldContract>{
      for (final field in fields) field.id: field,
    };
  }
}

class ConnectionSettingsHostActions {
  const ConnectionSettingsHostActions({
    required this.onFieldChanged,
    required this.onModelChanged,
    required this.onConnectionModeChanged,
    required this.onAuthModeChanged,
    required this.onReasoningEffortChanged,
    required this.onRefreshModelCatalog,
    required this.onToggleChanged,
    required this.onCancel,
    required this.onSave,
  });

  final void Function(ConnectionSettingsFieldId fieldId, String value)
  onFieldChanged;
  final ValueChanged<String?> onModelChanged;
  final ValueChanged<ConnectionMode> onConnectionModeChanged;
  final ValueChanged<AuthMode> onAuthModeChanged;
  final ValueChanged<CodexReasoningEffort?> onReasoningEffortChanged;
  final Future<void> Function() onRefreshModelCatalog;
  final void Function(ConnectionSettingsToggleId toggleId, bool value)
  onToggleChanged;
  final VoidCallback onCancel;
  final VoidCallback onSave;
}
