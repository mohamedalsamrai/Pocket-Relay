import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'connection_repository_contract.dart';
import 'connection_repository_normalization.dart';

class MemoryCodexConnectionRepository implements CodexConnectionRepository {
  MemoryCodexConnectionRepository({
    Iterable<SavedConnection> initialConnections = const <SavedConnection>[],
    Iterable<SavedWorkspace> initialWorkspaces = const <SavedWorkspace>[],
    Iterable<SavedSystem> initialSystems = const <SavedSystem>[],
    ConnectionIdGenerator? connectionIdGenerator,
    SystemIdGenerator? systemIdGenerator,
  }) : _workspaceIdGenerator =
           connectionIdGenerator ?? _defaultMemoryConnectionIdGenerator(),
       _systemIdGenerator =
           systemIdGenerator ?? _defaultMemorySystemIdGenerator() {
    _seedMemoryRepository(
      this,
      initialConnections: initialConnections,
      initialWorkspaces: initialWorkspaces,
      initialSystems: initialSystems,
    );
  }

  factory MemoryCodexConnectionRepository.single({
    required SavedProfile savedProfile,
    String connectionId = 'conn_1',
  }) {
    return MemoryCodexConnectionRepository(
      initialConnections: <SavedConnection>[
        SavedConnection(
          id: connectionId,
          profile: savedProfile.profile,
          secrets: savedProfile.secrets,
        ),
      ],
    );
  }

  late final Map<String, SavedWorkspace> _workspacesById;
  late final List<String> _orderedWorkspaceIds;
  late final Map<String, SavedSystem> _systemsById;
  late final List<String> _orderedSystemIds;
  final ConnectionIdGenerator _workspaceIdGenerator;
  final SystemIdGenerator _systemIdGenerator;

  @override
  Future<WorkspaceCatalogState> loadWorkspaceCatalog() =>
      _memoryLoadWorkspaceCatalog(this);

  @override
  Future<SystemCatalogState> loadSystemCatalog() =>
      _memoryLoadSystemCatalog(this);

  @override
  Future<SavedWorkspace> loadWorkspace(String workspaceId) =>
      _memoryLoadWorkspace(this, workspaceId);

  @override
  Future<SavedSystem> loadSystem(String systemId) =>
      _memoryLoadSystem(this, systemId);

  @override
  Future<SavedWorkspace> createWorkspace({required WorkspaceProfile profile}) =>
      _memoryCreateWorkspace(this, profile: profile);

  @override
  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) => _memoryCreateSystem(this, profile: profile, secrets: secrets);

  @override
  Future<void> saveWorkspace(SavedWorkspace workspace) =>
      _memorySaveWorkspace(this, workspace);

  @override
  Future<void> saveSystem(SavedSystem system) =>
      _memorySaveSystem(this, system);

  @override
  Future<void> deleteWorkspace(String workspaceId) =>
      _memoryDeleteWorkspace(this, workspaceId);

  @override
  Future<void> deleteSystem(String systemId) =>
      _memoryDeleteSystem(this, systemId);

  @override
  Future<ConnectionCatalogState> loadCatalog() => _memoryLoadCatalog(this);

  @override
  Future<SavedConnection> loadConnection(String connectionId) =>
      _memoryLoadConnection(this, connectionId);

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) => _memoryCreateConnection(this, profile: profile, secrets: secrets);

  @override
  Future<void> saveConnection(SavedConnection connection) =>
      _memorySaveConnection(this, connection);

  @override
  Future<void> deleteConnection(String connectionId) =>
      _memoryDeleteConnection(this, connectionId);
}

void _seedMemoryRepository(
  MemoryCodexConnectionRepository repository, {
  required Iterable<SavedConnection> initialConnections,
  required Iterable<SavedWorkspace> initialWorkspaces,
  required Iterable<SavedSystem> initialSystems,
}) {
  repository._workspacesById = <String, SavedWorkspace>{
    for (final workspace in initialWorkspaces) workspace.id: workspace,
  };
  repository._orderedWorkspaceIds = <String>[
    for (final workspace in initialWorkspaces) workspace.id,
  ];
  repository._systemsById = <String, SavedSystem>{
    for (final system in initialSystems) system.id: system,
  };
  repository._orderedSystemIds = <String>[
    for (final system in initialSystems) system.id,
  ];

  for (final connection in initialConnections) {
    final resolvedSystemProfile = normalizeSystemFingerprintFromHostIdentity(
      systemProfileFromConnectionProfile(connection.profile),
      repository._systemsById.values,
    );
    final resolvedSystemId =
        connection.profile.isRemote &&
            shouldPersistSystem(resolvedSystemProfile, connection.secrets)
        ? matchingSystem(
                repository._systemsById.values,
                profile: resolvedSystemProfile,
                secrets: connection.secrets,
              )?.id ??
              _memoryInsertSystem(
                repository,
                profile: resolvedSystemProfile,
                secrets: connection.secrets,
              )
        : null;
    final workspace = SavedWorkspace(
      id: connection.id,
      profile: workspaceProfileFromConnectionProfile(
        connection.profile,
        systemId: resolvedSystemId,
      ),
    );
    repository._workspacesById[workspace.id] = workspace;
    if (!repository._orderedWorkspaceIds.contains(workspace.id)) {
      repository._orderedWorkspaceIds.add(workspace.id);
    }
  }
}

