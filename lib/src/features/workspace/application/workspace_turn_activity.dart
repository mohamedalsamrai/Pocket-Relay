import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

typedef WorkspaceLiveSessionControllerEntry = ({
  String connectionId,
  ChatSessionController sessionController,
});

Iterable<WorkspaceLiveSessionControllerEntry> workspaceLiveSessionControllers(
  ConnectionWorkspaceController workspaceController,
) sync* {
  for (final connectionId in workspaceController.state.liveConnectionIds) {
    final binding = workspaceController.bindingForConnectionId(connectionId);
    if (binding != null) {
      yield (
        connectionId: connectionId,
        sessionController: binding.sessionController,
      );
    }
  }
}

bool workspaceHasContinuityActiveTurn(
  ConnectionWorkspaceController workspaceController,
) {
  return workspaceSessionControllersHaveContinuityActiveTurn(
    workspaceLiveSessionControllers(
      workspaceController,
    ).map((entry) => entry.sessionController),
  );
}

bool workspaceSessionControllersHaveContinuityActiveTurn(
  Iterable<ChatSessionController> sessionControllers,
) {
  for (final controller in sessionControllers) {
    if (workspaceSessionHasContinuityActiveTurn(controller.sessionState)) {
      return true;
    }
  }

  return false;
}

bool workspaceSessionHasContinuityActiveTurn(
  TranscriptSessionState sessionState,
) {
  if (workspaceTurnKeepsContinuity(sessionState.sessionActiveTurn)) {
    return true;
  }

  for (final timeline in sessionState.timelinesByThreadId.values) {
    if (workspaceTurnKeepsContinuity(timeline.activeTurn)) {
      return true;
    }
  }

  return false;
}

bool workspaceTurnKeepsContinuity(TranscriptActiveTurnState? activeTurn) {
  return activeTurn?.timer.isRunning == true;
}
