import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/persisted_json.dart';
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
      await state.preferences.remove(
        workspaceProfileKeyForWorkspace(workspaceId),
      );
      continue;
    }
    final decodedProfile = decodePersistedJsonRecord<WorkspaceProfile>(
      rawProfile,
      subject: 'saved workspace profile',
      decode: (json) => WorkspaceProfile.fromJson(json),
    );
    if (decodedProfile.issue != null) {
      await state.preferences.remove(
        workspaceProfileKeyForWorkspace(workspaceId),
      );
      continue;
    }
    workspacesById[workspaceId] = SavedWorkspaceSummary(
      id: workspaceId,
      profile: decodedProfile.value!,
    );
    normalizedOrderedIds.add(workspaceId);
  }

  if (!listEquals(normalizedOrderedIds, orderedIds)) {
    await persistOrderedIds(
      state.preferences,
      indexKey: workspaceCatalogIndexKey,
      schemaVersion: workspaceCatalogSchemaVersion,
      orderedIds: normalizedOrderedIds,
    );
  }

  final deferredLegacyCatalog = state.deferredLegacyCatalogSnapshot;
  if (normalizedOrderedIds.isEmpty &&
      deferredLegacyCatalog?.workspaceCatalog.orderedWorkspaceIds.isNotEmpty ==
          true) {
    return deferredLegacyCatalog!.workspaceCatalog;
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
      await state.preferences.remove(systemProfileKeyForSystem(systemId));
      await deleteSystemSecrets(state, systemId);
      continue;
    }
    final decodedProfile = decodePersistedJsonRecord<SystemProfile>(
      rawProfile,
      subject: 'saved system profile',
      decode: (json) => SystemProfile.fromJson(json),
    );
    if (decodedProfile.issue != null) {
      await state.preferences.remove(systemProfileKeyForSystem(systemId));
      await deleteSystemSecrets(state, systemId);
      continue;
    }
    systemsById[systemId] = SavedSystemSummary(
      id: systemId,
      profile: decodedProfile.value!,
    );
    normalizedOrderedIds.add(systemId);
  }

  if (!listEquals(normalizedOrderedIds, orderedIds)) {
    await persistOrderedIds(
      state.preferences,
      indexKey: systemCatalogIndexKey,
      schemaVersion: systemCatalogSchemaVersion,
      orderedIds: normalizedOrderedIds,
    );
  }

  final deferredLegacyCatalog = state.deferredLegacyCatalogSnapshot;
  if (normalizedOrderedIds.isEmpty &&
      deferredLegacyCatalog?.systemCatalog.orderedSystemIds.isNotEmpty ==
          true) {
    return deferredLegacyCatalog!.systemCatalog;
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
  if (summary != null) {
    return SavedWorkspace(id: summary.id, profile: summary.profile);
  }
  final deferredLegacyCatalog = state.deferredLegacyCatalogSnapshot;
  final deferredWorkspace =
      deferredLegacyCatalog?.workspacesById[normalizedWorkspaceId];
  if (deferredWorkspace != null) {
    return deferredWorkspace;
  }
  throw StateError('Unknown saved workspace: $normalizedWorkspaceId');
}

Future<SavedSystem> secureLoadSystem(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  final normalizedSystemId = requireSystemId(systemId);
  final catalog = await secureLoadSystemCatalog(state);
  final deferredLegacyCatalog = state.deferredLegacyCatalogSnapshot;
  final deferredSystem = deferredLegacyCatalog?.systemsById[normalizedSystemId];
  final summary = catalog.systemForId(normalizedSystemId);
  if (summary != null) {
    if (deferredSystem != null &&
        identical(catalog, deferredLegacyCatalog?.systemCatalog)) {
      return deferredSystem;
    }
    return SavedSystem(
      id: summary.id,
      profile: summary.profile,
      secrets: await readSystemSecrets(state, normalizedSystemId),
    );
  }
  if (deferredSystem != null) {
    return deferredSystem;
  }
  throw StateError('Unknown saved system: $normalizedSystemId');
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
