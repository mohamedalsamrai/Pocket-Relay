part of 'workspace_desktop_shell.dart';

extension on _MaterialDesktopSidebar {
  List<ConnectionLifecycleSectionPresentation> _lifecycleSections() {
    return connectionLifecycleSectionsFromState(
      state,
      isTransportConnected: _isTransportConnected,
    );
  }

  bool _isTransportConnected(String connectionId) {
    return workspaceController
            .bindingForConnectionId(connectionId)
            ?.agentAdapterClient
            .isConnected ==
        true;
  }

  List<ConnectionLifecycleFact> _sidebarFactsForRow(
    ConnectionLifecyclePresentation row,
  ) {
    final laneFact = row.facts.firstWhereOrNull(
      (fact) =>
          fact.label.startsWith('${ConnectionWorkspaceCopy.laneFactLabel}:'),
    );
    final settingsFact = row.facts.firstWhereOrNull(
      (fact) => fact.label.startsWith(
        '${ConnectionWorkspaceCopy.settingsFactLabel}:',
      ),
    );
    final transportFact = row.facts.firstWhereOrNull(
      (fact) => fact.label.startsWith(
        '${ConnectionWorkspaceCopy.transportFactLabel}:',
      ),
    );
    final serverFact = row.facts.firstWhereOrNull(
      (fact) =>
          fact.label.startsWith('${ConnectionWorkspaceCopy.serverFactLabel}:'),
    );
    final configurationFact = row.facts.firstWhereOrNull(
      (fact) =>
          fact.label ==
          ConnectionWorkspaceCopy.laneConfigurationIncompleteStatus,
    );

    final secondaryFact =
        configurationFact ??
        settingsFact ??
        (row.connection.profile.isRemote &&
                (row.transportRecoveryPhase != null ||
                    row.liveReattachPhase != null ||
                    !row.isTransportConnected)
            ? transportFact
            : null) ??
        (row.connection.profile.isRemote &&
                row.remoteRuntime?.server.status !=
                    ConnectionRemoteServerStatus.running
            ? serverFact
            : null);

    return <ConnectionLifecycleFact>[
      if (laneFact != null) laneFact,
      if (secondaryFact != null && secondaryFact != laneFact) secondaryFact,
    ];
  }
}
