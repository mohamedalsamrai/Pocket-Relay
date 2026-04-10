part of '../connection_workspace_controller.dart';

Future<void> _handleWorkspaceAppLifecycleState(
  ConnectionWorkspaceController controller,
  AppLifecycleState state,
) async {
  switch (state) {
    case AppLifecycleState.inactive:
      final selectedLaneId = controller._state.selectedLaneId;
      final backgroundedAt = controller._now();
      if (selectedLaneId != null &&
          controller._state.isLaneLive(selectedLaneId)) {
        controller._recordLifecycleBackgroundSnapshot(
          selectedLaneId,
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
      final hiddenLaneId = controller._state.selectedLaneId;
      final hiddenAt = controller._now();
      if (hiddenLaneId != null && controller._state.isLaneLive(hiddenLaneId)) {
        controller._recordLifecycleBackgroundSnapshot(
          hiddenLaneId,
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
      final pausedLaneId = controller._state.selectedLaneId;
      final pausedAt = controller._now();
      if (pausedLaneId != null && controller._state.isLaneLive(pausedLaneId)) {
        controller._recordLifecycleBackgroundSnapshot(
          pausedLaneId,
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
      final selectedLaneId = controller._state.selectedLaneId;
      final resumedAt = controller._now();
      if (selectedLaneId == null ||
          !controller._state.isLaneLive(selectedLaneId)) {
        return;
      }
      final selectedLane = controller._state.liveLaneForId(selectedLaneId);
      if (selectedLane == null) {
        return;
      }

      controller._recordLifecycleResume(selectedLaneId, occurredAt: resumedAt);
      if (!controller._state.requiresTransportReconnectForLane(
        selectedLaneId,
      )) {
        final binding = controller._laneRoster.bindingForLaneId(selectedLaneId);
        if (binding == null || binding.sessionController.sessionState.isBusy) {
          return;
        }
        await _restoreWorkspaceConversationAfterResumeIfNeeded(
          controller,
          selectedLaneId,
          binding,
        );
        return;
      }

      final binding = controller._laneRoster.bindingForLaneId(selectedLaneId);
      if (binding == null || binding.sessionController.sessionState.isBusy) {
        return;
      }

      controller._beginRecoveryAttempt(
        selectedLaneId,
        startedAt: resumedAt,
        origin: ConnectionWorkspaceRecoveryOrigin.foregroundResume,
      );
      await _reconnectWorkspaceConnection(controller, selectedLaneId);
      return;
    case AppLifecycleState.detached:
      return;
  }
}

Future<void> _restoreWorkspaceConversationAfterResumeIfNeeded(
  ConnectionWorkspaceController controller,
  String laneId,
  ConnectionLaneBinding binding,
) async {
  final lane = controller._state.liveLaneForId(laneId);
  if (lane == null ||
      !_canRestoreWorkspaceConversationAfterResume(
        controller,
        laneId,
        binding,
      )) {
    return;
  }

  String? selectedThreadId;
  try {
    final latestUnsavedRecoveryState = controller
        ._latestUnsavedRecoveryStateSnapshot();
    selectedThreadId = _normalizedWorkspaceThreadId(
      latestUnsavedRecoveryState?.connectionId == lane.connectionId
          ? latestUnsavedRecoveryState?.selectedThreadId
          : null,
    );
    if (selectedThreadId == null) {
      final persistedRecoveryState = await controller
          ._recoveryPersistenceController
          .loadPersistedSnapshot();
      selectedThreadId = _normalizedWorkspaceThreadId(
        persistedRecoveryState?.connectionId == lane.connectionId
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
    laneId,
    binding,
  )) {
    return;
  }

  try {
    await binding.sessionController.reattachConversation(selectedThreadId);
  } catch (_) {
    if (!_canRestoreWorkspaceConversationAfterResume(
      controller,
      laneId,
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
  String laneId,
  ConnectionLaneBinding binding,
) {
  final lane = controller._state.liveLaneForId(laneId);
  if (controller._isDisposed ||
      lane == null ||
      !controller._state.isShowingLiveLane ||
      controller._state.selectedLaneId != laneId ||
      !controller._state.isLaneLive(laneId)) {
    return false;
  }

  final currentBinding = controller._laneRoster.bindingForLaneId(laneId);
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
