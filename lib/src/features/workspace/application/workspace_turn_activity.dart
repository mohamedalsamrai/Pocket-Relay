import 'package:pocket_relay/src/features/chat/lane/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_live_session_tracker.dart';

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
  return sessionControllers.any(
    (controller) =>
        workspaceSessionHasContinuityActiveTurn(controller.sessionState),
  );
}

bool workspaceSessionHasContinuityActiveTurn(
  TranscriptSessionState sessionState,
) {
  return workspaceTurnKeepsContinuity(sessionState.sessionActiveTurn) ||
      sessionState.timelinesByThreadId.values.any(
        (timeline) => workspaceTurnKeepsContinuity(timeline.activeTurn),
      );
}

bool workspaceTurnKeepsContinuity(TranscriptActiveTurnState? activeTurn) {
  return activeTurn?.timer.isRunning == true;
}
