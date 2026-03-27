part of 'workspace_saved_connections_content.dart';

extension on _ConnectionWorkspaceSavedConnectionsContentState {
  Widget _buildMaterialContent(
    BuildContext context, {
    required List<ConnectionLifecycleSectionPresentation> sections,
  }) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          ConnectionWorkspaceCopy.workspaceTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('add_connection'),
            onPressed: _isCreatingConnection ? null : _createConnection,
            icon: const Icon(Icons.add),
            label: Text(
              _isCreatingConnection
                  ? ConnectionWorkspaceCopy.addConnectionProgress
                  : ConnectionWorkspaceCopy.addConnectionAction,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (sections.isEmpty)
          const _SavedConnectionsEmptyState()
        else
          ...sections.indexed.map((entry) {
            final index = entry.$1;
            final section = entry.$2;
            return Padding(
              padding: EdgeInsets.only(bottom: index == sections.length - 1 ? 0 : 20),
              child: ConnectionLifecycleSection(
                sectionId: section.id,
                title: section.title,
                count: section.rows.length,
                children: [
                  ...section.rows.indexed.map((rowEntry) {
                    final rowIndex = rowEntry.$1;
                    final row = rowEntry.$2;
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: rowIndex == section.rows.length - 1 ? 0 : 12,
                      ),
                      child: ConnectionLifecycleRow(
                        rowKey: ValueKey<String>(
                          'saved_connection_${row.connection.id}',
                        ),
                        title: row.connection.profile.label,
                        subtitle: row.subtitle,
                        facts: row.facts,
                        primaryAction: _primaryActionForRow(row),
                        secondaryActions: _secondaryActionsForRow(row),
                        detailActions: _detailActionsForRow(row),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),
      ],
    );
  }

  ConnectionLifecycleButtonAction? _primaryActionForRow(
    ConnectionLifecyclePresentation row,
  ) {
    final connectionId = row.connection.id;
    final isBusy = _isRowBusy(connectionId);
    return switch (row.primaryActionId) {
      ConnectionLifecyclePrimaryActionId.openLane ||
      ConnectionLifecyclePrimaryActionId.goToLane =>
        ConnectionLifecycleButtonAction(
          key: ValueKey<String>('open_connection_$connectionId'),
          label: _instantiatingConnectionIds.contains(connectionId)
              ? ConnectionWorkspaceCopy.openingLaneAction
              : row.isLive
              ? ConnectionWorkspaceCopy.goToLaneAction
              : ConnectionWorkspaceCopy.openLaneAction,
          onPressed: isBusy ? null : () => _openConnection(row.connection),
        ),
      ConnectionLifecyclePrimaryActionId.reconnect =>
        ConnectionLifecycleButtonAction(
          key: ValueKey<String>('reconnect_connection_$connectionId'),
          label: _reconnectingConnectionIds.contains(connectionId)
              ? ConnectionWorkspaceCopy.reconnectProgressFor(
                  row.reconnectRequirement!,
                )
              : ConnectionWorkspaceCopy.reconnectActionFor(
                  row.reconnectRequirement!,
                ),
          onPressed: isBusy ? null : () => _reconnectConnection(connectionId),
        ),
      null => null,
    };
  }

  List<ConnectionLifecycleButtonAction> _secondaryActionsForRow(
    ConnectionLifecyclePresentation row,
  ) {
    final connectionId = row.connection.id;
    final isBusy = _isRowBusy(connectionId);
    return <ConnectionLifecycleButtonAction>[
      for (final actionId in row.secondaryActionIds)
        switch (actionId) {
          ConnectionLifecycleSecondaryActionId.disconnect =>
            ConnectionLifecycleButtonAction(
              key: ValueKey<String>('disconnect_$connectionId'),
              label: _disconnectingConnectionIds.contains(connectionId)
                  ? ConnectionWorkspaceCopy.disconnectProgress
                  : ConnectionWorkspaceCopy.disconnectAction,
              onPressed: isBusy ? null : () => _disconnectConnection(connectionId),
            ),
          ConnectionLifecycleSecondaryActionId.edit =>
            ConnectionLifecycleButtonAction(
              key: ValueKey<String>('edit_$connectionId'),
              label: _editingConnectionIds.contains(connectionId)
                  ? ConnectionWorkspaceCopy.saveProgress
                  : ConnectionWorkspaceCopy.editAction,
              onPressed: isBusy ? null : () => _editConnection(row.connection),
            ),
          ConnectionLifecycleSecondaryActionId.closeLane =>
            ConnectionLifecycleButtonAction(
              key: ValueKey<String>('close_lane_$connectionId'),
              label: ConnectionWorkspaceCopy.closeLaneAction,
              onPressed: isBusy
                  ? null
                  : () => widget.workspaceController.terminateConnection(
                      connectionId,
                    ),
            ),
          ConnectionLifecycleSecondaryActionId.delete =>
            ConnectionLifecycleButtonAction(
              key: ValueKey<String>('delete_$connectionId'),
              label: _deletingConnectionIds.contains(connectionId)
                  ? ConnectionWorkspaceCopy.deleteProgress
                  : ConnectionWorkspaceCopy.deleteAction,
              onPressed: isBusy ? null : () => _deleteConnection(connectionId),
              isDestructive: true,
            ),
          _ => const ConnectionLifecycleButtonAction(
              key: ValueKey<String>('unsupported_action'),
              label: '',
              onPressed: null,
            ),
        },
    ].where((action) => action.label.isNotEmpty).toList();
  }

  List<ConnectionLifecycleButtonAction> _detailActionsForRow(
    ConnectionLifecyclePresentation row,
  ) {
    final connectionId = row.connection.id;
    final isBusy = _isRowBusy(connectionId);
    return <ConnectionLifecycleButtonAction>[
      for (final actionId in row.detailActionIds)
        switch (actionId) {
          ConnectionLifecycleSecondaryActionId.checkHost =>
            ConnectionLifecycleButtonAction(
              key: ValueKey<String>('check_host_$connectionId'),
              label: _checkingHostConnectionIds.contains(connectionId)
                  ? ConnectionWorkspaceCopy.checkHostProgress
                  : ConnectionWorkspaceCopy.checkHostAction,
              onPressed: isBusy ? null : () => _checkHost(connectionId),
            ),
          ConnectionLifecycleSecondaryActionId.restartServer =>
            ConnectionLifecycleButtonAction(
              key: ValueKey<String>(
                'saved_connection_remote_server_restart_$connectionId',
              ),
              label:
                  _activeRemoteServerActionsByConnectionId[connectionId] ==
                      ConnectionSettingsRemoteServerActionId.restart
                  ? ConnectionWorkspaceCopy.remoteServerActionProgressLabel(
                      ConnectionSettingsRemoteServerActionId.restart,
                    )
                  : ConnectionWorkspaceCopy.remoteServerActionLabel(
                      ConnectionSettingsRemoteServerActionId.restart,
                    ),
              onPressed: isBusy
                  ? null
                  : () => _runRemoteServerAction(
                      connectionId,
                      ConnectionSettingsRemoteServerActionId.restart,
                    ),
            ),
          ConnectionLifecycleSecondaryActionId.stopServer =>
            ConnectionLifecycleButtonAction(
              key: ValueKey<String>(
                'saved_connection_remote_server_stop_$connectionId',
              ),
              label:
                  _activeRemoteServerActionsByConnectionId[connectionId] ==
                      ConnectionSettingsRemoteServerActionId.stop
                  ? ConnectionWorkspaceCopy.remoteServerActionProgressLabel(
                      ConnectionSettingsRemoteServerActionId.stop,
                    )
                  : ConnectionWorkspaceCopy.remoteServerActionLabel(
                      ConnectionSettingsRemoteServerActionId.stop,
                    ),
              onPressed: isBusy
                  ? null
                  : () => _runRemoteServerAction(
                      connectionId,
                      ConnectionSettingsRemoteServerActionId.stop,
                    ),
            ),
          _ => const ConnectionLifecycleButtonAction(
              key: ValueKey<String>('unsupported_detail_action'),
              label: '',
              onPressed: null,
            ),
        },
    ].where((action) => action.label.isNotEmpty).toList();
  }

  bool _isRowBusy(String connectionId) {
    return _instantiatingConnectionIds.contains(connectionId) ||
        _reconnectingConnectionIds.contains(connectionId) ||
        _editingConnectionIds.contains(connectionId) ||
        _deletingConnectionIds.contains(connectionId) ||
        _disconnectingConnectionIds.contains(connectionId) ||
        _checkingHostConnectionIds.contains(connectionId) ||
        _activeRemoteServerActionsByConnectionId.containsKey(connectionId);
  }
}
