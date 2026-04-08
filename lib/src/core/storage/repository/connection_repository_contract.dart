import 'dart:math';

import 'package:pocket_relay/src/core/models/connection_models.dart';

typedef ConnectionIdGenerator = String Function();
typedef SystemIdGenerator = String Function();

abstract interface class CodexConnectionRepository {
  Future<WorkspaceCatalogState> loadWorkspaceCatalog();

  Future<SystemCatalogState> loadSystemCatalog();

  Future<SavedWorkspace> loadWorkspace(String workspaceId);

  Future<SavedSystem> loadSystem(String systemId);

  Future<SavedWorkspace> createWorkspace({required WorkspaceProfile profile});

  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<void> saveWorkspace(SavedWorkspace workspace);

  Future<void> saveSystem(SavedSystem system);

  Future<void> deleteWorkspace(String workspaceId);

  Future<void> deleteSystem(String systemId);

  Future<ConnectionCatalogState> loadCatalog();

  Future<SavedConnection> loadConnection(String connectionId);

  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<void> saveConnection(SavedConnection connection);

  Future<void> deleteConnection(String connectionId);
}

String generateConnectionId() {
  return generateEntityId(prefix: 'conn');
}

String generateSystemId() {
  return generateEntityId(prefix: 'sys');
}

String generateEntityId({required String prefix}) {
  final random = Random.secure();
  final buffer = StringBuffer('${prefix}_');
  buffer.write(DateTime.now().microsecondsSinceEpoch.toRadixString(16));
  buffer.write('_');
  for (var index = 0; index < 8; index += 1) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
