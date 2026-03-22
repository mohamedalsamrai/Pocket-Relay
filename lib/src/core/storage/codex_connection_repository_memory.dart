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
  final exists = repository._connectionsById.containsKey(connection.id);
  repository._connectionsById[connection.id] = connection;
  if (!exists) {
    repository._orderedConnectionIds.add(connection.id);
  }
}

Future<void> _memoryDeleteConnection(
  MemoryCodexConnectionRepository repository,
  String connectionId,
) async {
  repository._connectionsById.remove(connectionId);
  repository._orderedConnectionIds.remove(connectionId);
}
