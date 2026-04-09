part of '../connection_workspace_controller.dart';

Future<void> _handleWorkspaceAppLifecycleState(
  ConnectionWorkspaceController controller,
  AppLifecycleState state,
) async {
  switch (state) {
    case AppLifecycleState.inactive:
      final selectedConnectionId = controller._state.selectedConnectionId;
      final backgroundedAt = controller._now();
      if (selectedConnectionId != null &&
          controller._state.isConnectionLive(selectedConnectionId)) {
        controller._recordLifecycleBackgroundSnapshot(
          selectedConnectionId,
          occurredAt: backgroundedAt,
          lifecycleState: ConnectionWorkspaceBackgroundLifecycleState.inactive,
        );
      }
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: backgroundedAt,
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.inactive,
      );
      return;
    case AppLifecycleState.hidden:
      final hiddenConnectionId = controller._state.selectedConnectionId;
      final hiddenAt = controller._now();
      if (hiddenConnectionId != null &&
          controller._state.isConnectionLive(hiddenConnectionId)) {
        controller._recordLifecycleBackgroundSnapshot(
          hiddenConnectionId,
          occurredAt: hiddenAt,
          lifecycleState: ConnectionWorkspaceBackgroundLifecycleState.hidden,
        );
      }
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: hiddenAt,
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.hidden,
      );
      return;
    case AppLifecycleState.paused:
      final pausedConnectionId = controller._state.selectedConnectionId;
      final pausedAt = controller._now();
      if (pausedConnectionId != null &&
          controller._state.isConnectionLive(pausedConnectionId)) {
        controller._recordLifecycleBackgroundSnapshot(
          pausedConnectionId,
          occurredAt: pausedAt,
          lifecycleState: ConnectionWorkspaceBackgroundLifecycleState.paused,
        );
      }
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: pausedAt,
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      return;
    case AppLifecycleState.resumed:
      final selectedConnectionId = controller._state.selectedConnectionId;
      final resumedAt = controller._now();
      if (selectedConnectionId == null ||
          !controller._state.isConnectionLive(selectedConnectionId)) {
        return;
      }

      controller._recordLifecycleResume(
        selectedConnectionId,
        occurredAt: resumedAt,
      );
      if (!controller._state.requiresTransportReconnect(selectedConnectionId)) {
        final binding = controller._liveBindingRegistry.bindingFor(
          selectedConnectionId,
        );
        if (binding == null || binding.sessionController.sessionState.isBusy) {
          return;
        }
        await _restoreWorkspaceConversationAfterResumeIfNeeded(
          controller,
          selectedConnectionId,
          binding,
        );
        return;
      }

      final binding = controller._liveBindingRegistry.bindingFor(
        selectedConnectionId,
      );
      if (binding == null || binding.sessionController.sessionState.isBusy) {
        return;
      }

      controller._beginRecoveryAttempt(
        selectedConnectionId,
        startedAt: resumedAt,
        origin: ConnectionWorkspaceRecoveryOrigin.foregroundResume,
      );
      await _reconnectWorkspaceConnection(controller, selectedConnectionId);
      return;
    case AppLifecycleState.detached:
      return;
  }
}

Future<void> _restoreWorkspaceConversationAfterResumeIfNeeded(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionLaneBinding binding,
) async {
  if (!_canRestoreWorkspaceConversationAfterResume(
    controller,
    connectionId,
    binding,
  )) {
    return;
  }

  String? selectedThreadId;
  try {
    final latestUnsavedRecoveryState = controller
        ._latestUnsavedRecoveryStateSnapshot();
    selectedThreadId = _normalizedWorkspaceThreadId(
      latestUnsavedRecoveryState?.connectionId == connectionId
          ? latestUnsavedRecoveryState?.selectedThreadId
          : null,
    );
    if (selectedThreadId == null) {
      final persistedRecoveryState = await controller
          ._recoveryPersistenceController
          .loadPersistedSnapshot();
      selectedThreadId = _normalizedWorkspaceThreadId(
        persistedRecoveryState?.connectionId == connectionId
            ? persistedRecoveryState?.selectedThreadId
            : null,
      );
    }
  } catch (error, stackTrace) {
    _debugLogWorkspaceResumeRecoveryFailure(
      operation: 'load recovery state',
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }
  if (selectedThreadId == null) {
    return;
  }

  if (!_canRestoreWorkspaceConversationAfterResume(
    controller,
    connectionId,
    binding,
  )) {
    return;
  }

  try {
    await binding.sessionController.reattachConversation(selectedThreadId);
  } catch (_) {
    if (!_canRestoreWorkspaceConversationAfterResume(
      controller,
      connectionId,
      binding,
    )) {
      return;
    }
    try {
      await binding.sessionController.selectConversationForResume(
        selectedThreadId,
      );
    } catch (error, stackTrace) {
      _debugLogWorkspaceResumeRecoveryFailure(
        operation: 'select conversation for resume',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

void _debugLogWorkspaceResumeRecoveryFailure({
  required String operation,
  required Object error,
  required StackTrace stackTrace,
}) {
  assert(() {
    debugPrint('Failed to $operation during workspace resume: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  }());
}

bool _canRestoreWorkspaceConversationAfterResume(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionLaneBinding binding,
) {
  if (controller._isDisposed ||
      !controller._state.isShowingLiveLane ||
      controller._state.selectedConnectionId != connectionId ||
      !controller._state.isConnectionLive(connectionId)) {
    return false;
  }

  final currentBinding = controller._liveBindingRegistry.bindingFor(
    connectionId,
  );
  if (!identical(currentBinding, binding) ||
      currentBinding == null ||
      currentBinding.sessionController.sessionState.isBusy ||
      currentBinding.sessionController.conversationRecoveryState != null ||
      currentBinding.sessionController.historicalConversationRestoreState !=
          null ||
      _workspaceLaneHasVisibleLiveConversationState(currentBinding)) {
    return false;
  }

  return true;
}
