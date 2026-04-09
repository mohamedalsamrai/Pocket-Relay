import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/repository/connection_repository_normalization.dart';

import 'secure_connection_repository_keys.dart';
import 'secure_connection_repository_ordered_index.dart';
import 'secure_connection_repository_profiles.dart';
import 'secure_connection_repository_secrets.dart';
import 'secure_connection_repository_state.dart';

Future<void> ensureSecureCatalogsReady(SecureConnectionRepositoryState state) {
  return state.normalizedCatalogsReady ??= secureMigrateCatalogsIfNeeded(state);
}

Future<void> secureMigrateCatalogsIfNeeded(
  SecureConnectionRepositoryState state,
) async {
  await state.catalogRecovery.ensurePreferencesReady();
  final legacySingletonResult = await readLegacySingletonConnectionWithStatus(
    state,
  );
  final legacySingletonConnection = legacySingletonResult.connection;

  final existingWorkspaceIds = await discoverStoredIds(
    state.preferences,
    prefix: workspaceProfileKeyPrefix,
    suffix: workspaceProfileKeySuffix,
  );
  final existingSystemIds = await discoverStoredIds(
    state.preferences,
    prefix: systemProfileKeyPrefix,
    suffix: systemProfileKeySuffix,
  );
  final rawWorkspaceIndex = await state.preferences.getString(
    workspaceCatalogIndexKey,
  );
  final rawSystemIndex = await state.preferences.getString(
    systemCatalogIndexKey,
  );

  if (existingWorkspaceIds.isNotEmpty ||
      existingSystemIds.isNotEmpty ||
      (rawWorkspaceIndex?.trim().isNotEmpty ?? false) ||
      (rawSystemIndex?.trim().isNotEmpty ?? false)) {
    _clearDeferredLegacyCatalogSnapshot(state);
    await persistOrderedIds(
      state.preferences,
      indexKey: workspaceCatalogIndexKey,
      schemaVersion: workspaceCatalogSchemaVersion,
      orderedIds: await loadOrderedIds(
        state.preferences,
        indexKey: workspaceCatalogIndexKey,
        discoveredIds: existingWorkspaceIds,
      ),
    );
    await persistOrderedIds(
      state.preferences,
      indexKey: systemCatalogIndexKey,
      schemaVersion: systemCatalogSchemaVersion,
      orderedIds: await loadOrderedIds(
        state.preferences,
        indexKey: systemCatalogIndexKey,
        discoveredIds: existingSystemIds,
      ),
    );
    return;
  }

  final legacyCatalog = await state.catalogRecovery.loadCatalog();
  if (legacySingletonConnection != null &&
      !legacySingletonResult.allowCleanup) {
    state.deferredLegacyCatalogSnapshot =
        await _buildDeferredLegacyCatalogSnapshot(
          state,
          legacyCatalog: legacyCatalog,
          legacySingletonConnection: legacySingletonConnection,
        );
    return;
  }
  if (legacyCatalog == null || legacyCatalog.isEmpty) {
    final seededConnectionId = state.workspaceIdGenerator();
    final seededConnection =
        legacySingletonConnection ??
        SavedConnection(
          id: seededConnectionId,
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        );
    await migrateLegacyConnectionsIntoSplitStorage(
      state,
      legacyConnections: <SavedConnection>[
        seededConnection.copyWith(id: seededConnectionId),
      ],
    );
    _clearDeferredLegacyCatalogSnapshot(state);
    if (legacySingletonConnection != null &&
        legacySingletonResult.allowCleanup) {
      await deleteLegacySingletonStorage(state);
    }
    return;
  }

  final legacyConnections = <SavedConnection>[];
  var pendingSingletonUpgrade = legacySingletonConnection;
  for (final connectionId in legacyCatalog.orderedConnectionIds) {
    final summary = legacyCatalog.connectionForId(connectionId);
    if (summary == null) {
      continue;
    }

    final migratedConnection =
        pendingSingletonUpgrade != null &&
            summary.profile == ConnectionProfile.defaults()
        ? pendingSingletonUpgrade.copyWith(id: connectionId)
        : SavedConnection(
            id: connectionId,
            profile: summary.profile,
            secrets: await readLegacyConnectionSecrets(state, connectionId),
          );
    if (pendingSingletonUpgrade != null &&
        migratedConnection.id == connectionId &&
        migratedConnection.profile == pendingSingletonUpgrade.profile &&
        connectionSecretsEqual(
          migratedConnection.secrets,
          pendingSingletonUpgrade.secrets,
        )) {
      pendingSingletonUpgrade = null;
    }
    legacyConnections.add(migratedConnection);
  }

  await migrateLegacyConnectionsIntoSplitStorage(
    state,
    legacyConnections: legacyConnections,
  );
  _clearDeferredLegacyCatalogSnapshot(state);
  await deleteLegacyConnections(state, legacyCatalog.orderedConnectionIds);
  if (legacySingletonResult.allowCleanup) {
    await deleteLegacySingletonStorage(state);
  }
}

