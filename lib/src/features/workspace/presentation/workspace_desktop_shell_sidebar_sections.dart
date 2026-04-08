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
    ConnectionLifecycleFact? factMatching(
      bool Function(ConnectionLifecycleFact) test,
    ) {
      for (final fact in row.facts) {
        if (test(fact)) {
          return fact;
        }
      }
      return null;
    }

    final laneFact = factMatching(
      (fact) =>
          fact.label.startsWith('${ConnectionWorkspaceCopy.laneFactLabel}:'),
    );
    final settingsFact = factMatching(
      (fact) => fact.label.startsWith(
        '${ConnectionWorkspaceCopy.settingsFactLabel}:',
      ),
    );
    final transportFact = factMatching(
      (fact) => fact.label.startsWith(
        '${ConnectionWorkspaceCopy.transportFactLabel}:',
      ),
    );
    final serverFact = factMatching(
      (fact) =>
          fact.label.startsWith('${ConnectionWorkspaceCopy.serverFactLabel}:'),
    );
    final configurationFact = factMatching(
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
      ...?(laneFact == null ? null : <ConnectionLifecycleFact>[laneFact]),
      ...?(secondaryFact == null || secondaryFact == laneFact
          ? null
          : <ConnectionLifecycleFact>[secondaryFact]),
    ];
  }
}
