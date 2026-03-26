part of 'codex_connection_repository.dart';

MemoryCodexConnectionRepository _memoryRepositorySingle({
  required SavedProfile savedProfile,
  required String connectionId,
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

Future<ConnectionCatalogState> _memoryLoadCatalog(
  MemoryCodexConnectionRepository repository,
) async {
  _memorySynchronizeSharedHostFingerprints(repository);
  return ConnectionCatalogState(
    orderedConnectionIds: List<String>.from(repository._orderedConnectionIds),
    connectionsById: <String, SavedConnectionSummary>{
      for (final entry in repository._connectionsById.entries)
        entry.key: entry.value.toSummary(),
    },
  );
}

Future<SavedConnection> _memoryLoadConnection(
  MemoryCodexConnectionRepository repository,
  String connectionId,
) async {
  _memorySynchronizeSharedHostFingerprints(repository);
  final connection = repository._connectionsById[connectionId];
  if (connection == null) {
    throw StateError('Unknown saved connection: $connectionId');
  }
  return connection;
}

Future<SavedConnection> _memoryCreateConnection(
  MemoryCodexConnectionRepository repository, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  late SavedConnection connection;
  do {
    connection = SavedConnection(
      id: repository._connectionIdGenerator(),
      profile: profile,
      secrets: secrets,
    );
  } while (repository._connectionsById.containsKey(connection.id));

  await repository.saveConnection(connection);
  return connection;
}

Future<void> _memorySaveConnection(
  MemoryCodexConnectionRepository repository,
  SavedConnection connection,
) async {
  final normalizedConnection = _normalizeConnection(connection);
  final exists = repository._connectionsById.containsKey(
    normalizedConnection.id,
  );
  repository._connectionsById[normalizedConnection.id] = normalizedConnection;
  if (!exists) {
    repository._orderedConnectionIds.add(normalizedConnection.id);
  }
  _memorySynchronizeSharedHostFingerprints(
    repository,
    preferredConnectionId: normalizedConnection.id,
    overwriteExistingFingerprints: true,
  );
}

Future<void> _memoryDeleteConnection(
  MemoryCodexConnectionRepository repository,
  String connectionId,
) async {
  repository._connectionsById.remove(connectionId);
  repository._orderedConnectionIds.remove(connectionId);
}

void _memorySynchronizeSharedHostFingerprints(
  MemoryCodexConnectionRepository repository, {
  String? preferredConnectionId,
  bool overwriteExistingFingerprints = false,
}) {
  final normalizedProfilesByConnectionId =
      _normalizeProfilesWithSharedHostFingerprints(
        orderedConnectionIds: repository._orderedConnectionIds,
        profilesByConnectionId: <String, ConnectionProfile>{
          for (final entry in repository._connectionsById.entries)
            entry.key: entry.value.profile,
        },
        preferredConnectionId: preferredConnectionId,
        overwriteExistingFingerprints: overwriteExistingFingerprints,
      );

  repository._connectionsById.updateAll((connectionId, connection) {
    final normalizedProfile = normalizedProfilesByConnectionId[connectionId];
    if (normalizedProfile == null || normalizedProfile == connection.profile) {
      return connection;
    }

    return connection.copyWith(profile: normalizedProfile);
  });
}