Future<void> migrateLegacyConnectionsIntoSplitStorage(
  SecureConnectionRepositoryState state, {
  required List<SavedConnection> legacyConnections,
}) async {
  final splitCatalogs = _buildSplitCatalogsFromLegacyConnections(
    state,
    legacyConnections: legacyConnections,
  );

  for (final systemId in splitCatalogs.orderedSystemIds) {
    final system = splitCatalogs.systemsById[systemId];
    if (system == null) {
      continue;
    }
    await persistSystemProfile(
      state,
      systemId: systemId,
      profile: system.profile,
    );
    await persistSystemSecrets(state, system);
  }
  for (final workspaceId in splitCatalogs.orderedWorkspaceIds) {
    final workspace = splitCatalogs.workspacesById[workspaceId];
    if (workspace == null) {
      continue;
    }
    await persistWorkspaceProfile(
      state,
      workspaceId: workspaceId,
      profile: workspace.profile,
    );
  }
  await persistOrderedIds(
    state.preferences,
    indexKey: workspaceCatalogIndexKey,
    schemaVersion: workspaceCatalogSchemaVersion,
    orderedIds: splitCatalogs.orderedWorkspaceIds,
  );
  await persistOrderedIds(
    state.preferences,
    indexKey: systemCatalogIndexKey,
    schemaVersion: systemCatalogSchemaVersion,
    orderedIds: splitCatalogs.orderedSystemIds,
  );
}

void _clearDeferredLegacyCatalogSnapshot(
  SecureConnectionRepositoryState state,
) {
  state.deferredLegacyCatalogSnapshot = null;
}

Future<DeferredLegacyCatalogSnapshot> _buildDeferredLegacyCatalogSnapshot(
  SecureConnectionRepositoryState state, {
  required ConnectionCatalogState? legacyCatalog,
  required SavedConnection legacySingletonConnection,
}) async {
  final legacyConnections = await _loadLegacyConnectionsForMigration(
    state,
    legacyCatalog: legacyCatalog,
    legacySingletonConnection: legacySingletonConnection,
  );
  final splitCatalogs = _buildSplitCatalogsFromLegacyConnections(
    state,
    legacyConnections: legacyConnections,
  );
  return (
    workspaceCatalog: WorkspaceCatalogState(
      orderedWorkspaceIds: splitCatalogs.orderedWorkspaceIds,
      workspacesById: <String, SavedWorkspaceSummary>{
        for (final entry in splitCatalogs.workspacesById.entries)
          entry.key: SavedWorkspaceSummary(
            id: entry.value.id,
            profile: entry.value.profile,
          ),
      },
    ),
    systemCatalog: SystemCatalogState(
      orderedSystemIds: splitCatalogs.orderedSystemIds,
      systemsById: <String, SavedSystemSummary>{
        for (final entry in splitCatalogs.systemsById.entries)
          entry.key: SavedSystemSummary(
            id: entry.value.id,
            profile: entry.value.profile,
          ),
      },
    ),
    workspacesById: splitCatalogs.workspacesById,
    systemsById: splitCatalogs.systemsById,
    connectionsById: <String, SavedConnection>{
      for (final workspaceEntry in splitCatalogs.workspacesById.entries)
        workspaceEntry.key: resolvedConnectionForWorkspace(
          workspaceId: workspaceEntry.key,
          workspace: workspaceEntry.value.profile,
          system: workspaceEntry.value.profile.systemId == null
              ? null
              : splitCatalogs.systemsById[workspaceEntry
                    .value
                    .profile
                    .systemId!],
        ),
    },
  );
}

