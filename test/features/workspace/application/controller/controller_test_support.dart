import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

export 'dart:async';
export 'package:flutter_secure_storage/flutter_secure_storage.dart';
export 'package:flutter/widgets.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/errors/pocket_error.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
export 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
export 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
export 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
export 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
export 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
export 'package:shared_preferences/shared_preferences.dart';
export 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
export 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
export '../../support/workspace_test_harness.dart';

final class MutableRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  MutableRemoteOwnerControl({
    required CodexRemoteAppServerOwnerSnapshot snapshot,
  }) : _snapshot = snapshot;

  CodexRemoteAppServerOwnerSnapshot _snapshot;
  int startCalls = 0;
  int stopCalls = 0;
  int restartCalls = 0;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return _snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls += 1;
    await stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
    return startOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls += 1;
    _snapshot = CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.running,
      sessionName: 'pocket-relay-$ownerId',
      endpoint: const CodexRemoteAppServerEndpoint(
        host: '127.0.0.1',
        port: 4100,
      ),
      detail: 'Managed remote app-server is ready.',
    );
    return _snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls += 1;
    _snapshot = CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.missing,
      sessionName: 'pocket-relay-$ownerId',
      detail: 'No managed remote app-server is running for this connection.',
    );
    return _snapshot;
  }
}

class RecordingConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  RecordingConnectionWorkspaceRecoveryStore({this.initialState});

  final ConnectionWorkspaceRecoveryState? initialState;
  final List<ConnectionWorkspaceRecoveryState?> savedStates =
      <ConnectionWorkspaceRecoveryState?>[];
  ConnectionWorkspaceRecoveryState? _state;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    return _state ?? initialState;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    _state = state;
    savedStates.add(state);
  }
}

class FixedLoadConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  FixedLoadConnectionWorkspaceRecoveryStore(this.state);

  final ConnectionWorkspaceRecoveryState? state;
  final List<ConnectionWorkspaceRecoveryState?> attemptedSaves =
      <ConnectionWorkspaceRecoveryState?>[];

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async => state;

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    attemptedSaves.add(state);
  }
}

class DelayedLoadConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  DelayedLoadConnectionWorkspaceRecoveryStore({
    this.initialState,
    Completer<void>? loadCompleter,
    int immediateLoadCount = 0,
  }) : loadCompleter = loadCompleter ?? Completer<void>(),
       _remainingImmediateLoads = immediateLoadCount;

  final ConnectionWorkspaceRecoveryState? initialState;
  final Completer<void> loadCompleter;
  ConnectionWorkspaceRecoveryState? _state;
  int _remainingImmediateLoads;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    if (_remainingImmediateLoads > 0) {
      _remainingImmediateLoads -= 1;
      return _state ?? initialState;
    }
    await loadCompleter.future;
    return _state ?? initialState;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    _state = state;
  }
}

class DelayedFirstSaveConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  DelayedFirstSaveConnectionWorkspaceRecoveryStore({
    this.initialState,
    Completer<void>? firstSaveCompleter,
  }) : firstSaveCompleter = firstSaveCompleter ?? Completer<void>();

  final ConnectionWorkspaceRecoveryState? initialState;
  final Completer<void> firstSaveCompleter;
  final List<ConnectionWorkspaceRecoveryState?> attemptedStates =
      <ConnectionWorkspaceRecoveryState?>[];
  ConnectionWorkspaceRecoveryState? _state;
  var _saveCalls = 0;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    return _state ?? initialState;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    attemptedStates.add(state);
    _saveCalls += 1;
    if (_saveCalls == 1) {
      await firstSaveCompleter.future;
    }
    _state = state;
  }
}

class ToggleableFailingConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  ToggleableFailingConnectionWorkspaceRecoveryStore({
    this.initialState,
    this.saveError,
  });

  final ConnectionWorkspaceRecoveryState? initialState;
  final List<ConnectionWorkspaceRecoveryState?> attemptedStates =
      <ConnectionWorkspaceRecoveryState?>[];
  ConnectionWorkspaceRecoveryState? _state;
  Object? saveError;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    return _state ?? initialState;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    attemptedStates.add(state);
    final error = saveError;
    if (error != null) {
      throw error;
    }
    _state = state;
  }
}

Future<void> startBusyTurn(
  ConnectionLaneBinding binding,
  FakeCodexAppServerClient appServerClient,
) async {
  appServerClient.emit(
    const CodexAppServerNotificationEvent(
      method: 'thread/started',
      params: <String, Object?>{
        'thread': <String, Object?>{'id': 'thread_123'},
      },
    ),
  );
  appServerClient.emit(
    const CodexAppServerNotificationEvent(
      method: 'turn/started',
      params: <String, Object?>{
        'threadId': 'thread_123',
        'turn': <String, Object?>{
          'id': 'turn_running',
          'status': 'running',
          'model': 'gpt-5.4',
          'effort': 'high',
        },
      },
    ),
  );
  await Future<void>.delayed(Duration.zero);
  expect(binding.sessionController.sessionState.isBusy, isTrue);
}

class StickyDisconnectFakeCodexAppServerClient
    extends FakeCodexAppServerClient {
  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
  }
}

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  FakeFlutterSecureStorage(this.data);

  final Map<String, String> data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
      return;
    }
    data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}
