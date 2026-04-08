import '../session_controller_test_support.dart';
import 'session_controller_work_log_terminal_test_support.dart';

void main() {
  test(
    'hydrateWorkLogTerminal keeps summary-only history distinct from terminal output',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_summary'] =
            const CodexAppServerThreadHistory(
              id: 'thread_summary',
              turns: <CodexAppServerHistoryTurn>[
                CodexAppServerHistoryTurn(
                  id: 'turn_summary',
                  status: 'completed',
                  items: <CodexAppServerHistoryItem>[
                    CodexAppServerHistoryItem(
                      id: 'command_summary',
                      type: 'commandExecution',
                      status: 'completed',
                      raw: <String, dynamic>{
                        'id': 'command_summary',
                        'type': 'commandExecution',
                        'status': 'completed',
                        'command': 'deploy.sh',
                        'result': <String, dynamic>{
                          'summary': 'Waiting on remote deployment slot',
                        },
                      },
                    ),
                  ],
                  raw: <String, dynamic>{
                    'id': 'turn_summary',
                    'status': 'completed',
                  },
                ),
              ],
            );
      final controller = buildWorkLogTerminalSessionController(
        appServerClient: appServerClient,
      );

      final hydrated = await controller.hydrateWorkLogTerminal(
        const ChatWorkLogTerminalContract(
          id: 'item_command_summary',
          activityLabel: 'Ran command',
          commandText: 'deploy.sh',
          isRunning: false,
          isWaiting: false,
          itemId: 'command_summary',
          threadId: 'thread_summary',
          turnId: 'turn_summary',
        ),
      );

      expect(hydrated.terminalOutput, isNull);
      expect(hydrated.activitySummary, 'Waiting on remote deployment slot');
    },
  );
}
