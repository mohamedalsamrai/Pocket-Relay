import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../secure/secure_connection_repository_read.dart';
import '../secure/secure_connection_repository_state.dart';
import '../secure/secure_connection_repository_write.dart';
import 'connection_repository_contract.dart';

class SecureCodexConnectionRepository implements CodexConnectionRepository {
  SecureCodexConnectionRepository({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
    ConnectionIdGenerator? connectionIdGenerator,
    SystemIdGenerator? systemIdGenerator,
  }) : _state = SecureConnectionRepositoryState(
         secureStorage: secureStorage,
         preferences: preferences,
         connectionIdGenerator: connectionIdGenerator,
         systemIdGenerator: systemIdGenerator,
       );

  final SecureConnectionRepositoryState _state;

  @override
  Future<WorkspaceCatalogState> loadWorkspaceCatalog() =>
      secureLoadWorkspaceCatalog(_state);

  @override
  Future<SystemCatalogState> loadSystemCatalog() =>
      secureLoadSystemCatalog(_state);

  @override
  Future<SavedWorkspace> loadWorkspace(String workspaceId) =>
      secureLoadWorkspace(_state, workspaceId);

  @override
  Future<SavedSystem> loadSystem(String systemId) =>
      secureLoadSystem(_state, systemId);

  @override
  Future<SavedWorkspace> createWorkspace({required WorkspaceProfile profile}) =>
      secureCreateWorkspace(_state, profile: profile);

  @override
  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) => secureCreateSystem(_state, profile: profile, secrets: secrets);

  @override
  Future<void> saveWorkspace(SavedWorkspace workspace) =>
      secureSaveWorkspace(_state, workspace);

  @override
  Future<void> saveSystem(SavedSystem system) =>
      secureSaveSystem(_state, system);

  @override
  Future<void> deleteWorkspace(String workspaceId) =>
      secureDeleteWorkspace(_state, workspaceId);

  @override
  Future<void> deleteSystem(String systemId) =>
      secureDeleteSystem(_state, systemId);

  @override
  Future<ConnectionCatalogState> loadCatalog() => secureLoadCatalog(_state);

  @override
  Future<SavedConnection> loadConnection(String connectionId) =>
      secureLoadConnection(_state, connectionId);

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) => secureCreateConnection(_state, profile: profile, secrets: secrets);

  @override
  Future<void> saveConnection(SavedConnection connection) =>
      secureSaveConnection(_state, connection);

  @override
  Future<void> deleteConnection(String connectionId) =>
      secureDeleteConnection(_state, connectionId);
}
