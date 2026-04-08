import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/repository/connection_repository_normalization.dart';

import 'secure_connection_repository_keys.dart';
import 'secure_connection_repository_migration.dart';
import 'secure_connection_repository_ordered_index.dart';
import 'secure_connection_repository_secrets.dart';
import 'secure_connection_repository_state.dart';

Future<ConnectionCatalogState> secureLoadCatalog(
  SecureConnectionRepositoryState state,
) async {
  final workspaceCatalog = await secureLoadWorkspaceCatalog(state);
  final systemCatalog = await secureLoadSystemCatalog(state);
  return resolvedConnectionCatalogFromWorkspaces(
    workspaceCatalog: workspaceCatalog,
    systemCatalog: systemCatalog,
  );
}

Future<WorkspaceCatalogState> secureLoadWorkspaceCatalog(
  SecureConnectionRepositoryState state,
) async {
  await ensureSecureCatalogsReady(state);
  final orderedIds = await loadOrderedIds(
    state.preferences,
    indexKey: workspaceCatalogIndexKey,
    discoveredIds: await discoverStoredIds(
      state.preferences,
      prefix: workspaceProfileKeyPrefix,
      suffix: workspaceProfileKeySuffix,
    ),
  );
  final profiles = await state.preferences.getAll(
    allowList: orderedIds.map(workspaceProfileKeyForWorkspace).toSet(),
  );

  final workspacesById = <String, SavedWorkspaceSummary>{};
  final normalizedOrderedIds = <String>[];
  for (final workspaceId in orderedIds) {
    final rawProfile = profiles[workspaceProfileKeyForWorkspace(workspaceId)];
    if (rawProfile is! String || rawProfile.trim().isEmpty) {
      continue;
    }
    normalizedOrderedIds.add(workspaceId);
    workspacesById[workspaceId] = SavedWorkspaceSummary(
      id: workspaceId,
      profile: WorkspaceProfile.fromJson(
        jsonDecode(rawProfile) as Map<String, dynamic>,
      ),
    );
  }

  if (!listEquals(normalizedOrderedIds, orderedIds)) {
    await persistOrderedIds(
      state.preferences,
      indexKey: workspaceCatalogIndexKey,
      schemaVersion: workspaceCatalogSchemaVersion,
      orderedIds: normalizedOrderedIds,
    );
  }

  return WorkspaceCatalogState(
    orderedWorkspaceIds: normalizedOrderedIds,
    workspacesById: workspacesById,
  );
}

Future<SystemCatalogState> secureLoadSystemCatalog(
  SecureConnectionRepositoryState state,
) async {
  await ensureSecureCatalogsReady(state);
  final orderedIds = await loadOrderedIds(
    state.preferences,
    indexKey: systemCatalogIndexKey,
    discoveredIds: await discoverStoredIds(
      state.preferences,
      prefix: systemProfileKeyPrefix,
      suffix: systemProfileKeySuffix,
    ),
  );
  final profiles = await state.preferences.getAll(
    allowList: orderedIds.map(systemProfileKeyForSystem).toSet(),
  );

  final systemsById = <String, SavedSystemSummary>{};
  final normalizedOrderedIds = <String>[];
  for (final systemId in orderedIds) {
    final rawProfile = profiles[systemProfileKeyForSystem(systemId)];
    if (rawProfile is! String || rawProfile.trim().isEmpty) {
      continue;
    }
    normalizedOrderedIds.add(systemId);
    systemsById[systemId] = SavedSystemSummary(
      id: systemId,
      profile: SystemProfile.fromJson(
        jsonDecode(rawProfile) as Map<String, dynamic>,
      ),
    );
  }

  if (!listEquals(normalizedOrderedIds, orderedIds)) {
    await persistOrderedIds(
      state.preferences,
      indexKey: systemCatalogIndexKey,
      schemaVersion: systemCatalogSchemaVersion,
      orderedIds: normalizedOrderedIds,
    );
  }

  return SystemCatalogState(
    orderedSystemIds: normalizedOrderedIds,
    systemsById: systemsById,
  );
}

Future<SavedWorkspace> secureLoadWorkspace(
  SecureConnectionRepositoryState state,
  String workspaceId,
) async {
  final normalizedWorkspaceId = requireConnectionId(workspaceId);
  final catalog = await secureLoadWorkspaceCatalog(state);
  final summary = catalog.workspaceForId(normalizedWorkspaceId);
  if (summary == null) {
    throw StateError('Unknown saved workspace: $normalizedWorkspaceId');
  }
  return SavedWorkspace(id: summary.id, profile: summary.profile);
}

Future<SavedSystem> secureLoadSystem(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  final normalizedSystemId = requireSystemId(systemId);
  final catalog = await secureLoadSystemCatalog(state);
  final summary = catalog.systemForId(normalizedSystemId);
  if (summary == null) {
    throw StateError('Unknown saved system: $normalizedSystemId');
  }
  return SavedSystem(
    id: summary.id,
    profile: summary.profile,
    secrets: await readSystemSecrets(state, normalizedSystemId),
  );
}

Future<SavedConnection> secureLoadConnection(
  SecureConnectionRepositoryState state,
  String connectionId,
) async {
  final workspace = await secureLoadWorkspace(state, connectionId);
  final system = await secureLoadSystemForWorkspace(state, workspace.profile);
  return resolvedConnectionForWorkspace(
    workspaceId: workspace.id,
    workspace: workspace.profile,
    system: system,
  );
}

Future<List<SavedSystem>> loadOrderedSystems(
  SecureConnectionRepositoryState state,
  List<String> orderedSystemIds,
) async {
  final systems = <SavedSystem>[];
  for (final systemId in orderedSystemIds) {
    try {
      systems.add(await secureLoadSystem(state, systemId));
    } catch (_) {}
  }
  return systems;
}

Future<SavedSystem?> secureLoadSystemForWorkspace(
  SecureConnectionRepositoryState state,
  WorkspaceProfile workspace,
) async {
  final systemId = workspace.systemId?.trim();
  if (systemId == null || systemId.isEmpty) {
    return null;
  }
  try {
    return await secureLoadSystem(state, systemId);
  } catch (_) {
    return null;
  }
}
