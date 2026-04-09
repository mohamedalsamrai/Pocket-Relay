import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/workspace/application/workspace_turn_activity.dart';

void main() {
  final startedAt = DateTime.utc(2026, 4, 9, 12);

  TranscriptActiveTurnState activeTurn({
    String turnId = 'turn_1',
    bool completed = false,
    TranscriptActiveTurnStatus status = TranscriptActiveTurnStatus.running,
  }) {
    final timer = TranscriptSessionTurnTimer(
      turnId: turnId,
      startedAt: startedAt,
    );
    return TranscriptActiveTurnState(
      turnId: turnId,
      timer: completed ? timer.complete(completedAt: startedAt) : timer,
      status: status,
    );
  }

  test('session transcript active turns keep workspace continuity alive', () {
    final state = TranscriptSessionState.transcript(
      connectionStatus: TranscriptRuntimeSessionState.running,
      activeTurn: activeTurn(),
    );

    expect(workspaceSessionHasContinuityActiveTurn(state), isTrue);
  });

  test('blocked active turns still keep workspace continuity alive', () {
    final state = TranscriptSessionState.transcript(
      connectionStatus: TranscriptRuntimeSessionState.running,
      activeTurn: activeTurn(status: TranscriptActiveTurnStatus.blocked),
    );

    expect(workspaceSessionHasContinuityActiveTurn(state), isTrue);
  });

  test('completed turns do not keep workspace continuity alive', () {
    final state = TranscriptSessionState.transcript(
      connectionStatus: TranscriptRuntimeSessionState.ready,
      activeTurn: activeTurn(completed: true),
    );

    expect(workspaceSessionHasContinuityActiveTurn(state), isFalse);
  });

  test(
    'non-selected timeline active turns keep workspace continuity alive',
    () {
      final state = TranscriptSessionState(
        connectionStatus: TranscriptRuntimeSessionState.running,
        rootThreadId: 'thread_primary',
        selectedThreadId: 'thread_primary',
        timelinesByThreadId: <String, TranscriptTimelineState>{
          'thread_primary': const TranscriptTimelineState(
            threadId: 'thread_primary',
          ),
          'thread_background': TranscriptTimelineState(
            threadId: 'thread_background',
            activeTurn: activeTurn(turnId: 'turn_background'),
          ),
        },
      );

      expect(workspaceSessionHasContinuityActiveTurn(state), isTrue);
    },
  );
}