Future<WorkspaceCatalogState> _memoryLoadWorkspaceCatalog(
  MemoryCodexConnectionRepository repository,
) async {
  return WorkspaceCatalogState(
    orderedWorkspaceIds: List<String>.from(repository._orderedWorkspaceIds),
    workspacesById: <String, SavedWorkspaceSummary>{
      for (final entry in repository._workspacesById.entries)
        entry.key: entry.value.toSummary(),
    },
  );
}

Future<SystemCatalogState> _memoryLoadSystemCatalog(
  MemoryCodexConnectionRepository repository,
) async {
  return SystemCatalogState(
    orderedSystemIds: List<String>.from(repository._orderedSystemIds),
    systemsById: <String, SavedSystemSummary>{
      for (final entry in repository._systemsById.entries)
        entry.key: entry.value.toSummary(),
    },
  );
}

Future<SavedWorkspace> _memoryLoadWorkspace(
  MemoryCodexConnectionRepository repository,
  String workspaceId,
) async {
  final workspace = repository._workspacesById[workspaceId];
  if (workspace == null) {
    throw StateError('Unknown saved workspace: $workspaceId');
  }
  return workspace;
}

Future<SavedSystem> _memoryLoadSystem(
  MemoryCodexConnectionRepository repository,
  String systemId,
) async {
  final system = repository._systemsById[systemId];
  if (system == null) {
    throw StateError('Unknown saved system: $systemId');
  }
  return system;
}

Future<SavedWorkspace> _memoryCreateWorkspace(
  MemoryCodexConnectionRepository repository, {
  required WorkspaceProfile profile,
}) async {
  late SavedWorkspace workspace;
  do {
    workspace = SavedWorkspace(
      id: repository._workspaceIdGenerator(),
      profile: profile,
    );
  } while (repository._workspacesById.containsKey(workspace.id));

  await repository.saveWorkspace(workspace);
  return workspace;
}

