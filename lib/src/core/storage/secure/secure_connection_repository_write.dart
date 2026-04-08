import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/repository/connection_repository_normalization.dart';

import 'secure_connection_repository_keys.dart';
import 'secure_connection_repository_migration.dart';
import 'secure_connection_repository_ordered_index.dart';
import 'secure_connection_repository_profiles.dart';
import 'secure_connection_repository_read.dart';
import 'secure_connection_repository_secrets.dart';
import 'secure_connection_repository_state.dart';

Future<SavedWorkspace> secureCreateWorkspace(
  SecureConnectionRepositoryState state, {
  required WorkspaceProfile profile,
}) async {
  final catalog = await secureLoadWorkspaceCatalog(state);
  late SavedWorkspace workspace;
  do {
    workspace = SavedWorkspace(
      id: state.workspaceIdGenerator(),
      profile: profile,
    );
  } while (catalog.workspaceForId(workspace.id) != null);

  await secureSaveWorkspace(state, workspace);
  return workspace;
}

Future<SavedSystem> secureCreateSystem(
  SecureConnectionRepositoryState state, {
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final catalog = await secureLoadSystemCatalog(state);
  late SavedSystem system;
  do {
    system = SavedSystem(
      id: state.systemIdGenerator(),
      profile: profile,
      secrets: secrets,
    );
  } while (catalog.systemForId(system.id) != null);

  await secureSaveSystem(state, system);
  return system;
}

Future<SavedConnection> secureCreateConnection(
  SecureConnectionRepositoryState state, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final workspace = await secureCreateWorkspace(
    state,
    profile: workspaceProfileFromConnectionProfile(profile, systemId: null),
  );
  await securePersistResolvedConnection(
    state,
    SavedConnection(id: workspace.id, profile: profile, secrets: secrets),
  );
  return secureLoadConnection(state, workspace.id);
}

Future<void> secureSaveWorkspace(
  SecureConnectionRepositoryState state,
  SavedWorkspace workspace,
) async {
  await ensureSecureCatalogsReady(state);
  final normalizedWorkspace = normalizeWorkspace(workspace);
  final catalog = await secureLoadWorkspaceCatalog(state);
  final exists = catalog.workspaceForId(normalizedWorkspace.id) != null;
  final orderedWorkspaceIds = exists
      ? catalog.orderedWorkspaceIds
      : <String>[...catalog.orderedWorkspaceIds, normalizedWorkspace.id];

  await persistWorkspaceProfile(
    state,
    workspaceId: normalizedWorkspace.id,
    profile: normalizedWorkspace.profile,
  );
  await persistOrderedIds(
    state.preferences,
    indexKey: workspaceCatalogIndexKey,
    schemaVersion: workspaceCatalogSchemaVersion,
    orderedIds: orderedWorkspaceIds,
  );
}

Future<void> secureSaveSystem(
  SecureConnectionRepositoryState state,
  SavedSystem system,
) async {
  await ensureSecureCatalogsReady(state);
  final normalizedSystem = normalizeSystem(system);
  final catalog = await secureLoadSystemCatalog(state);
  final exists = catalog.systemForId(normalizedSystem.id) != null;
  final orderedSystemIds = exists
      ? catalog.orderedSystemIds
      : <String>[...catalog.orderedSystemIds, normalizedSystem.id];

  await persistSystemProfile(
    state,
    systemId: normalizedSystem.id,
    profile: normalizedSystem.profile,
  );
  await persistSystemSecrets(state, normalizedSystem);
  await persistOrderedIds(
    state.preferences,
    indexKey: systemCatalogIndexKey,
    schemaVersion: systemCatalogSchemaVersion,
    orderedIds: orderedSystemIds,
  );
}

Future<void> secureSaveConnection(
  SecureConnectionRepositoryState state,
  SavedConnection connection,
) async {
  await securePersistResolvedConnection(state, connection);
}

Future<void> secureDeleteWorkspace(
  SecureConnectionRepositoryState state,
  String workspaceId,
) async {
  await ensureSecureCatalogsReady(state);
  final normalizedWorkspaceId = requireConnectionId(workspaceId);
  final catalog = await secureLoadWorkspaceCatalog(state);
  if (catalog.workspaceForId(normalizedWorkspaceId) == null) {
    return;
  }

  final nextOrderedWorkspaceIds = catalog.orderedWorkspaceIds
      .where((id) => id != normalizedWorkspaceId)
      .toList(growable: false);
  await state.preferences.remove(
    workspaceProfileKeyForWorkspace(normalizedWorkspaceId),
  );
  await persistOrderedIds(
    state.preferences,
    indexKey: workspaceCatalogIndexKey,
    schemaVersion: workspaceCatalogSchemaVersion,
    orderedIds: nextOrderedWorkspaceIds,
  );
}

Future<void> secureDeleteSystem(
  SecureConnectionRepositoryState state,
  String systemId,
) async {
  await ensureSecureCatalogsReady(state);
  final normalizedSystemId = requireSystemId(systemId);
  final systemCatalog = await secureLoadSystemCatalog(state);
  if (systemCatalog.systemForId(normalizedSystemId) == null) {
    return;
  }

  final workspaceCatalog = await secureLoadWorkspaceCatalog(state);
  if (workspaceCountForSystem(
        workspaceCatalog.orderedWorkspaces.map(
          (summary) => SavedWorkspace(id: summary.id, profile: summary.profile),
        ),
        normalizedSystemId,
      ) >
      0) {
    throw StateError(
      'Cannot delete a system that is still used by a workspace.',
    );
  }

  final nextOrderedSystemIds = systemCatalog.orderedSystemIds
      .where((id) => id != normalizedSystemId)
      .toList(growable: false);
  await state.preferences.remove(systemProfileKeyForSystem(normalizedSystemId));
  await deleteSystemSecrets(state, normalizedSystemId);
  await persistOrderedIds(
    state.preferences,
    indexKey: systemCatalogIndexKey,
    schemaVersion: systemCatalogSchemaVersion,
    orderedIds: nextOrderedSystemIds,
  );
}

Future<void> secureDeleteConnection(
  SecureConnectionRepositoryState state,
  String connectionId,
) async {
  await secureDeleteWorkspace(state, connectionId);
  await deleteLegacyConnectionNamespace(state, connectionId);
}

Future<void> securePersistResolvedConnection(
  SecureConnectionRepositoryState state,
  SavedConnection connection,
) async {
  final normalizedConnection = normalizeConnection(connection);
  SavedWorkspace? existingWorkspace;
  try {
    existingWorkspace = await secureLoadWorkspace(
      state,
      normalizedConnection.id,
    );
  } catch (_) {}

  String? systemId;
  final systemCatalog = await secureLoadSystemCatalog(state);
  final orderedSystems = await loadOrderedSystems(
    state,
    systemCatalog.orderedSystemIds,
  );
  final resolvedSystemProfile = normalizeSystemFingerprintFromHostIdentity(
    systemProfileFromConnectionProfile(normalizedConnection.profile),
    orderedSystems,
  );
  if (normalizedConnection.profile.isRemote &&
      shouldPersistSystem(
        resolvedSystemProfile,
        normalizedConnection.secrets,
      )) {
    final existingSystem = matchingSystem(
      orderedSystems,
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
        await secureSaveSystem(
          state,
          existingSystem.copyWith(profile: mergedProfile),
        );
      }
    }
    if (systemId == null) {
      final currentSystemId = existingWorkspace?.profile.systemId?.trim();
      if (currentSystemId != null && currentSystemId.isNotEmpty) {
        systemId = currentSystemId;
        await secureSaveSystem(
          state,
          SavedSystem(
            id: systemId,
            profile: resolvedSystemProfile,
            secrets: normalizedConnection.secrets,
          ),
        );
      } else {
        final system = await secureCreateSystem(
          state,
          profile: resolvedSystemProfile,
          secrets: normalizedConnection.secrets,
        );
        systemId = system.id;
      }
    }
    final fingerprintToShare = resolvedSystemProfile.hostFingerprint.trim();
    if (fingerprintToShare.isNotEmpty) {
      for (final savedSystem in orderedSystems) {
        if (!sameSystemHostIdentity(
              savedSystem.profile,
              resolvedSystemProfile,
            ) ||
            savedSystem.profile.hostFingerprint.trim() == fingerprintToShare) {
          continue;
        }
        await secureSaveSystem(
          state,
          savedSystem.copyWith(
            profile: savedSystem.profile.copyWith(
              hostFingerprint: fingerprintToShare,
            ),
          ),
        );
      }
    }
  }

  await secureSaveWorkspace(
    state,
    SavedWorkspace(
      id: normalizedConnection.id,
      profile: workspaceProfileFromConnectionProfile(
        normalizedConnection.profile,
        systemId: systemId,
      ),
    ),
  );
}
