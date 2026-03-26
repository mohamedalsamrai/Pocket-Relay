part of '../connection_workspace_controller.dart';

Future<ConnectionModelCatalog?> _loadWorkspaceConnectionModelCatalog(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  return controller._modelCatalogStore.load(normalizedConnectionId);
}

Future<void> _saveWorkspaceConnectionModelCatalog(
  ConnectionWorkspaceController controller,
  ConnectionModelCatalog catalog,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(
    catalog.connectionId,
  );
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  await controller._modelCatalogStore.save(
    ConnectionModelCatalog(
      connectionId: normalizedConnectionId,
      fetchedAt: catalog.fetchedAt,
      models: catalog.models,
    ),
  );
}

Future<ConnectionModelCatalog?> _loadWorkspaceLastKnownConnectionModelCatalog(
  ConnectionWorkspaceController controller,
) async {
  await controller.initialize();
  return controller._modelCatalogStore.loadLastKnown();
}

Future<void> _saveWorkspaceLastKnownConnectionModelCatalog(
  ConnectionWorkspaceController controller,
  ConnectionModelCatalog catalog,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(
    catalog.connectionId,
  );
  await controller.initialize();
  await controller._modelCatalogStore.saveLastKnown(
    ConnectionModelCatalog(
      connectionId: normalizedConnectionId,
      fetchedAt: catalog.fetchedAt,
      models: catalog.models,
    ),
  );
}