Future<SavedSystem> _memoryCreateSystem(
  MemoryCodexConnectionRepository repository, {
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) async {
  late SavedSystem system;
  do {
    system = SavedSystem(
      id: repository._systemIdGenerator(),
      profile: profile,
      secrets: secrets,
    );
  } while (repository._systemsById.containsKey(system.id));

  await repository.saveSystem(system);
  return system;
}

Future<void> _memorySaveWorkspace(
  MemoryCodexConnectionRepository repository,
  SavedWorkspace workspace,
) async {
  final normalizedWorkspace = normalizeWorkspace(workspace);
  final exists = repository._workspacesById.containsKey(normalizedWorkspace.id);
  repository._workspacesById[normalizedWorkspace.id] = normalizedWorkspace;
  if (!exists) {
    repository._orderedWorkspaceIds.add(normalizedWorkspace.id);
  }
}

Future<void> _memorySaveSystem(
  MemoryCodexConnectionRepository repository,
  SavedSystem system,
) async {
  final normalizedSystem = normalizeSystem(system);
  final exists = repository._systemsById.containsKey(normalizedSystem.id);
  repository._systemsById[normalizedSystem.id] = normalizedSystem;
  if (!exists) {
    repository._orderedSystemIds.add(normalizedSystem.id);
  }
}

Future<void> _memoryDeleteWorkspace(
  MemoryCodexConnectionRepository repository,
  String workspaceId,
) async {
  repository._workspacesById.remove(workspaceId);
  repository._orderedWorkspaceIds.remove(workspaceId);
}

Future<void> _memoryDeleteSystem(
  MemoryCodexConnectionRepository repository,
  String systemId,
) async {
  if (workspaceCountForSystem(repository._workspacesById.values, systemId) >
      0) {
    throw StateError(
      'Cannot delete a system that is still used by a workspace.',
    );
  }
  repository._systemsById.remove(systemId);
  repository._orderedSystemIds.remove(systemId);
}

Future<ConnectionCatalogState> _memoryLoadCatalog(
  MemoryCodexConnectionRepository repository,
) async {
  final workspaceCatalog = await repository.loadWorkspaceCatalog();
  final systemCatalog = await repository.loadSystemCatalog();
  return resolvedConnectionCatalogFromWorkspaces(
    workspaceCatalog: workspaceCatalog,
    systemCatalog: systemCatalog,
  );
}

Future<SavedConnection> _memoryLoadConnection(
  MemoryCodexConnectionRepository repository,
  String connectionId,
) async {
  final workspace = await repository.loadWorkspace(connectionId);
  final system = _loadSystemForWorkspace(repository, workspace.profile);
  return resolvedConnectionForWorkspace(
    workspaceId: workspace.id,
    workspace: workspace.profile,
    system: system,
  );
}

Future<SavedConnection> _memoryCreateConnection(
  MemoryCodexConnectionRepository repository, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  late SavedWorkspace workspace;
  do {
    workspace = SavedWorkspace(
      id: repository._workspaceIdGenerator(),
      profile: workspaceProfileFromConnectionProfile(profile, systemId: null),
    );
  } while (repository._workspacesById.containsKey(workspace.id));

  await _memoryPersistResolvedConnection(
    repository,
    SavedConnection(id: workspace.id, profile: profile, secrets: secrets),
  );
  return repository.loadConnection(workspace.id);
}

Future<void> _memorySaveConnection(
  MemoryCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  await _memoryPersistResolvedConnection(repository, connection);
}

Future<void> _memoryDeleteConnection(
  MemoryCodexConnectionRepository repository,
  String connectionId,
) async {
  await repository.deleteWorkspace(connectionId);
}

Future<void> _memoryPersistResolvedConnection(
  MemoryCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  final normalizedConnection = normalizeConnection(connection);
  final existingWorkspace = repository._workspacesById[normalizedConnection.id];
  String? systemId;
  final resolvedSystemProfile = normalizeSystemFingerprintFromHostIdentity(
    systemProfileFromConnectionProfile(normalizedConnection.profile),
    repository._systemsById.values,
  );
  if (normalizedConnection.profile.isRemote &&
      shouldPersistSystem(
        resolvedSystemProfile,
        normalizedConnection.secrets,
      )) {
    final existingSystem = matchingSystem(
      repository._systemsById.values,
      profile: resolvedSystemProfile,
      secrets: normalizedConnection.secrets,
    );
    systemId = existingSystem?.id;
    if (existingSystem != null) {
      final mergedProfile = mergeSystemFingerprint(
        existingSystem.profile,
        resolvedSystemProfile,
      );
      if (mergedProfile != existingSystem.profile) {
        repository._systemsById[existingSystem.id] = existingSystem.copyWith(
          profile: mergedProfile,
        );
      }
    }
    if (systemId == null) {
      final existingSystemId = existingWorkspace?.profile.systemId?.trim();
      if (existingSystemId != null &&
          existingSystemId.isNotEmpty &&
          repository._systemsById.containsKey(existingSystemId)) {
        systemId = existingSystemId;
        await repository.saveSystem(
          SavedSystem(
            id: systemId,
            profile: resolvedSystemProfile,
            secrets: normalizedConnection.secrets,
          ),
        );
      } else {
        systemId = _memoryInsertSystem(
          repository,
          profile: resolvedSystemProfile,
          secrets: normalizedConnection.secrets,
        );
      }
    }
    final fingerprintToShare = resolvedSystemProfile.hostFingerprint.trim();
    if (fingerprintToShare.isNotEmpty) {
      for (final entry in repository._systemsById.entries.toList()) {
        final savedSystem = entry.value;
        if (!sameSystemHostIdentity(
              savedSystem.profile,
              resolvedSystemProfile,
            ) ||
            savedSystem.profile.hostFingerprint.trim() == fingerprintToShare) {
          continue;
        }
        repository._systemsById[entry.key] = savedSystem.copyWith(
          profile: savedSystem.profile.copyWith(
            hostFingerprint: fingerprintToShare,
          ),
        );
      }
    }
  }

  await repository.saveWorkspace(
    SavedWorkspace(
      id: normalizedConnection.id,
      profile: workspaceProfileFromConnectionProfile(
        normalizedConnection.profile,
        systemId: systemId,
      ),
    ),
  );
}

SavedSystem? _loadSystemForWorkspace(
  MemoryCodexConnectionRepository repository,
  WorkspaceProfile workspace,
) {
  final systemId = workspace.systemId?.trim();
  if (systemId == null || systemId.isEmpty) {
    return null;
  }
  return repository._systemsById[systemId];
}

String _memoryInsertSystem(
  MemoryCodexConnectionRepository repository, {
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) {
  late String systemId;
  do {
    systemId = repository._systemIdGenerator();
  } while (repository._systemsById.containsKey(systemId));
  repository._systemsById[systemId] = SavedSystem(
    id: systemId,
    profile: profile,
    secrets: secrets,
  );
  repository._orderedSystemIds.add(systemId);
  return systemId;
}

ConnectionIdGenerator _defaultMemoryConnectionIdGenerator() {
  var nextId = 1;
  return () => 'conn_memory_${nextId++}';
}

SystemIdGenerator _defaultMemorySystemIdGenerator() {
  var nextId = 1;
  return () => 'sys_memory_${nextId++}';
}
