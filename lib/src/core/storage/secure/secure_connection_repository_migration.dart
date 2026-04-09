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
  await deleteLegacyConnections(state, legacyCatalog.orderedConnectionIds);
  if (legacySingletonResult.allowCleanup) {
    await deleteLegacySingletonStorage(state);
  }
}

Future<void> migrateLegacyConnectionsIntoSplitStorage(
  SecureConnectionRepositoryState state, {
  required List<SavedConnection> legacyConnections,
}) async {
  final migratedSystemsById = <String, SavedSystem>{};
  final migratedWorkspacesById = <String, SavedWorkspace>{};
  final orderedSystemIds = <String>[];
  final orderedWorkspaceIds = <String>[];
  for (final legacyConnection in legacyConnections) {
    final normalizedConnection = normalizeConnection(legacyConnection);
    String? systemId;
    final resolvedSystemProfile = normalizeSystemFingerprintFromHostIdentity(
      systemProfileFromConnectionProfile(normalizedConnection.profile),
      migratedSystemsById.values,
    );
    if (normalizedConnection.profile.isRemote &&
        shouldPersistSystem(
          resolvedSystemProfile,
          normalizedConnection.secrets,
        )) {
      final existingSystem = matchingSystem(
        migratedSystemsById.values,
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
          migratedSystemsById[existingSystem.id] = existingSystem.copyWith(
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
        migratedSystemsById[systemId] = savedSystem;
        orderedSystemIds.add(systemId);
      }
      final fingerprintToShare = resolvedSystemProfile.hostFingerprint.trim();
      if (fingerprintToShare.isNotEmpty) {
        for (final entry in migratedSystemsById.entries.toList()) {
          final savedSystem = entry.value;
          if (!sameSystemHostIdentity(
                savedSystem.profile,
                resolvedSystemProfile,
              ) ||
              savedSystem.profile.hostFingerprint.trim() ==
                  fingerprintToShare) {
            continue;
          }
          migratedSystemsById[entry.key] = savedSystem.copyWith(
            profile: savedSystem.profile.copyWith(
              hostFingerprint: fingerprintToShare,
            ),
          );
        }
      }
    }

    migratedWorkspacesById[normalizedConnection.id] = SavedWorkspace(
      id: normalizedConnection.id,
      profile: workspaceProfileFromConnectionProfile(
        normalizedConnection.profile,
        systemId: systemId,
      ),
    );
    orderedWorkspaceIds.add(normalizedConnection.id);
  }

  for (final systemId in orderedSystemIds) {
    final system = migratedSystemsById[systemId];
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
  for (final workspaceId in orderedWorkspaceIds) {
    final workspace = migratedWorkspacesById[workspaceId];
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
    orderedIds: orderedWorkspaceIds,
  );
  await persistOrderedIds(
    state.preferences,
    indexKey: systemCatalogIndexKey,
    schemaVersion: systemCatalogSchemaVersion,
    orderedIds: orderedSystemIds,
  );
}
