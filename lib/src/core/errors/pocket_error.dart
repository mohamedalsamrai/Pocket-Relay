enum PocketErrorDomain { connectionLifecycle }

final class PocketErrorDefinition {
  const PocketErrorDefinition({
    required this.code,
    required this.domain,
    required this.meaning,
  });

  final String code;
  final PocketErrorDomain domain;
  final String meaning;
}

final class PocketUserFacingError {
  const PocketUserFacingError({
    required this.definition,
    required this.title,
    required this.message,
  });

  final PocketErrorDefinition definition;
  final String title;
  final String message;

  String get inlineMessage {
    final normalizedTitle = title.trim();
    final normalizedMessage = message.trim();
    if (normalizedTitle.isEmpty) {
      return '[${definition.code}] $normalizedMessage';
    }
    if (normalizedMessage.isEmpty) {
      return '[${definition.code}] $normalizedTitle';
    }
    return '[${definition.code}] $normalizedTitle. $normalizedMessage';
  }

  String get bodyWithCode => '[${definition.code}] ${message.trim()}';
}

abstract final class PocketErrorCatalog {
  // Connection lifecycle: open lane (11xx).
  static const PocketErrorDefinition
  connectionOpenRemoteHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1101',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because Pocket Relay could not verify the remote host continuity prerequisites.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1102',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-1103',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because no Pocket Relay server is running for the saved remote connection.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1104',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because the saved remote Pocket Relay server is present but not healthy enough to attach.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteAttachUnavailable = PocketErrorDefinition(
    code: 'PR-CONN-1105',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed after the server reported running because Pocket Relay could not attach the lane to the managed remote session.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1106',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed for an unexpected connection-lifecycle reason outside the known remote continuity states.',
  );
  static const PocketErrorDefinition
  connectionOpenLocalUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1107',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a local lane failed for an unexpected connection-lifecycle reason outside the known local startup states.',
  );

  // Connection lifecycle: start server (12xx).
  static const PocketErrorDefinition
  connectionStartServerHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1201',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the remote Pocket Relay server failed because Pocket Relay could not verify the remote host after the start attempt.',
  );
  static const PocketErrorDefinition
  connectionStartServerContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1202',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the remote Pocket Relay server failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionStartServerStillStopped = PocketErrorDefinition(
    code: 'PR-CONN-1203',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the remote Pocket Relay server failed because the managed owner was still not running after the start attempt.',
  );
  static const PocketErrorDefinition
  connectionStartServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1204',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the remote Pocket Relay server failed because the managed owner appeared but did not become healthy enough to accept connections.',
  );
  static const PocketErrorDefinition
  connectionStartServerUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1205',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the remote Pocket Relay server failed for an unexpected reason outside the known post-start runtime states.',
  );

  // Connection lifecycle: stop server (13xx).
  static const PocketErrorDefinition
  connectionStopServerHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1301',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the remote Pocket Relay server failed because Pocket Relay could not verify the remote host after the stop attempt.',
  );
  static const PocketErrorDefinition
  connectionStopServerContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1302',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the remote Pocket Relay server failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionStopServerStillRunning = PocketErrorDefinition(
    code: 'PR-CONN-1303',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the remote Pocket Relay server failed because the managed owner was still running after the stop attempt.',
  );
  static const PocketErrorDefinition
  connectionStopServerStillUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1304',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the remote Pocket Relay server failed because the managed owner remained present in an unhealthy state after the stop attempt.',
  );
  static const PocketErrorDefinition
  connectionStopServerUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1305',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the remote Pocket Relay server failed for an unexpected reason outside the known post-stop runtime states.',
  );

  // Connection lifecycle: restart server (14xx).
  static const PocketErrorDefinition
  connectionRestartServerHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1401',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the remote Pocket Relay server failed because Pocket Relay could not verify the remote host after the restart attempt.',
  );
  static const PocketErrorDefinition
  connectionRestartServerContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1402',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the remote Pocket Relay server failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionRestartServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-1403',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the remote Pocket Relay server failed because no managed owner was running after the restart attempt.',
  );
  static const PocketErrorDefinition
  connectionRestartServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1404',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the remote Pocket Relay server failed because the managed owner did not become healthy enough to accept connections after the restart attempt.',
  );
  static const PocketErrorDefinition
  connectionRestartServerUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1405',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the remote Pocket Relay server failed for an unexpected reason outside the known post-restart runtime states.',
  );

  // Connection lifecycle: reconnect and live reattach (21xx).
  static const PocketErrorDefinition
  connectionTransportLost = PocketErrorDefinition(
    code: 'PR-CONN-2101',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'The live lane lost its transport connection to Codex and now requires reconnect handling.',
  );
  static const PocketErrorDefinition
  connectionTransportUnavailable = PocketErrorDefinition(
    code: 'PR-CONN-2102',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane transport failed and Pocket Relay could not restore the remote session directly.',
  );
  static const PocketErrorDefinition
  connectionReconnectContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-2103',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because the remote host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionReconnectHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-2104',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because Pocket Relay could not verify the remote host continuity prerequisites.',
  );
  static const PocketErrorDefinition
  connectionReconnectServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-2105',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because no managed Pocket Relay server was running for the saved remote connection.',
  );
  static const PocketErrorDefinition
  connectionReconnectServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-2106',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because the managed remote Pocket Relay server was present but unhealthy.',
  );

  // Connection lifecycle: conversation history (31xx).
  static const PocketErrorDefinition
  connectionHistoryLoadFailed = PocketErrorDefinition(
    code: 'PR-CONN-3101',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history from Codex failed for a generic connection-lifecycle reason.',
  );
  static const PocketErrorDefinition
  connectionHistoryHostKeyUnpinned = PocketErrorDefinition(
    code: 'PR-CONN-3102',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because the remote host fingerprint is not pinned in the saved connection profile.',
  );
  static const PocketErrorDefinition
  connectionHistoryServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-3103',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because no managed Pocket Relay server was running for the saved remote connection.',
  );
  static const PocketErrorDefinition
  connectionHistoryServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-3104',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because the managed remote Pocket Relay server was present but unhealthy.',
  );
  static const PocketErrorDefinition
  connectionHistorySessionUnavailable = PocketErrorDefinition(
    code: 'PR-CONN-3105',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because Pocket Relay could not attach to the managed remote session even though the owner reported running.',
  );

  static const List<PocketErrorDefinition> connectionLifecycleDefinitions =
      <PocketErrorDefinition>[
        connectionOpenRemoteHostProbeFailed,
        connectionOpenRemoteContinuityUnsupported,
        connectionOpenRemoteServerStopped,
        connectionOpenRemoteServerUnhealthy,
        connectionOpenRemoteAttachUnavailable,
        connectionOpenRemoteUnexpectedFailure,
        connectionOpenLocalUnexpectedFailure,
        connectionStartServerHostProbeFailed,
        connectionStartServerContinuityUnsupported,
        connectionStartServerStillStopped,
        connectionStartServerUnhealthy,
        connectionStartServerUnexpectedFailure,
        connectionStopServerHostProbeFailed,
        connectionStopServerContinuityUnsupported,
        connectionStopServerStillRunning,
        connectionStopServerStillUnhealthy,
        connectionStopServerUnexpectedFailure,
        connectionRestartServerHostProbeFailed,
        connectionRestartServerContinuityUnsupported,
        connectionRestartServerStopped,
        connectionRestartServerUnhealthy,
        connectionRestartServerUnexpectedFailure,
        connectionTransportLost,
        connectionTransportUnavailable,
        connectionReconnectContinuityUnsupported,
        connectionReconnectHostProbeFailed,
        connectionReconnectServerStopped,
        connectionReconnectServerUnhealthy,
        connectionHistoryLoadFailed,
        connectionHistoryHostKeyUnpinned,
        connectionHistoryServerStopped,
        connectionHistoryServerUnhealthy,
        connectionHistorySessionUnavailable,
      ];

  static const List<PocketErrorDefinition> allDefinitions =
      connectionLifecycleDefinitions;

  static PocketErrorDefinition? lookup(String code) {
    for (final definition in allDefinitions) {
      if (definition.code == code) {
        return definition;
      }
    }
    return null;
  }
}
