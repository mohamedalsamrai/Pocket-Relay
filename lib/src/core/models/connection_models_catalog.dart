part of 'connection_models.dart';

class ConnectionCatalogState {
  const ConnectionCatalogState({
    required this.orderedConnectionIds,
    required this.connectionsById,
  });

  const ConnectionCatalogState.empty()
    : orderedConnectionIds = const <String>[],
      connectionsById = const <String, SavedConnectionSummary>{};

  final List<String> orderedConnectionIds;
  final Map<String, SavedConnectionSummary> connectionsById;

  bool get isEmpty => orderedConnectionIds.isEmpty;
  bool get isNotEmpty => orderedConnectionIds.isNotEmpty;
  int get length => orderedConnectionIds.length;

  SavedConnectionSummary? connectionForId(String connectionId) {
    return connectionsById[connectionId];
  }

  List<SavedConnectionSummary> get orderedConnections {
    return <SavedConnectionSummary>[
      for (final connectionId in orderedConnectionIds)
        if (connectionsById[connectionId] != null)
          connectionsById[connectionId]!,
    ];
  }

  ConnectionCatalogState copyWith({
    List<String>? orderedConnectionIds,
    Map<String, SavedConnectionSummary>? connectionsById,
  }) {
    return ConnectionCatalogState(
      orderedConnectionIds: orderedConnectionIds ?? this.orderedConnectionIds,
      connectionsById: connectionsById ?? this.connectionsById,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionCatalogState &&
        listEquals(other.orderedConnectionIds, orderedConnectionIds) &&
        mapEquals(other.connectionsById, connectionsById);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(orderedConnectionIds),
    Object.hashAll(
      connectionsById.entries.map<Object>(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}
