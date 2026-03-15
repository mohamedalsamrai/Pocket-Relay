import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';

class TranscriptReducer {
  const TranscriptReducer({TranscriptPolicy policy = const TranscriptPolicy()})
    : _policy = policy;

  final TranscriptPolicy _policy;

  CodexSessionState addUserMessage(
    CodexSessionState state, {
    required String text,
    DateTime? createdAt,
  }) {
    return _policy.addUserMessage(state, text: text, createdAt: createdAt);
  }

  CodexSessionState startFreshThread(
    CodexSessionState state, {
    String? message,
    DateTime? createdAt,
  }) {
    return _policy.startFreshThread(
      state,
      message: message,
      createdAt: createdAt,
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return _policy.clearTranscript(state);
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return _policy.detachThread(state);
  }

  CodexSessionState reduceRuntimeEvent(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    switch (event) {
      case CodexRuntimeSessionStartedEvent():
        return state;
      case CodexRuntimeSessionStateChangedEvent():
        return state.copyWith(connectionStatus: event.state);
      case CodexRuntimeSessionExitedEvent():
        return _policy.applySessionExited(state, event);
      case CodexRuntimeThreadStartedEvent():
        return state.copyWith(threadId: event.providerThreadId);
      case CodexRuntimeThreadStateChangedEvent():
        final isClosed = event.state == CodexRuntimeThreadState.closed;
        final activeTurn = isClosed && state.activeTurn != null
            ? state.activeTurn!.copyWith(
                timer: state.activeTurn!.timer.complete(
                  completedAt: event.createdAt,
                  monotonicAt: CodexMonotonicClock.now(),
                ),
              )
            : state.activeTurn;
        return state.copyWith(
          clearThreadId: isClosed,
          activeTurn: isClosed ? activeTurn : state.activeTurn,
          clearActiveTurn: isClosed,
        );
      case CodexRuntimeTurnStartedEvent():
        final nextTimer = event.turnId == null
            ? null
            : CodexSessionTurnTimer(
                turnId: event.turnId!,
                startedAt: event.createdAt,
                activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
              );
        return state.copyWith(
          connectionStatus: CodexRuntimeSessionState.running,
          threadId: event.threadId ?? state.threadId,
          activeTurn: event.turnId == null
              ? state.activeTurn
              : CodexActiveTurnState(
                  turnId: event.turnId!,
                  threadId: event.threadId ?? state.threadId,
                  timer: nextTimer!,
                ),
        );
      case CodexRuntimeTurnCompletedEvent():
        return _policy.applyTurnCompleted(state, event);
      case CodexRuntimeTurnAbortedEvent():
        return _policy.applyTurnAborted(state, event);
      case CodexRuntimeTurnPlanUpdatedEvent():
        return _policy.applyTurnPlanUpdated(state, event);
      case CodexRuntimeTurnDiffUpdatedEvent():
        return _policy.applyTurnDiffUpdated(state, event);
      case CodexRuntimeItemStartedEvent():
        return _policy.applyItemLifecycle(
          state,
          event,
          removeAfterUpsert: false,
        );
      case CodexRuntimeItemUpdatedEvent():
        return _policy.applyItemLifecycle(
          state,
          event,
          removeAfterUpsert: false,
        );
      case CodexRuntimeItemCompletedEvent():
        return _policy.applyItemLifecycle(
          state,
          event,
          removeAfterUpsert: true,
        );
      case CodexRuntimeContentDeltaEvent():
        return _policy.applyContentDelta(state, event);
      case CodexRuntimeRequestOpenedEvent():
        return _policy.applyRequestOpened(state, event);
      case CodexRuntimeRequestResolvedEvent():
        return _policy.applyRequestResolved(state, event);
      case CodexRuntimeUserInputRequestedEvent():
        return _policy.applyUserInputRequested(state, event);
      case CodexRuntimeUserInputResolvedEvent():
        return _policy.applyUserInputResolved(state, event);
      case CodexRuntimeWarningEvent():
        return _policy.applyWarning(state, event);
      case CodexRuntimeStatusEvent():
        return _policy.applyStatus(state, event);
      case CodexRuntimeErrorEvent():
        return _policy.applyRuntimeError(state, event);
    }
  }
}