Future<List<SavedConnection>> _loadLegacyConnectionsForMigration(
  SecureConnectionRepositoryState state, {
  required ConnectionCatalogState? legacyCatalog,
  required SavedConnection legacySingletonConnection,
}) async {
  if (legacyCatalog == null || legacyCatalog.isEmpty) {
    final workspaceId = state.workspaceIdGenerator();
    return <SavedConnection>[
      legacySingletonConnection.copyWith(id: workspaceId),
    ];
  }

  final legacyConnections = <SavedConnection>[];
  SavedConnection? pendingSingletonUpgrade = legacySingletonConnection;
  for (final connectionId in legacyCatalog.orderedConnectionIds) {
    final summary = legacyCatalog.connectionForId(connectionId);
    if (summary == null) {
      continue;
    }

    final migratedConnection =
        pendingSingletonUpgrade != null &&
            pendingSingletonUpgrade.profile == ConnectionProfile.defaults()
        ? pendingSingletonUpgrade.copyWith(id: connectionId)
        : SavedConnection(
            id: connectionId,
            profile: summary.profile,
            secrets: await readLegacyConnectionSecrets(state, connectionId),
          );
    if (pendingSingletonUpgrade != null &&
        migratedConnection.id == connectionId &&
        migratedConnection.profile == pendingSingletonUpgrade.profile &&
        connectionSecretsEqual(
          migratedConnection.secrets,
          pendingSingletonUpgrade.secrets,
        )) {
      pendingSingletonUpgrade = null;
    }
    legacyConnections.add(migratedConnection);
  }
  return legacyConnections;
}

({
  Map<String, SavedSystem> systemsById,
  Map<String, SavedWorkspace> workspacesById,
  List<String> orderedSystemIds,
  List<String> orderedWorkspaceIds,
})
_buildSplitCatalogsFromLegacyConnections(
  SecureConnectionRepositoryState state, {
  required List<SavedConnection> legacyConnections,
}) {
  final systemsById = <String, SavedSystem>{};
  final workspacesById = <String, SavedWorkspace>{};
  final orderedSystemIds = <String>[];
  final orderedWorkspaceIds = <String>[];
  for (final legacyConnection in legacyConnections) {
    final normalizedConnection = normalizeConnection(legacyConnection);
    String? systemId;
    final resolvedSystemProfile = normalizeSystemFingerprintFromHostIdentity(
      systemProfileFromConnectionProfile(normalizedConnection.profile),
      systemsById.values,
    );
    if (normalizedConnection.profile.isRemote &&
        shouldPersistSystem(
          resolvedSystemProfile,
          normalizedConnection.secrets,
        )) {
      final existingSystem = matchingSystem(
        systemsById.values,
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
          systemsById[existingSystem.id] = existingSystem.copyWith(
            profile: mergedProfile,
          );
        }
      }
      if (systemId == null) {
        systemId = state.systemIdGenerator();
        final savedSystem = SavedSystem(
          id: systemId,
          profile: resolvedSystemProfile,
          secrets: normalizedConnection.secrets,
        );
        systemsById[systemId] = savedSystem;
        orderedSystemIds.add(systemId);
      }
      final fingerprintToShare = resolvedSystemProfile.hostFingerprint.trim();
      if (fingerprintToShare.isNotEmpty) {
        for (final entry in systemsById.entries.toList()) {
          final savedSystem = entry.value;
          if (!sameSystemHostIdentity(
                savedSystem.profile,
                resolvedSystemProfile,
              ) ||
              savedSystem.profile.hostFingerprint.trim() ==
                  fingerprintToShare) {
            continue;
          }
          systemsById[entry.key] = savedSystem.copyWith(
            profile: savedSystem.profile.copyWith(
              hostFingerprint: fingerprintToShare,
            ),
          );
        }
      }
    }

    workspacesById[normalizedConnection.id] = SavedWorkspace(
      id: normalizedConnection.id,
      profile: workspaceProfileFromConnectionProfile(
        normalizedConnection.profile,
        systemId: systemId,
      ),
    );
    orderedWorkspaceIds.add(normalizedConnection.id);
  }

  return (
    systemsById: systemsById,
    workspacesById: workspacesById,
    orderedSystemIds: orderedSystemIds,
    orderedWorkspaceIds: orderedWorkspaceIds,
  );
}
